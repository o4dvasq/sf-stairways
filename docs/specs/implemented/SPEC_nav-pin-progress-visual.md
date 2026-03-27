# SPEC: Nav Bar Redesign + Pin Icon Fix + Progress Card Header
**Project:** sf-stairways | **Date:** 2026-03-26 | **Status:** Ready for Implementation

---

## 1. Objective

Three visual fixes to the Map tab:

1. Restyle the custom top navigation bar: `brandOrange` background, white text, app icon staircase graphic centered.
2. Fix pin rendering where the white-filled `StairShape` may bleed outside the teardrop bulb area.
3. Add a `brandOrange` header bar with white "Progress" title to the floating progress card (bottom-right).

All orange in the app unifies to `brandOrange` (#E8602C). `accentAmber` (#E8A838) remains splash-screen only and is not used elsewhere (until Hard Mode spec introduces it for badges).

---

## 2. Scope

**In scope:**
- Top navigation bar background and text color
- App icon asset centered in nav bar
- StairShape / TeardropPin compositing review and fix
- Progress card header bar
- New `brandOrange` color token in AppColors.swift

**Out of scope:**
- Any changes to pin size, shape dimensions, or state logic
- Tab bar styling
- Filter chip styling
- Any other views outside MapTab

---

## 3. Business Rules

1. **New color token.** Add `brandOrange` (#E8602C) to `AppColors.swift`. All top bar and progress card header orange UI elements use this token.
2. **Nav bar colors.** `brandOrange` background, white title text "SF Stairways", white button icons.
3. **Pin icons must not bleed outside the teardrop bulb.** The custom `StairShape` (white fill) must be clipped to the circular bulb region of the teardrop, not extend into the pointed tail.
4. **Progress card header.** Solid `brandOrange` bar at top of the floating card, white "Progress" text, consistent corner radius with the card.

---

## 4. Data Model / Schema Changes

None.

---

## 5. UI / Interface

### 5a. New Color Token (AppColors.swift)

Add to the existing color extensions:

```swift
static let brandOrange = Color(red: 0.91, green: 0.376, blue: 0.173)  // #E8602C
```

Also update the two top-bar semantic colors that currently point to white/dark:

```swift
static let topBarBackground = Color.brandOrange   // was: Color.white
static let topBarText = Color.white                // was: Color(hex: "1A1A1A")
```

### 5b. Top Navigation Bar (MapTab.swift)

**Current implementation** (custom HStack overlay, NOT a system `.navigationBar`):
- White background with drop shadow
- Title "SF Stairways" in `brandAmber`
- Search button: 32px circle, `.systemGray5` background
- AroundMe button: 32px circle, amber when active

**New:**
```
┌──────────────────────────────────────────────────┐
│  [brandOrange background, full width]            │
│                                                  │
│  SF Stairways    [staircase icon]   🔍  ◎       │
│  (white, left)   (center, 28pt)   (white icons)  │
└──────────────────────────────────────────────────┘
```

**Implementation changes to the existing HStack:**

1. **Background:** Change the HStack's background from white/shadow to `Color.brandOrange` (or use the updated `Color.topBarBackground` semantic token). Remove the existing drop shadow — the solid orange makes it unnecessary.

2. **Title text:** Change from `.foregroundColor(.brandAmber)` to `.foregroundColor(.white)`.

3. **Center logo:** Add an `Image("StairwayLogo")` (or whatever the asset name is — see Constraints) as a `ToolbarItem(placement: .principal)` equivalent, or simply insert it in the HStack between the title and the trailing buttons.
   - Size: 28×28pt, `.resizable()`, `.aspectRatio(contentMode: .fit)`, `.frame(width: 28, height: 28)`.
   - If the asset is a full-color PNG: render as-is.
   - If the asset supports template rendering: apply `.renderingMode(.template).foregroundColor(.white)`.
   - **If no standalone staircase asset exists in Assets.xcassets** (only the full AppIcon), skip the center logo for now and add a TODO comment. Do not attempt to reference "AppIcon" directly — iOS does not allow rendering the app icon via `Image("AppIcon")`.

4. **Button icons:** Change search and AroundMe icon colors to `.white`. Change button background circles from `.systemGray5` to `Color.white.opacity(0.2)` (subtle contrast on orange).

5. **AroundMe active state:** When AroundMe filter is active, button background becomes `Color.white.opacity(0.35)` instead of `.brandAmber`.

6. **Status bar:** Add `.preferredColorScheme(.dark)` to the MapTab view to force white status bar content on the orange background. Alternatively, use `.toolbarColorScheme(.dark, for: .navigationBar)` if the view is embedded in a NavigationStack.

### 5c. Pin Icon Fix (TeardropPin.swift)

**Current code structure** (from `StairwayPin` view body):
```swift
ZStack {
    TeardropShape()
        .fill(fillColor)
        // shadows...
    StairShape()
        .fill(Color.white)
        .frame(width: iconSize, height: iconSize)
        // centered in the bulb area
}
```

**Root cause hypothesis:** The `StairShape` is positioned at the ZStack center, but the ZStack's frame is taller than wide (e.g., 44×55pt). The center of the ZStack is the center of the full teardrop including the tail. The `StairShape` needs to be offset upward to sit in the bulb (top circle) area, not the geometric center.

**Fix approach:**
1. The icon should be vertically offset so it centers in the **bulb** (top circular area), not the full teardrop. The bulb center is at `y = pinWidth / 2` from the top. The ZStack center is at `y = pinHeight / 2`. The offset needed is approximately `-(pinHeight - pinWidth) / 4` (half the difference between height and width, halved again).

2. Alternatively, clip the `StairShape` to a circle matching the bulb diameter:
```swift
StairShape()
    .fill(Color.white)
    .frame(width: iconSize, height: iconSize)
    .offset(y: -(pinHeight - pinWidth) * 0.25)  // shift up into bulb center
```

3. **Verify visually** that the white StairShape does not extend below the bulb into the tapered tail region at any pin size (38, 44, 52pt wide). The icon size at 42% of pin width should be safe, but confirm.

4. Do NOT change: pin sizes, StairShape geometry, fill colors, opacity rules, shadow rules, or animation behavior.

### 5d. Progress Card Header (MapTab.swift)

**Current:** Floating card with 3 stacked text lines (walked count, height, steps), 120px width, `.ultraThinMaterial` background, 12px corner radius, bottom-right positioned.

**New:**
```
┌─────────────────────┐
│  Progress           │  ← brandOrange bar, white text, rounded top corners
├─────────────────────┤
│  8 walked           │
│  1,240 ft           │
│  847 steps          │
└─────────────────────┘
```

**Implementation:**
1. Wrap existing content in a `VStack(spacing: 0)`.
2. Add header as first child of the VStack:
```swift
HStack {
    Text("Progress")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(.white)
    Spacer()
}
.padding(.horizontal, 8)
.padding(.vertical, 4)
.background(Color.brandOrange)
```
3. Existing stat rows remain unchanged below the header.
4. The outer card shape (`RoundedRectangle(cornerRadius: 12)`) stays. Use `.clipShape(RoundedRectangle(cornerRadius: 12))` on the outer VStack so the orange header clips to the top corners.
5. Keep `.ultraThinMaterial` as the card background behind the stat rows. The header bar's `brandOrange` fill will cover the material in the top portion.
6. Keep `.allowsHitTesting(false)`.

---

## 6. Integration Points

| File | Change |
|------|--------|
| `Resources/AppColors.swift` | Add `brandOrange`, update `topBarBackground` and `topBarText` |
| `Views/Map/MapTab.swift` | Nav bar HStack colors/backgrounds; progress card header |
| `Views/Map/TeardropPin.swift` | StairShape vertical offset to center in bulb |

---

## 7. Constraints

- **App icon asset:** Before referencing an image asset for the nav bar center logo, check what image assets exist in `Assets.xcassets` besides `AppIcon.appiconset`. If only the standard app icon exists, skip the center logo and leave a `// TODO: Add standalone staircase logo asset` comment. iOS does not support rendering the app icon via `Image("AppIcon")`.
- No third-party packages.
- Pin state logic, sizes, and colors are unchanged — this is a positioning/compositing fix only.
- `accentAmber` (#E8A838) usage remains splash-screen only in this spec. (The Hard Mode spec introduces it for unverified badges — that's a separate change.)

---

## 8. Acceptance Criteria

- [ ] `brandOrange` (#E8602C) color exists in AppColors.swift
- [ ] Nav bar background is `brandOrange` with white title text "SF Stairways"
- [ ] Nav bar button icons are white with subtle translucent backgrounds
- [ ] If a standalone staircase asset exists, it appears centered in nav bar at 28pt
- [ ] Status bar content is white/light on the orange background
- [ ] StairShape icon is visually centered in the teardrop bulb (not the full pin), at all three pin sizes (38, 44, 52pt)
- [ ] No white bleed from StairShape extends into the tapered tail of any pin
- [ ] Progress card has a `brandOrange` header bar with white "Progress" text, clipped to top corners
- [ ] Progress card stat content (walked, height, steps) is unchanged
- [ ] No usage of `accentAmber` outside `SplashView`
- [ ] Feedback loop prompt has been run

---

## 9. Files Likely Touched

| File | Change |
|------|--------|
| `Resources/AppColors.swift` | Add `brandOrange` (#E8602C); update `topBarBackground` → `brandOrange`, `topBarText` → white |
| `Views/Map/MapTab.swift` | Nav bar HStack: orange bg, white text/icons, translucent button backgrounds; progress card: add header VStack with brandOrange bar |
| `Views/Map/TeardropPin.swift` | Offset `StairShape` vertically to center in teardrop bulb, not full pin center |
