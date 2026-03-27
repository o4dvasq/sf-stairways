SPEC: iOS UI Improvements v1 | Project: sf-stairways | Date: 2026-03-23 | Status: Implemented (icon updated to v7)

---

## 1. Objective

Five visual improvements to the iOS app: splash screen, new app icon, larger walked-stairway markers, redesigned bottom sheet card with action-oriented color hierarchy, and a progress overlay card on the map view.

## 2. Scope

1. Launch/splash screen using provided artwork
2. New app icon — simple gradient + 3-step stair motif (replaces current green/white icon)
3. Walked-stairway map markers 1.5x the size of unwalked markers
4. Bottom sheet card redesign for walked stairways — "Walked" label, color hierarchy changes
5. Progress card overlay on map view (bottom-right corner)

Out of scope: data model changes, CloudKit, new tabs, navigation changes

## 3. Business Rules

**Color hierarchy principle:** Bright colors = actionable ("click here"). Dim colors = informational only.

This principle drives changes #4 and should be applied consistently going forward.

## 4. Data Model / Schema Changes

None. All changes are view-layer only. Step counts come from `WalkRecord.stepCount`, heights from `Stairway.heightFt`.

## 5. UI / Interface

### 5a. Splash Screen

Add a launch screen using the "SF Stairs" illustration artwork.

