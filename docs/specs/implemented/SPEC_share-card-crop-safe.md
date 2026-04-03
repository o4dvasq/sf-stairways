# SPEC: Share Card Crop-Safe Layout
**Project:** sf-stairways | **Date:** 2026-04-03 | **Status:** Ready for Implementation

---

## 1. Objective

Fix the share card layout so that branding elements (logo overlay, progress pill) survive cropping in Messages and Instagram Posts. The current 9:16 card works perfectly in Stories and Reels but gets clipped from the top in square (1:1) and portrait (4:5) contexts, cutting off the "SF Stairways" logo pill and part of the photo.

---

## 2. Scope

**In scope:**
- Reposition the logo overlay from top-left to bottom-left of the photo area
- Ensure all branding survives a center crop to 4:5 or 1:1
- Keep the card dimensions at 1080x1920 (9:16)

**Out of scope:**
- Generating multiple card sizes (too complex for the benefit)
- Changes to the no-photo layout (already has branding centered/lower)
- Changes to the bottom text panel
- Changes to the amber frame width

---

## 3. Business Rules

1. **All branding must be in the bottom 60% of the card.** Messages crops to roughly square from center. Instagram Posts crop to 4:5 from center. The bottom text panel is safe in both cases. The photo area's bottom half is safe. The top ~20-25% of the card is the danger zone.

2. **Logo overlay moves to bottom-left of the photo inset.** Currently at top-left with `alignment: .topLeading`. Move to `alignment: .bottomLeading`. The progress pill is already at bottom-right (`.bottomTrailing`), so the two pills will sit on opposite sides of the same horizontal line at the bottom of the photo.

3. **Padding from edges stays the same (12pt).** The logo pill and progress pill should both be 12pt from the bottom and sides of the photo inset.

4. **No-photo layout is already fine.** The stairway name, neighborhood, and progress pill are all centered/lower in the brandOrange content area. No changes needed.

5. **Stories/Reels still look great.** Moving the logo lower doesn't hurt the 9:16 layout. The photo is the hero; the branding sits at the bottom of the photo like a watermark. This is actually a more natural placement.

---

## 4. Data Model / Schema Changes

None.

---

## 5. UI / Interface

### With Photo Layout: Before (current)

```
┌──────────────────────────┐
│  amber frame             │
│  ┌────────────────────┐  │
│  │ [logo]             │  │  <- TOP-LEFT (gets cropped!)
│  │                    │  │
│  │    photo           │  │
│  │                    │  │
│  │            [19/23] │  │  <- bottom-right (safe)
│  └────────────────────┘  │
│  Stairway Name           │
│  Neighborhood            │
│  [pills]                 │
│  sfstairways.app         │
└──────────────────────────┘
```

### With Photo Layout: After (fixed)

```
┌──────────────────────────┐
│  amber frame             │
│  ┌────────────────────┐  │
│  │                    │  │  <- top is now clean photo only
│  │                    │  │
│  │    photo           │  │
│  │                    │  │
│  │ [logo]     [19/23] │  │  <- BOTH at bottom (safe!)
│  └────────────────────┘  │
│  Stairway Name           │
│  Neighborhood            │
│  [pills]                 │
│  sfstairways.app         │
└──────────────────────────┘
```

### Crop Preview: How the card appears in different contexts

**Instagram Stories / Reels (9:16):** Full card visible, no crop. Logo at bottom-left of photo, progress at bottom-right. Clean.

**Instagram Posts (4:5):** Top and bottom edges cropped. The amber frame top and part of the photo's upper area get clipped. Logo and progress pills are in the lower portion of the photo, safely visible. Bottom text panel is partially visible.

**Messages (square-ish):** More aggressive crop from top and bottom. The photo's lower portion with both pills is visible. Bottom panel with stairway name is visible. Branding survives.

---

## 6. Integration Points

- **ShareCardView.swift** — one line change: swap `.topLeading` to `.bottomLeading` on the logo overlay alignment

---

## 7. Constraints

- With both the logo and progress pill at the bottom of the photo, make sure they don't overlap on narrow photos or long stairway names. The logo is left-aligned and the progress pill is right-aligned, so they should have natural spacing. If a collision is possible, add a minimum spacing check or cap the logo pill width.

---

## 8. Acceptance Criteria

- [ ] Logo overlay ("SF Stairways" pill) is positioned at bottom-left of the photo inset
- [ ] Progress pill ("19 of 23") remains at bottom-right of the photo inset
- [ ] Logo and progress pill do not overlap
- [ ] Card still looks good in full 9:16 (Stories, Reels)
- [ ] Card branding is visible when shared to Messages (center crop)
- [ ] Card branding is visible when shared to Instagram Posts (4:5 crop)
- [ ] No-photo layout is unchanged
- [ ] Feedback loop prompt has been run

---

## 9. Files Likely Touched

- `ios/SFStairways/Views/ShareCardView.swift` — change `.overlay(alignment: .topLeading)` to `.overlay(alignment: .bottomLeading)` on the logo overlay (line 50 area)
