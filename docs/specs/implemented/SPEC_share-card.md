# SPEC: In-App Share Card
**Project:** sf-stairways | **Date:** 2026-04-02 | **Status:** Ready for Implementation

---

## 1. Objective

Allow users to generate and share a visually appealing card image after logging a stairway walk. The card displays stairway details and optionally a user photo, and includes a CTA that drives traffic back to the landing page. Shared via the native iOS share sheet.

---

## 2. Scope

**In scope:**
- Share button on `StairwayBottomSheet` for walked stairways
- Card image generation (SwiftUI → UIImage)
- Card layout with stairway name, neighborhood, height, optional photo, CTA, and logo
- iOS share sheet (`UIActivityViewController`) with the generated image
- Portrait orientation optimized for Instagram Stories

**Out of scope:**
- Direct posting to Instagram/Threads/Strava (Apple/Meta APIs don't support this — user posts the shared image themselves)
- Card templates or customization options
- Sharing unwalked stairways
- Any backend or analytics for share tracking
- Step count display (removed from app per prior spec)

---

## 3. Business Rules

1. **Share is only available for walked stairways.** The share button does not appear on stairways without a `WalkRecord` where `walked == true`.

2. **Share button location.** Add a share icon (`square.and.arrow.up`) to the `StairwayBottomSheet` toolbar/header area, near the stairway name. It should be discoverable but not intrusive.

3. **Card is generated locally.** No network requests. The card is rendered as a `UIImage` from a SwiftUI view using `ImageRenderer`.

4. **Photo is optional.** If the stairway's `WalkRecord` has associated `WalkPhoto` records, use the first photo's `imageData` as a background or featured image on the card. If no photos exist, the card renders without a photo (text-only layout with brand color background).

5. **Landing page URL on card.** The card includes `sfstairways.app` as visible text (confirmed domain). This is not a live link (it's an image) — it's there so viewers know where to find the app.

6. **Brand consistency.** The card follows the app's Layer 1 aesthetic: clean, minimal, brand orange `#E8602C` as accent, white or dark background. Not a promotional flyer.

7. **Portrait aspect ratio.** Card dimensions should be 1080×1920 pixels (9:16), optimized for Instagram Stories. This also works well for Messages and other share targets.

---

## 4. Data Model / Schema Changes

None. All data needed for the card already exists in `WalkRecord`, `WalkPhoto`, `StairwayOverride`, and the `Stairway` catalog.

---

## 5. UI / Interface

### Share Button Placement

In `StairwayBottomSheet`, for walked stairways only:
- Add a share icon button (`square.and.arrow.up`) in the header area alongside the stairway name
- Tapping generates the card and immediately presents the share sheet
- Use `brandOrange` tint for the icon, consistent with other interactive elements

### Card Layout — With Photo

```
┌──────────────────────────┐
│                          │
│    [User's photo]        │  ← top ~60% of card, photo fills width
│    (full bleed)          │
│                          │
│                          │
├──────────────────────────┤
│                          │
│  Stairway Name           │  ← large, prominent, serif or rounded font
│  Neighborhood            │  ← smaller, secondary color
│                          │
│  ┌────────┐ ┌──────────┐ │
│  │ 115 ft │ │ Walked ✓ │ │  ← stat pills (height, walked badge)
│  └────────┘ └──────────┘ │
│                          │
│  Climb every stairway    │  ← tagline, small
│  in San Francisco        │
│                          │
│  sfstairways.app         │  ← URL, brand orange
│  [logo]                  │  ← three-step mark, small, bottom corner
│                          │
└──────────────────────────┘
```

### Card Layout — Without Photo

```
┌──────────────────────────┐
│         (brand orange    │
│          gradient or     │
│          solid bg)       │
│                          │
│  Stairway Name           │  ← large, white text
│  Neighborhood            │  ← smaller, white/cream
│                          │
│  ┌────────┐ ┌──────────┐ │
│  │ 115 ft │ │ Walked ✓ │ │  ← stat pills
│  └────────┘ └──────────┘ │
│                          │
│  Climb every stairway    │
│  in San Francisco        │
│                          │
│  sfstairways.app         │
│  [logo]                  │
│                          │
└──────────────────────────┘
```

### Share Sheet

- Use `UIActivityViewController` (via SwiftUI's `ShareLink` or a UIKit wrapper)
- Share the generated `UIImage`
- Include the text "Climb every stairway in SF — sfstairways.app" as the share text (appears in Messages, email, etc. alongside the image)

---

## 6. Integration Points

- **StairwayBottomSheet** — add share button to walked stairway state
- **WalkRecord / WalkPhoto** — read photo data for card generation
- **StairwayStore** — resolve height via `resolvedHeightFt(for:override:)`
- **StairwayOverride** — curator height data (existing query pattern in StairwayBottomSheet)
- **AppColors** — use `brandOrange` and existing color tokens
- **No network, no backend, no new dependencies**

---

## 7. Constraints

- `ImageRenderer` requires iOS 16+ (the app targets iOS 17+, so this is fine).
- Card rendering should be fast — no noticeable delay between tap and share sheet appearance.
- Photo decoding from `WalkPhoto.imageData` (externalStorage) may have a brief load time. If the photo isn't immediately available, render the no-photo variant rather than blocking.
- The three-step logo mark may not exist as an asset yet. If no logo asset is available, use the text "SF Stairways" in brand orange as the logo placeholder. Do not block the feature on logo availability.
- Font choice should use SF Pro Rounded (already used throughout the app for display text) for the stairway name, and standard SF Pro for secondary text.

---

## 8. Acceptance Criteria

- [ ] Share button appears on `StairwayBottomSheet` for walked stairways only
- [ ] Share button does not appear for unwalked stairways
- [ ] Tapping share generates a card image and opens the iOS share sheet
- [ ] Card displays: stairway name, neighborhood, height (if available), CTA text, landing page URL
- [ ] Card includes user photo when WalkPhoto records exist for the stairway
- [ ] Card renders cleanly without a photo when none exist
- [ ] Card is 1080×1920 portrait orientation
- [ ] Card uses brand orange `#E8602C` consistently
- [ ] Share sheet includes both image and text content
- [ ] No crashes or hangs during card generation
- [ ] Card looks good when shared to Messages (quick visual check)
- [ ] Feedback loop prompt has been run

---

## 9. Files Likely Touched

- `ios/SFStairways/Views/StairwayBottomSheet.swift` — add share button and share action
- `ios/SFStairways/Views/ShareCardView.swift` — new file: SwiftUI view that renders the card layout (used by `ImageRenderer`)
- `ios/SFStairways/Resources/AppColors.swift` — reference only (no changes expected)