- Image file: `ios/SFStairways/Resources/splash_image.png` (Oscar will place this — it's the warm-toned illustration with Golden Gate Bridge, stairways, person climbing, "SF STAIRS" text, retro/70s color palette)
- Display as a centered, full-bleed image on a background that matches the image edges (warm golden/amber)
- Use SwiftUI splash screen approach: either a `LaunchScreen.storyboard` with the image, or an `Info.plist` launch screen configuration
- Show for ~1.5 seconds minimum (enough to load data), then transition to the map tab

### 5b. App Icon

**Final icon: `ios/SFStairways/Resources/AppIcon_v7.png`** (1024x1024 PNG, generated via Pillow)

- **Background:** Vertical linear gradient — bright yellow (#FFC814) at top → deep burnt orange (#82280A) at bottom
- **Foreground:** Solid 3-step ascending staircase filled with the reversed gradient (dark amber at top → bright cream at bottom), creating a counterpoint to the background
- **Border:** Bold white outline (~66px) around the stair silhouette, giving crisp definition at all icon sizes
- **Shape:** Standard iOS rounded rectangle (system-masked)

To apply: drag `AppIcon_v7.png` into the Xcode asset catalog as the 1024x1024 App Store icon. Xcode auto-generates smaller sizes.

### 5c. Walked Stairway Markers — 1.5x Size

In `StairwayAnnotation.swift`, make walked stairways visually larger so they're easy to distinguish at a glance:

**Current sizes:**
- Default (unwalked): 14pt
- Selected: 20pt

**New sizes:**
- Unwalked: 14pt (unchanged)
- Walked (not selected): 21pt (14 × 1.5)
- Walked + selected: 28pt
- Unwalked + selected: 20pt (unchanged)

The `frame(width:height:)` and stroke `lineWidth` should scale proportionally. The walked markers should feel noticeably bigger but not cluttered.

### 5d. Bottom Sheet Card — Walked Stairway State

When a walked stairway's card appears in `StairwayBottomSheet.swift`:

**Checkmark circle (top-right):**
- Currently: bright green (`walkedGreen`) circle with white checkmark
- Change to: **dim green** — use a muted/desaturated version of walkedGreen (suggestion: `Color(red: 120/255, green: 180/255, blue: 125/255)` or ~30% opacity overlay on walkedGreen). This is informational, not a call to action.
- Add **"Walked"** in bold white text directly beneath the checkmark circle, `font(.caption)`, `.fontWeight(.bold)`

**"View Details" button:**
- Currently: `Color.forestGreen` background (dark green, #2D5F3F)
- Change to: **bright green** — use the current `walkedGreen` (#4CAF50) as the button background. This is the action — it should pop.

**For unwalked stairways**, the card stays the same — the "+" circle is already the call to action.

Add two new color constants to `AppColors.swift`:
```swift
static let walkedGreenDim = Color(red: 120/255, green: 180/255, blue: 125/255)  // informational
static let actionGreen = Color(red: 76/255, green: 175/255, blue: 80/255)       // same as walkedGreen, used for CTA buttons
```

### 5e. Progress Card Overlay — Map View

Add a small, semi-transparent card in the bottom-right corner of `MapTab.swift`, visible at all times on the map:

**Content:**
- Number of stairways climbed (count of WalkRecords where `walked == true`)
- Total height climbed (sum of `heightFt` for walked stairways, formatted as "X ft")
- Total steps (sum of `stepCount` from WalkRecords where `walked == true`, formatted as "X steps")

**Design:**
- Compact card: ~120pt wide, auto-height
- Background: `.ultraThinMaterial` (frosted glass) with rounded corners (12pt radius)
- Text: Left-aligned, three lines:
  - `"8 stairways"` — `.font(.caption)`, `.fontWeight(.semibold)`
  - `"1,240 ft"` — `.font(.caption2)`, `.foregroundStyle(.secondary)`
  - `"3,450 steps"` — `.font(.caption2)`, `.foregroundStyle(.secondary)`
- Position: bottom-right, with padding to avoid map controls
- If a value is zero or unavailable, show "—" instead of "0"
- Card should not intercept map gestures — use `.allowsHitTesting(false)`

**Data source:** Query `walkRecords` (already available in MapTab) joined against `store.stairways` to look up `heightFt`. Step counts come from `WalkRecord.stepCount`.

## 6. Integration Points

- Xcode asset catalog: App icon and splash image need to be added/updated in the Xcode project at `~/Desktop/SFStairways/`
- Launch screen: May require `Info.plist` changes or a `LaunchScreen.storyboard` depending on approach

## 7. Constraints

- All changes are in SwiftUI views and resources — no model or service changes
- The Xcode project is not version-controlled (lives at `~/Desktop/SFStairways/`), so asset catalog changes must be done manually in Xcode after source files are updated
- Oscar will place the splash screen image at `ios/SFStairways/Resources/splash_image.png` before implementation begins
- The app icon should be generated as a PNG, not require manual design tools

## 8. Acceptance Criteria

- [ ] App launches with the SF Stairs illustration as splash screen for ~1.5s
- [ ] App icon on home screen shows gradient yellow→orange with 3-step stair motif
- [ ] Walked stairway markers on map are visibly larger than unwalked ones (~1.5x)
- [ ] Bottom sheet for walked stairways shows dim green checkmark + bold "Walked" label
- [ ] "View Details" button uses bright green (walkedGreen) for walked stairways
- [ ] Progress card visible in bottom-right of map showing stairways climbed, total height, total steps
- [ ] Color hierarchy is consistent: bright = action, dim = information
- [ ] No regressions in unwalked stairway card appearance
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Resources/AppColors.swift` — Add `walkedGreenDim`, `actionGreen` colors, plus warm gradient colors for icon
- `ios/SFStairways/Views/Map/StairwayAnnotation.swift` — Conditional sizing for walked markers
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — Dim checkmark, "Walked" label, bright "View Details" button
- `ios/SFStairways/Views/Map/MapTab.swift` — Add progress card overlay in ZStack
- `ios/SFStairways/SFStairwaysApp.swift` — Launch screen configuration (if using SwiftUI approach)
- `ios/SFStairways/Resources/splash_image.png` — NEW (Oscar provides)
- `ios/SFStairways/Resources/AppIcon_v7.png` — NEW (final icon, generated by Cowork via Pillow; drag into Xcode asset catalog)
- Xcode project: Asset catalog updates for icon and splash image (manual step)
