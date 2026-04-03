SPEC: Walked Card Redesign | Project: sf-stairways | Date: 2026-04-03 | Status: Ready for implementation

## 1. Objective

Redesign the "walked" state of StairwayBottomSheet to deliver a clear visual celebration. Replace the barely-tinted green background with a bold green banner at the top of the card. Remove section headings ("My Notes", "Tags", "Photos") to declutter the card. This replaces the earlier celebration spec (SPEC_mark-walked-celebration and SPEC_celebration-bug) with a layout-driven approach that doesn't depend on animations firing correctly.

## 2. Scope

- StairwayBottomSheet layout changes for walked state
- Remove section headings, keep action buttons and content
- Move share icon and camera icon below the banner
- Fix the celebration animation timing (haptic + banner appearance on mark)

## 3. Business Rules

When a stairway is marked as walked, the card should feel like an achievement. The walked state should be unmistakable at a glance.

## 4. Data Model / Schema Changes

None.

## 5. UI / Interface

### Walked State: Green Banner

When `isWalked == true`, the top of the card becomes a bold green (`walkedGreen` / `#4CAF50`) banner:

```
┌─────────────────────────────────┐
│  (green background)             │
│  Ventura Avenue to              │  ← white, bold, .title3
│  8th Avenue                     │
│  Forest Hill · 2 of 10     ✓   │  ← white, .subheadline on left; big white checkmark on right
│                                 │
├─────────────────────────────────┤
│  (white background below)       │
│  📤  📷  30 ft                  │  ← share icon, camera icon, stats row
│                                 │
│  ┌─ note content or +Add Note ─┐│
│  └──────────────────────────────┘│
│                                 │
│  [tag pills] [+ Add Tag]       │
│                                 │
│  [photo carousel]               │
│                                 │
│  🔗 View on sfstairways.com    │
└─────────────────────────────────┘
```

**Banner details:**
- Background: `Color.walkedGreen` (the full-width green)
- Stairway name: white, `.title3`, `.fontWeight(.bold)`
- Neighborhood + progress: white, `.subheadline`. Format: `"Forest Hill · 2 of 10"` (use center dot, not dash)
- Checkmark: white `checkmark.circle.fill`, `.font(.system(size: 44))`, right-aligned
- Banner padding: 20pt horizontal, 16pt vertical
- If the stairway was NOT proximity-verified, show a small amber `xmark.seal.fill` icon next to the checkmark (existing behavior, just relocated)

**Below the banner (white background):**
- Share icon and camera icon row (moved from headerSection)
- Stats row (height, etc.)
- Notes content area: show existing notes or "+ Add Note" button. NO "My Notes" heading.
- Tags area: show tag pills or "+ Add Tag" button. NO "Tags" heading.
- Photo carousel: show photos or add photo. NO "Photos" heading. The PhotoCarousel already has its own add button, so this should work as-is.
- External links (sfstairways.com, Urban Hiker) remain unchanged at bottom.

### Unwalked State

When `isWalked == false`, the card layout stays essentially the same as current, EXCEPT:
- Also drop the "My Notes", "Tags" section headings (keep consistent with walked state)
- Keep the "Mark Walked" action button
- Background remains white/systemBackground

### Celebration on Mark

When the user taps "Mark Walked" (or "Mark Anyway" from Hard Mode):
1. Haptic: `UIImpactFeedbackGenerator(style: .medium).impactOccurred()`
2. The banner appears with a slide-down + fade animation (`.transition(.move(edge: .top).combined(with: .opacity))`)
3. Important: on the Hard Mode path, use `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)` before calling `markWalked()` so the alert fully dismisses before the celebration plays

## 6. Integration Points

None.

## 7. Constraints

- iOS 17+
- The banner replaces the current `headerSection` + `walkStatusCard` when walked. It does NOT replace the entire card background (no more `surfaceWalked` tinting the whole sheet).
- Remove the `.background(isWalked ? Color.surfaceWalked : ...)` from the ScrollView. The whole-sheet green tint is being replaced by the banner approach.

## 8. Acceptance Criteria

- [ ] Walked stairways show bold green banner with white stairway name, neighborhood + progress, and large checkmark
- [ ] Share and camera icons appear below the banner on white background
- [ ] Section headings "My Notes", "Tags" are removed (both walked and unwalked states)
- [ ] "+ Add Note", "+ Add Tag" action buttons still present and functional
- [ ] Existing notes and tags display correctly without headings
- [ ] Haptic fires on mark
- [ ] Banner animates in on mark (not just appears statically)
- [ ] Hard Mode "Mark Anyway" path also shows celebration (delayed after alert dismiss)
- [ ] Unmark ("Remove") transitions back to unwalked layout smoothly
- [ ] `surfaceWalked` whole-sheet background tint is removed (banner replaces it)

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — main changes: new `walkedBanner` view, restructure `headerSection` to be conditional, remove section heading texts, move share/camera icons, fix animation timing
- `ios/SFStairways/Resources/AppColors.swift` — `surfaceWalked` can be removed or kept for potential future use
