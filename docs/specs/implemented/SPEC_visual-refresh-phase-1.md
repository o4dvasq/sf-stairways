# SPEC: Visual Refresh Phase 1 — Light Mode, Warm Palette, Typography

**Project:** SF Stairways (iOS)
**Date:** 2026-03-29
**Status:** Ready for CoWork review

---

## 1. Objective

Shift the app's visual identity from dark-mode utility to a warm, light-first aesthetic that feels like a local's companion to San Francisco — not a fitness tracker. This is the foundational layer that all subsequent visual refinements will build on.

Four changes in this spec:
- Light mode as the default appearance
- Warmer orange palette (terracotta family)
- Progress ring color changed from green to the new warm orange
- SF Pro Rounded for display typography (headers, large numbers)

---

## 2. Scope

**In scope:**
- AppColors.swift: new/updated color tokens
- All views: light-mode-first color treatment
- ProgressTab: ring stroke color change
- Typography: display-size text switches to SF Pro Rounded
- SplashView: updated to harmonize with new palette
- Dark mode: still supported, but light is the default and the primary design target

**Out of scope:**
- Pin redesign (unchanged — existing pin colors adapt to new tokens)
- Card layout/content changes on Progress tab
- Neighborhood elevation work (separate spec)
- Map styling or background treatments
- Empty state copy changes
- Tab bar restructuring

---

## 3. Business Rules

- Light mode is the default appearance. The app should look right on a bright San Francisco afternoon.
- Dark mode remains fully functional (system toggle). Colors should be defined with light/dark variants where needed.
- The warm orange is the brand anchor. It replaces `brandOrange` everywhere that token is used.
- `walkedGreen` remains the color for the walked state on pins and indicators. Green = "done." Orange = brand/progress/saved.
- The progress ring changes from green to warm orange. This reinforces the brand and separates "progress toward a goal" (orange) from "this specific stairway is walked" (green).
- SF Pro Rounded is used for display text only: screen titles, large stat numbers, the progress ring number. Body text, labels, captions, and UI controls remain SF Pro (default system font).

---

## 4. Color Palette Changes

### Updated tokens

| Token | Current | New (Light) | New (Dark) | Usage |
|-------|---------|-------------|------------|-------|
| `brandOrange` | #E8602C | #D4724E | #E07A52 | Saved pins, saved indicators, progress ring, brand accents |
| `brandOrangeDark` | #C04A1A | #B85A38 | #C46842 | Selected/pressed states of brandOrange |
| `accentAmber` | #E8A838 | #E8A838 | #E8A838 | Splash screen, secondary warm accent (unchanged value, but now available for broader use) |

### New tokens

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `surfaceBackground` | #FAFAF7 | #1C1C1E (system) | Primary screen background — warm white, not blue-white |
| `surfaceCard` | #FFFFFF | #2C2C2E | Card/cell backgrounds |
| `surfaceCardElevated` | #F5F2ED | #3A3A3C | Grouped section backgrounds, stat cards |
| `textPrimary` | #1A1A1A | #F5F5F5 | Primary text |
| `textSecondary` | #6B6B6B | #A0A0A0 | Secondary labels, captions |
| `divider` | #E8E4DF | #3A3A3C | List separators, section dividers — warm-tinted, not cold gray |

### Unchanged tokens

| Token | Value | Notes |
|-------|-------|-------|
| `forestGreen` | #2D5F3F | Tab tint, filter chips, active search tabs — unchanged |
| `walkedGreen` | #4CAF50 | Walked pins, walked state indicators — unchanged |
| `walkedGreenDim` | #78B47D | Unchanged |
| `actionGreen` | #4CAF50 | Unchanged |
| `unwalkedSlate` | #789094 | Unsaved pins — may need light/dark variants for contrast; CoWork to evaluate |
| `closedRed` | #B0706F | Unchanged |

### Splash screen
- Background shifts to `brandOrange` (the new warm terracotta) instead of `accentAmber`. This makes the splash the brand moment rather than an outlier color. The three-stairs logo renders in white on the warm orange field.

---

## 5. Typography Changes

