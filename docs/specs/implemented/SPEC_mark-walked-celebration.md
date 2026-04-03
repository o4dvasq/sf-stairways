# SPEC: Mark Walked Celebration
**Project:** sf-stairways | **Date:** 2026-04-02 | **Status:** Ready for Implementation

---

## 1. Objective

Transform the "Mark Walked" action from a silent database write into the emotional core of the app. This is the only thing users "do" in SF Stairways, and it should feel like a moment. Three changes: the bottom sheet card changes color to reflect completion state, a brief celebration animation plays on mark, an immediate neighborhood progress callout appears, and a haptic tap fires.

---

## 2. Scope

**In scope:**
- Bottom sheet background color changes based on walked state
- Celebration animation on successful "Mark Walked"
- Immediate neighborhood progress callout after marking
- Haptic feedback on mark
- Richer walked state display in the bottom sheet

**Out of scope:**
- Sound effects
- Confetti or particle systems (keep it tasteful)
- Changes to map pin behavior or colors
- Changes to the "Mark Walked" button design (can be revisited later)
- Neighborhood milestone callouts ("First in Bernal Heights!") — captured separately in the Neighborhood Rewards future spec
- Changes to the list view or progress tab

---

## 3. Business Rules

1. **Bottom sheet color reflects state.** The sheet background communicates completion at a glance:
   - **Unwalked:** White/default background. The current look. Says "not yet."
   - **Walked:** Soft green background tint. Says "this is yours." The green should be gentle, not neon. Think `walkedGreen` at 10-15% opacity over white, or a dedicated light green surface color. All text remains legible. The walked status card, notes, tags, and photos sections all sit on this green-tinted surface.
   - The color transition should animate smoothly when the user taps "Mark Walked" (not an instant swap).

2. **Celebration animation on mark.** When `markWalked()` succeeds, a brief visual celebration plays. This should be subtle enough that it still feels good on the 50th walk. Suggestions (implementation picks one):
   - The green checkmark icon scales up with a spring/bounce animation, then settles
   - A brief green radial pulse emanates from the checkmark
   - The sheet background fades from white to green with a satisfying ease curve
   - Whatever is chosen, it should take 0.4-0.8 seconds total. Not longer.

3. **Haptic feedback.** Fire `UIImpactFeedbackGenerator(style: .medium)` immediately when `markWalked()` succeeds. One tap, no patterns. This makes the action feel physical.

4. **Immediate progress callout.** After marking walked, show a compact line of text in the bottom sheet: "3 of 14 in Mission Terrace" (or whatever the current neighborhood progress is). This connects the single action to the larger mission. The callout appears as part of the walked state display, not as a separate toast or modal.

5. **The Mark Walked button disappears after marking.** This is current behavior and should remain. The walked state card replaces the button. The celebration animation bridges the transition.

6. **Unmark reverts to white.** If a user unmarks a walk (reverts to unwalked), the sheet background animates back to white. No celebration plays in reverse. Just a quiet revert.

---

## 4. Data Model / Schema Changes

None. All data needed (walked state, neighborhood counts) is already available via existing `WalkRecord` queries and `StairwayStore`.

---

## 5. UI / Interface

### Bottom Sheet: Unwalked State (unchanged except background is explicitly white)

```
┌─────────────────────────────────────┐  white background
│                                     │
│  Sunglow Lane              [camera] │
│  Mission Terrace >                  │
│                                     │
│  30 ft                              │
│                                     │
│  Not yet walked                     │
│                                     │
│  ┌─────────────────────────────┐    │
│  │     ✓  Mark Walked          │    │  green button
│  └─────────────────────────────┘    │
│                                     │
│  My Notes                           │
│  + Add Note                         │
│                                     │
│  Tags                               │
│  + Add Tag                          │
│                                     │
└─────────────────────────────────────┘
```

### Bottom Sheet: Walked State (NEW colored background)

