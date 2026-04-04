SPEC: Celebration Haptic + Bounce Fix v2 | Project: sf-stairways | Date: 2026-04-03 | Status: Ready for implementation

## 1. Objective

The haptic feedback and checkmark bounce animation on "Mark Walked" are not firing despite the code being present. Fix both so they actually trigger on device.

## 2. Scope

StairwayBottomSheet.swift only.

## 3. Root Cause

### Bounce not firing
The `.symbolEffect(.bounce, value: celebrationTrigger)` is on the checkmark inside the green walked banner. But the banner only renders when `isWalked == true`. When the user taps "Mark Walked":
1. `markWalked()` saves the record AND increments `celebrationTrigger`
2. SwiftUI re-evaluates the view: `isWalked` becomes true, so the banner (including the checkmark) gets inserted into the view hierarchy for the first time
3. The checkmark was not in the view when `celebrationTrigger` changed, so `.symbolEffect(.bounce, value:)` has no "old value" to compare against. It sees the current value on first render and does nothing.

**The bounce fires on VALUE CHANGE, but the view didn't exist during the change.**

### Haptic possibly not firing
`UIImpactFeedbackGenerator` should be `prepare()`d before `impactOccurred()`. Without prepare, the Taptic Engine may not be ready in time and the haptic gets silently dropped.

## 4. Fix

### Bounce fix
Move the `celebrationTrigger` increment to the banner's `.onAppear` so it fires AFTER the checkmark is in the view hierarchy:

```swift
// In the walked banner view:
Image(systemName: "checkmark.circle.fill")
    .font(.system(size: 44))
    .foregroundStyle(.white)
    .symbolEffect(.bounce, value: celebrationTrigger)
    .onAppear {
        // Small delay lets the view settle before bouncing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            celebrationTrigger += 1
        }
    }
```

Remove the `celebrationTrigger += 1` from `markWalked()`. The `onAppear` on the banner handles it.

### Haptic fix
Prepare the haptic engine before the save:

```swift
private func markWalked(proximityVerified: Bool? = nil) {
    let haptic = UIImpactFeedbackGenerator(style: .medium)
    haptic.prepare()

    // ... existing record save logic ...

    try? modelContext.save()
    haptic.impactOccurred()
}
```

## 5. Acceptance Criteria

- [ ] Checkmark bounces visibly when banner appears after marking walked (test on DEVICE, not simulator)
- [ ] Haptic fires on mark walked (test on DEVICE, not simulator)
- [ ] Both work on the Hard Mode "Mark Anyway" path (after the 0.3s alert dismiss delay)
- [ ] Bounce does NOT re-fire when scrolling the sheet or switching tabs
- [ ] No crash or animation glitch on unmark (Remove walk record)

## 6. Files Likely Touched

- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — move celebrationTrigger to onAppear, fix haptic prepare
