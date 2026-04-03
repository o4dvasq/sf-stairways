# SPEC: Share Card Redesign
**Project:** sf-stairways | **Date:** 2026-04-02 | **Status:** Ready for Implementation

---

## 1. Objective

Redesign the share card so it works even when the user's photo is mediocre (or absent). The current card is "photo + text panel," which means a weak photo drags down the whole card. The redesign adds brand identity directly onto the photo (logo overlay, amber frame) and integrates a neighborhood progress element, so every card communicates "SF Stairways" and "I'm on a mission" regardless of photo quality.

---

## 2. Scope

**In scope:**
- Amber border framing the photo
- White logo + "SF Stairways" overlay on the photo
- Neighborhood progress indicator on the card
- Simplified bottom text panel
- Updated no-photo layout to match new design language
- Modifying the existing `ShareCardView.swift`

**Out of scope:**
- Card templates or user-selectable styles
- New SwiftData models
- Share button placement changes (already implemented, works well)
- Changes to `ActivityShareSheet` behavior

---

## 3. Business Rules

1. **Every card is branded.** The StairShape logo and "SF Stairways" text must appear on every card (both photo and no-photo variants). This is the primary goal of the redesign.

2. **Amber frame communicates the brand.** The user's photo is inset within a brandAmber (`#D4882B`) border, not edge-to-edge. The frame should be substantial enough to read as intentional design (not a rendering glitch), roughly 16-20pt logical width on each side.

3. **Logo overlay on the photo.** A white StairShape icon + "SF Stairways" text overlaid on the photo, top-left area, with a subtle shadow or semi-transparent background pill for legibility against any photo. Similar in spirit to how Strava brands their activity shares.

4. **Neighborhood progress.** The card includes a compact progress element showing the user's progress in that stairway's neighborhood. Format: "3 of 14 in Bernal Heights" or a small progress ring with the count. This is the hook that makes the card shareable. It says "I'm on a mission," not just "I walked some stairs."

5. **Bottom panel is lighter.** With branding on the photo and the amber frame doing the visual work, the bottom text panel can be more compact. Stairway name (prominent), neighborhood, height pill. The tagline ("Climb every stairway in San Francisco") and URL (`sfstairways.app`) remain but can be smaller.

6. **Card dimensions unchanged.** Still 1080x1920 (360x640pt @ 3x). Portrait, 9:16, optimized for Instagram Stories.

---

## 4. Data Model / Schema Changes

None. The neighborhood progress data is already computable. `StairwayStore` can count total stairways per neighborhood, and `WalkRecord` queries can count walked stairways per neighborhood. `ShareCardView` will need these counts passed in as parameters.

---

## 5. UI / Interface

### Card Layout: With Photo

```
┌──────────────────────────────────┐
│  brandAmber border (all sides)   │
│  ┌────────────────────────────┐  │
│  │ [StairShape] SF Stairways  │  │  <- white logo + text, top-left
│  │                            │  │     on photo, subtle shadow
│  │                            │  │
│  │     [User's photo]         │  │  <- photo inset within amber
│  │     (fills inset area)     │  │     frame, roughly top 55-60%
│  │                            │  │
│  │                            │  │
│  │          3 of 14 ○         │  │  <- progress, bottom-right of
│  │      Bernal Heights        │  │     photo area, pill overlay
│  └────────────────────────────┘  │
│                                  │
│  Vulcan Stairway                 │  <- stairway name, prominent
│  Bernal Heights                  │  <- neighborhood, muted
│                                  │
│  ┌────────┐  ┌──────────┐       │
│  │ 115 ft │  │ Walked ✓ │       │  <- stat pills
│  └────────┘  └──────────┘       │
│                                  │
│  Climb every stairway in SF      │  <- tagline, small
│  sfstairways.app                 │  <- URL, brand orange
│                                  │
└──────────────────────────────────┘
```

### Card Layout: No Photo