```
┌─────────────────────────────────────┐  soft green tinted background
│                                     │
│  Sunglow Lane        [share][camera]│
│  Mission Terrace >                  │
│                                     │
│  30 ft                              │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ ✓ Walked         April 2   │    │  green status card
│  │   3 of 14 in Mission Terr. │    │  <- NEW progress line
│  └─────────────────────────────┘    │
│                                     │
│  My Notes                           │
│  + Add Note                         │
│                                     │
│  Tags                               │
│  + Add Tag                          │
│                                     │
│  Photos                             │
│                                     │
└─────────────────────────────────────┘
```

### Color Specifications

**Walked sheet background:** Use `walkedGreen` (Color(red: 76/255, green: 175/255, blue: 80/255)) at approximately 8-12% opacity over white. The exact value should be tuned visually so that all text (dark text, muted text, orange accents) remains legible. An alternative approach: define a new `AppColors.surfaceWalked` color as a very light green (e.g., `Color(red: 240/255, green: 250/255, blue: 240/255)` for light mode). The implementation should test both approaches and pick whichever looks better.

**Dark mode:** If the app supports dark mode for the bottom sheet, the walked tint should be a very dark green rather than light green. Same principle: subtle, not neon.

### Animation Sequence

When user taps "Mark Walked":

1. **Haptic fires** (UIImpactFeedbackGenerator, medium) — instant
2. **Walk record is saved** — instant
3. **Sheet background animates** from white to soft green — 0.4s ease-in-out
4. **Walked status card appears** with the checkmark scaling up via spring animation — 0.3s
5. **Progress line fades in** below the walked date — 0.2s delay after step 4

Total perceived duration: under 1 second. Should feel snappy, not slow.

### Progress Line in Walked Card

The progress line sits inside the existing walked status card, below the date:
- Format: "3 of 14 in Mission Terrace"
- Font: `.caption`, secondary color
- Only shows if neighborhood has more than 1 stairway (don't show "1 of 1 in [neighborhood]")
- Uses the same neighborhood progress data that the share card already computes

---

## 6. Integration Points

- **StairwayBottomSheet.swift** — primary file. Add background color state, animation, haptic, progress line.
- **AppColors.swift** — add `surfaceWalked` color token if using the dedicated color approach.
- **StairwayStore** — already provides neighborhood stairway counts. Reuse existing helpers.
- **WalkRecord query** — the bottom sheet already queries walk records. Neighborhood walked count can be derived from the same query pattern used by the share card.
- **UIImpactFeedbackGenerator** — UIKit import, instantiate and call `.impactOccurred()`. One line of code.

---

## 7. Constraints

- The bottom sheet uses SwiftUI's `.presentationDetents` with `.height(390)` and `.large`. Background color changes must work within this presentation style. Test that `.presentationBackground()` modifier (iOS 16.4+) works for this, or apply the color to the content VStack's background instead.
- Animation must not interfere with the sheet's drag gesture or dismiss behavior.
- The progress line needs the same neighborhood count computation that `ShareCardView` now receives. Consider extracting a shared helper if the computation is duplicated.
- Keep the celebration animation simple enough that it works reliably in `ImageRenderer` is not a concern (the animation is live UI, not rendered to an image).

---

## 8. Acceptance Criteria

- [ ] Bottom sheet background is white for unwalked stairways
- [ ] Bottom sheet background tints to soft green when stairway is walked
- [ ] Background color animates smoothly on "Mark Walked" (not an instant snap)
- [ ] Background reverts to white when walk is unmarked
- [ ] Haptic feedback (medium impact) fires on successful "Mark Walked"
- [ ] Walked status card checkmark has a spring/bounce animation on appear
- [ ] Progress line ("3 of 14 in Mission Terrace") appears in the walked card
- [ ] Progress line does not appear for neighborhoods with only 1 stairway
- [ ] All text remains legible on the green-tinted background (both light and dark mode if applicable)
- [ ] Animation completes in under 1 second total
- [ ] No interference with sheet drag/dismiss gestures
- [ ] Celebration still feels good on the 10th, 20th, 50th walk (not annoying or slow)
- [ ] Feedback loop prompt has been run

---

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — background color state, animation, haptic, progress line in walked card
- `ios/SFStairways/Resources/AppColors.swift` — add `surfaceWalked` color token (optional, depending on approach)
