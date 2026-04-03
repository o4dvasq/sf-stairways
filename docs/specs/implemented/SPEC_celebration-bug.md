SPEC: Celebration Animation Bug Fix | Project: sf-stairways | Date: 2026-04-03 | Status: Ready for implementation

## 1. Objective

Fix the "mark walked" celebration not playing. The green background tint, haptic feedback, and checkmark bounce animation are all coded but none of them fire in practice. The most common path is: user taps "Mark Walked" with Hard Mode on, gets the proximity alert, taps "Mark Anyway", and the stairway silently becomes marked with no visual celebration.

## 2. Scope

StairwayBottomSheet.swift only. The celebration elements (haptic, surfaceWalked background, .symbolEffect bounce, withAnimation) are already implemented but are not triggering visually.

## 3. Business Rules

When a stairway is marked as walked (any path: direct mark, Hard Mode override, or photo-triggered), the user should see:
- Haptic feedback (medium impact)
- Sheet background color transition from white to surfaceWalked (green tint)
- Checkmark icon bounce animation
- Neighborhood progress line ("N of M in [neighborhood]")

## 4. Data Model / Schema Changes

None.

## 5. UI / Interface

No design changes. The spec is about making the existing celebration elements actually fire.

## 6. Integration Points

None.

## 7. Constraints

Must work on iOS 17+.

## 8. Acceptance Criteria

- [ ] Tapping "Mark Walked" (non-Hard Mode path) triggers haptic + green background transition + checkmark bounce
- [ ] Tapping "Mark Anyway" from the Hard Mode alert triggers the same celebration
- [ ] Unmarking (via "Remove" alert) reverses the green background smoothly back to white
- [ ] Celebration works on first mark (new WalkRecord) and re-mark (existing record with walked=false)

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift`

## Root Cause Analysis

There are likely two interacting bugs:

### Bug A: `withAnimation` wraps the wrong thing

In `markWalked()` (line ~728), the state mutation happens BEFORE the animation block:

```swift
record.walked = true          // ← mutation happens here (line 731)
// ...
withAnimation(.easeInOut(duration: 0.4)) {
    try? modelContext.save()  // ← animation wraps save, not the state change
}
```

SwiftData may trigger the view update on `record.walked = true` rather than on `save()`. If so, the animation context isn't active when `isWalked` flips.

**Fix**: Move the mutation inside the `withAnimation` block, or better yet, use an explicit `@State` trigger:

```swift
private func markWalked(proximityVerified: Bool? = nil) {
    // Save the record first
    if let record = walkRecord {
        record.walked = true
        record.dateWalked = record.dateWalked ?? Date()
        record.hardModeAtCompletion = authManager.hardModeEnabled
        record.proximityVerified = proximityVerified
        record.updatedAt = Date()
    } else {
        let record = WalkRecord(stairwayID: stairway.id, walked: true, dateWalked: Date())
        record.hardModeAtCompletion = authManager.hardModeEnabled
        record.proximityVerified = proximityVerified
        modelContext.insert(record)
    }
    try? modelContext.save()

    // Fire celebration AFTER save
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    withAnimation(.easeInOut(duration: 0.4)) {
        celebrationTrigger += 1  // new @State var, drives animations
    }
}
```

### Bug B: Alert dismissal swallows the animation

When the Hard Mode alert ("Mark Anyway") fires `markWalked()`, the alert is in the process of dismissing. SwiftUI's alert dismissal animation may override or cancel the celebration animation. The view redraws post-alert with `isWalked` already true, so there's no before/after transition to animate.

**Fix**: Delay the mark slightly so the alert finishes dismissing first:

```swift
Button("Mark Anyway") {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        markWalked(proximityVerified: false)
    }
}
```

Or use `.task` / `onChange(of: showHardModeAlert)` to trigger the mark after the alert is fully gone.

### Recommended approach

Combine both fixes. The `celebrationTrigger` @State var approach is more robust than relying on computed property changes for animation. And the slight delay on the Hard Mode path ensures the alert is out of the way.