**Display text — SF Pro Rounded:**
- Screen titles ("Progress", "Stairways")
- Large stat numbers (the "48" in the progress ring, "1285 ft", "8 / 53", "5")
- Stat card labels ("Total height climbed", "Neighborhoods", etc.)
- Neighborhood section headers in list and progress views

**Body text — SF Pro (system default, unchanged):**
- Stairway names in list rows and detail view
- Notes, captions, button labels
- Search input text
- Filter chip labels
- All other UI text

**Implementation note:** SF Pro Rounded is a system font available on iOS via `.rounded` design in UIFontDescriptor or the SwiftUI `.font(.system(.title, design: .rounded))` modifier. No custom font file needed. No dependency.

---

## 6. Progress Ring Change

The completion ring on the Progress tab changes:
- **Stroke color:** `walkedGreen` → `brandOrange` (new warm terracotta)
- **Track color (unfilled portion):** adapt to light/dark — light gray on light, dark gray on dark
- **The number inside the ring** and "of 382" text should use `textPrimary` on the new `surfaceBackground`

This decouples the ring from the walked-state color system. The ring represents overall journey progress (brand = orange). Individual walked indicators on pins and lists stay green.

---

## 7. Screen-by-Screen Impact Summary

**All screens:** Background changes from near-black to `surfaceBackground`. Text colors adapt to light palette.

**Progress tab:** Ring goes orange. Stat cards use `surfaceCardElevated`. Numbers and labels get Rounded treatment. Neighborhood breakdown section uses `surfaceCard` cells.

**List tab:** Warm white background. Section headers (neighborhood names) get Rounded treatment. Row dividers use warm `divider` token. Search bar adapts to light surface.

**Detail view (bottom sheet / StairwayDetail):** Card background becomes `surfaceCard`. The walked/saved state card adapts colors for light background. Photo grid sits on `surfaceBackground`.

**Map tab:** Filter chips, progress card overlay, and bottom search bar adapt to light palette. The map itself (Apple Maps) will render in its own light style by default. Around Me chip and neighborhood label adapt.

**Search panel:** Light background, warm dividers, Rounded tab headers.

**Splash screen:** `brandOrange` background with white logo.

**Toast:** Retains dark-on-translucent treatment (it needs contrast against any background).

---

## 8. Constraints

- No custom font files. SF Pro Rounded is accessed via the system `.rounded` font design.
- No new third-party dependencies.
- Dark mode must remain functional — all new color tokens need light/dark variants.
- Pin colors (the teardrop pins on the map) use existing tokens and are unchanged in this spec. If `unwalkedSlate` needs contrast adjustment for light mode, that's an implementation detail for CoWork.
- The map background is Apple Maps' default — we don't control its light/dark appearance beyond respecting the system color scheme.

---

## 9. Acceptance Criteria

- [ ] App launches in light mode by default on a device set to light appearance
- [ ] Dark mode still works correctly when the device is set to dark appearance
- [ ] All orange UI elements use the new warmer `brandOrange` value
- [ ] Progress ring on Progress tab renders in `brandOrange`, not green
- [ ] Screen titles and stat numbers render in SF Pro Rounded
- [ ] Body text, stairway names, and UI controls render in standard SF Pro
- [ ] Splash screen shows white logo on `brandOrange` background
- [ ] No cold grays — backgrounds and dividers carry a warm tint in light mode
- [ ] Walked-state indicators (pins, checkmarks) remain `walkedGreen`
- [ ] Feedback loop prompt has been run

---

## 10. Files Likely Touched

- `AppColors.swift` — new tokens, updated values, light/dark adaptive colors
- `ProgressTab.swift` — ring stroke color, typography modifiers
- `ContentView.swift` — if preferred color scheme is set at app level
- `SplashView.swift` — background color change
- `ListTab.swift` — section header typography, background colors
- `StairwayRow.swift` — divider color, background
- `StairwayDetail.swift` — card backgrounds, typography
- `StairwayBottomSheet.swift` — background, text colors
- `MapTab.swift` — filter chips, progress card, search bar colors
- `SearchPanel.swift` — background, tab styling
- `ToastView.swift` — verify contrast on light backgrounds
- `TeardropPin.swift` — verify pin contrast on light map; `unwalkedSlate` may need adjustment