```
┌──────────────────────────────────┐
│  brandAmber border (all sides)   │
│  ┌────────────────────────────┐  │
│  │                            │  │
│  │  [StairShape] SF Stairways │  │  <- white logo + text, top-left
│  │                            │  │
│  │  (brandOrange solid bg)    │  │
│  │                            │  │
│  │  Vulcan Stairway           │  │  <- stairway name, large, white
│  │  Bernal Heights            │  │  <- neighborhood, white/cream
│  │                            │  │
│  │  3 of 14 in                │  │  <- progress, larger treatment
│  │  Bernal Heights            │  │     since no photo to show
│  │                            │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌────────┐  ┌──────────┐       │
│  │ 115 ft │  │ Walked ✓ │       │  <- stat pills
│  └────────┘  └──────────┘       │
│                                  │
│  Climb every stairway in SF      │
│  sfstairways.app                 │
│                                  │
└──────────────────────────────────┘
```

### Logo Overlay Detail

- StairShape icon: ~16pt, white fill
- "SF Stairways" text: SF Pro Rounded, ~13pt, white, medium weight
- Positioned top-left of the photo area with ~12pt padding from edges
- Add a subtle drop shadow (radius 4, opacity 0.3) on both the icon and text so they're legible against light photos
- Alternatively: a semi-transparent dark pill behind the logo+text (dark at 40-50% opacity, rounded corners). Implementation can pick whichever looks better.

### Progress Element Detail

- **With photo:** compact overlay pill in the bottom-right corner of the photo inset area. Format: "3 of 14" with a tiny progress ring or just the text. White text on semi-transparent dark pill. Neighborhood name can be omitted here since it's in the text panel below.
- **Without photo:** larger treatment, centered in the main content area. Can include the neighborhood name: "3 of 14 in Bernal Heights."

### Amber Frame Detail

- brandAmber `#D4882B` background, visible as a border around the photo
- Frame width: ~16pt logical (48px rendered). Uniform on all four sides of the photo area.
- The bottom text panel sits below the framed photo area and extends to the card edges (no amber frame around the text panel, just around the photo).

---

## 6. Integration Points

- **ShareCardView.swift** — modify both photo and no-photo layouts
- **StairwayBottomSheet.swift** — pass neighborhood progress data (walked count, total count) to `ShareCardView`. The bottom sheet already has access to `StairwayStore` and can query `WalkRecord` by neighborhood.
- **StairShape** (in `TeardropPin.swift`) — already defined, reuse in the card's logo overlay
- **AppColors** — use `brandAmber` for frame, `brandOrange` for no-photo background and URL text

---

## 7. Constraints

- `ShareCardView` params will expand: add `neighborhoodWalked: Int` and `neighborhoodTotal: Int`. The caller in `StairwayBottomSheet` must compute these before generating the card.
- The StairShape is defined in `TeardropPin.swift` which is in the iOS target. It should already be accessible from `ShareCardView.swift` (same target). No file moves needed.
- Photo legibility: the logo overlay must work against both dark and light photos. A shadow or dark pill behind the text handles this.
- Keep the `ImageRenderer` approach and 3x scale. No changes to the rendering pipeline.

---

## 8. Acceptance Criteria

- [ ] Photo cards show a brandAmber frame around the photo (not edge-to-edge)
- [ ] White StairShape logo + "SF Stairways" text overlaid on photo, top-left area
- [ ] Logo overlay is legible against both light and dark photos (shadow or pill)
- [ ] Neighborhood progress appears on card (e.g., "3 of 14")
- [ ] No-photo cards show amber frame around brandOrange content area with logo + progress
- [ ] Bottom text panel shows stairway name, neighborhood, height pill, tagline, URL
- [ ] Card dimensions remain 1080x1920 (9:16 portrait)
- [ ] brandAmber `#D4882B` used for frame, brandOrange for accents
- [ ] No crashes or performance regressions during card generation
- [ ] Cards look intentional and branded when shared to Instagram Stories / Messages
- [ ] Feedback loop prompt has been run

---

## 9. Files Likely Touched

- `ios/SFStairways/Views/ShareCardView.swift` — redesign both layouts, add logo overlay, amber frame, progress element
- `ios/SFStairways/Views/StairwayBottomSheet.swift` — compute and pass neighborhood walked/total counts to `ShareCardView`
