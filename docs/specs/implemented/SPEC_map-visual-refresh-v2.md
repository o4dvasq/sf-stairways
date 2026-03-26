# SPEC: Map Visual Refresh v2 — Amber Pins, Dark Map, Top Bar
**Project:** sf-stairways | **Date:** 2026-03-26 | **Status:** Ready for Implementation
**Depends on:** SPEC_map-redesign-ios.md (implemented)

---

## 1. Objective

Refine the iOS map experience based on Build 9 feedback. This spec adjusts the visual layer only: pin colors shift from orange/slate to a warm amber palette, all pin states get a uniform stair icon, the map gets a dark appearance, and the search/Around Me controls move from a bottom bar to a white top bar with floating circle buttons. No data model changes, no new features, no architectural changes.

---

## 2. Scope

**In scope:**
- Pin color palette change (orange → warm amber, add light green for saved)
- Pin icon unification (3-step stair silhouette on all states including walked)
- Dark map appearance via MapKit `.dark` color scheme
- White top bar with logo, search circle button, and Around Me circle button
- Filter pills repositioned below top bar with dark-background styling
- Bottom search bar removed (replaced by top bar search button)
- Around Me pill removed (replaced by top bar circle button)
- Updated app icon (solid white steps, equal riser sizing)

**Out of scope:**
- Data model or SwiftData changes (none needed)
- Search panel internals (tabs, fuzzy search behavior unchanged)
- Bottom sheet / detail card changes
- Around Me logic changes (neighborhood detection, adjacency, dimming all unchanged)
- Supabase / multi-user work
- App Store submission

---

## 3. Business Rules

### Top Bar
- White bar pinned below the Dynamic Island / status bar safe area
- Left side: "SF Stairways" text logo in amber (#D4882B)
- Right side: two circular icon buttons (32pt diameter, light gray background)
  - Search button (magnifying glass SF Symbol) — leftmost
  - Around Me button (location.fill SF Symbol) — rightmost
- Around Me button fills with amber when active
- Bar has a subtle bottom shadow to float above the dark map

### Filter Pills
- Horizontal row directly below the top bar, overlaying the map
- Pills: **All** | **Saved** | **Walked** | **Nearby**
- Active pill: filled with brand amber (#D4882B), white text
- Inactive pill: dark background (#333333), white text
- Behavior unchanged from v1 (radio selection, same filter logic)

### Pin Colors (revised palette)
- **Unsaved:** warm amber (#D4882B) at 50% opacity, small teardrop (24x30pt), 3-step stair icon in white
- **Saved:** light green (#81C784), medium teardrop (28x35pt), 3-step stair icon in white
- **Walked:** green (#4CAF50), medium teardrop (28x35pt), 3-step stair icon in white
- **Selected:** current state color darkened one step, scaled to 34x42pt, drop shadow
- **Dimmed (Around Me active, out of zone):** 30% opacity of current state color
- **Closed:** unchanged (slate, 40% opacity, existing behavior)

Visual priority when both saved and walked: walked (green) wins.

### Pin Icon (unified)
- All three states use the same 3-step stair silhouette icon (solid white fill, transparent background)
- Steps ascend left to right with uniform riser height and tread depth
- Must match the app icon silhouette
- Replaces the current mixed approach (no icon for unsaved, stair for saved, checkmark for walked)

### Search Trigger
- Tapping the search circle button in the top bar opens the existing full-screen search panel (SearchPanel.swift)
- The bottom search bar is removed entirely
- Search panel internals (Name/Street/Neighborhood tabs, live filtering, result tap behavior) remain unchanged

### Around Me Trigger
- Tapping the Around Me circle button in the top bar triggers the same AroundMeManager logic as the current pill button
- The floating "Around Me" capsule button above the bottom bar is removed
- When active, the circle button fills with amber; the "Nearby" filter pill also shows active state
- Neighborhood chip ("You're in [Name]") still appears on the map
- All dimming, toggle-off, and error toast behavior is unchanged

### Dark Map
- Apply `.preferredColorScheme(.dark)` or MapKit's `mapStyle` modifier to render the map in dark mode
- The map background should be dark/charcoal, matching the dark basemap aesthetic from the reference screenshots
- The white top bar provides contrast against the dark map

### App Icon Update
- Same 3-step stair silhouette used in pins
- Solid white fill for the stair shape (replacing gradient-fill-with-outline)
- All 3 steps: identical riser height, identical tread depth
- Background: existing yellow-to-brown gradient retained
- Deliver as replacement asset in Assets.xcassets at all required sizes

---

## 4. Data Model / Schema Changes

None. This spec is purely visual. No SwiftData, CloudKit, or bundled JSON changes.

---

## 5. UI / Interface

### Layout (mobile, iPhone)

```
┌─────────────────────────────┐
│  [status bar / Dynamic Island] │
│  ┌───────────────────────┐  │
│  │ SF STAIRWAYS    🔍  ◎ │  │  ← white top bar
│  └───────────────────────┘  │
│  [All] [Saved] [Walked] [Nearby]│  ← dark pills below top bar
│                              │
│         APPLE MAPS           │
│      (dark appearance)       │
│    🟠  🟢  🟡               │  ← amber=unsaved, green=walked,
│       🟢     🟡             │     light green=saved
│                              │
│     [You're in Noe Valley]   │  ← neighborhood chip (Around Me)
│                              │
│  ┌───────────────────────┐  │
│  │  ── Vulcan Stairway    │  │  ← bottom detail card (pin tapped)
│  │  Corona Heights        │  │
│  │  [Save] [Mark Walked]  │  │
│  └───────────────────────┘  │
│  [home indicator safe area]  │
└─────────────────────────────┘
```

### Pin Design (updated)

Teardrop shape unchanged (existing `TeardropShape` in TeardropPin.swift). Changes:

| State | Fill | Icon | Size |
|-------|------|------|------|
| Unsaved | #D4882B @ 50% | 3-step stair (white) | 24×30pt |
| Saved | #81C784 | 3-step stair (white) | 28×35pt |
| Walked | #4CAF50 | 3-step stair (white) | 28×35pt |
| Selected | Darkened variant | 3-step stair (white) | 34×42pt |

The stair icon should be a simple SwiftUI `Path` or SF Symbol custom asset: three equal rectangles stacked as ascending steps, left to right.

### Color Tokens (updated AppColors.swift)

```swift
// REPLACE existing values
static let brandAmber = Color(red: 212/255, green: 136/255, blue: 43/255)       // #D4882B — replaces brandOrange
static let brandAmberDark = Color(red: 181/255, green: 114/255, blue: 31/255)   // #B5721F — replaces brandOrangeDark
static let pinSaved = Color(red: 129/255, green: 199/255, blue: 132/255)        // #81C784 — new: saved state
static let pinSavedDark = Color(red: 102/255, green: 187/255, blue: 106/255)    // #66BB6A — new: saved selected

// KEEP existing values
static let walkedGreen       // #4CAF50 — unchanged
static let walkedGreenDark = Color(red: 56/255, green: 142/255, blue: 60/255)   // #388E3C — new: walked selected
static let unwalkedSlate     // keep for closed stairways
static let closedRed         // unchanged
static let forestGreen       // unchanged
static let accentAmber       // unchanged

// NEW surface colors
static let pillActive = Color(red: 212/255, green: 136/255, blue: 43/255)       // #D4882B
static let pillInactive = Color(red: 51/255, green: 51/255, blue: 51/255)       // #333333
static let topBarBackground = Color.white
static let topBarText = Color(red: 26/255, green: 26/255, blue: 26/255)         // #1A1A1A
```

---

## 6. Integration Points

- **MapKit** — unchanged; dark appearance via `.preferredColorScheme(.dark)` or `MKMapView.overrideUserInterfaceStyle`
- **AroundMeManager** — unchanged; just called from a different button location
- **SearchPanel** — unchanged; just triggered from a different button location
- **StairwayPin / TeardropPin** — color and icon changes only
- **No new frameworks or dependencies**

---

## 7. Constraints

- MapKit dark mode should use the system dark map style, not a custom tile overlay. If MapKit's `.dark` style doesn't match the desired aesthetic closely enough, accept MapKit's default dark appearance rather than introducing Mapbox.
- The stair icon inside pins must remain legible at 24px width (the unsaved pin size). Keep the geometry simple: three rectangles, no curves.
- App icon must be delivered at 1024x1024 and all required iOS sizes via Assets.xcassets.
- No functional changes. Every interaction (save, walk, search, filter, Around Me) should behave identically to the current build. If something breaks during the visual rework, that's a bug, not a scope change.

---

## 8. Acceptance Criteria

- [ ] White top bar renders below Dynamic Island safe area
- [ ] "SF Stairways" text logo visible in top bar, amber colored
- [ ] Search circle button (magnifying glass) in top bar opens full-screen search panel
- [ ] Around Me circle button (location arrow) in top bar triggers neighborhood highlighting
- [ ] Around Me button shows amber fill when active
- [ ] Bottom search bar is removed
- [ ] Bottom "Around Me" capsule button is removed
- [ ] Filter pills render below top bar with dark background (#333) inactive / amber (#D4882B) active styling
- [ ] Filter pill behavior unchanged (radio selection, same filtering)
- [ ] Unsaved pins are warm amber (#D4882B) at 50% opacity with white stair icon
- [ ] Saved pins are light green (#81C784) with white stair icon
- [ ] Walked pins are green (#4CAF50) with white stair icon
- [ ] All three pin states use the same 3-step stair silhouette (no checkmark, no blank)
- [ ] Stair icon reads clearly at 24pt pin width
- [ ] Selected pin darkens and scales up (existing behavior with new colors)
- [ ] Around Me dimming uses 30% opacity of each pin's state color
- [ ] Map renders in dark appearance
- [ ] White top bar provides visual contrast against dark map
- [ ] Bottom sheet / detail card still opens on pin tap (unchanged behavior)
- [ ] Search panel still functions (tabs, live filter, fly-to-result — unchanged)
- [ ] Neighborhood chip still appears when Around Me is active
- [ ] Toast messages still display on location denial
- [ ] All 8 walked stairways and 5 saved stairways display correctly with new colors
- [ ] Updated app icon delivered: solid white 3-step stair, equal sizing, in Assets.xcassets
- [ ] No functional regressions — save, walk, search, filter, Around Me all work as before
- [ ] Feedback loop prompt has been run

---

## 9. Files Likely Touched

### Modify
```
ios/SFStairways/Resources/AppColors.swift            — Replace brandOrange with brandAmber, add pinSaved colors, add surface colors
ios/SFStairways/Views/Map/TeardropPin.swift           — Update StairwayPin to use stair icon for all states, apply new color palette
ios/SFStairways/Views/Map/MapTab.swift                — Replace bottom bar with top bar, move search/Around Me to circle buttons, dark map style, update pill styling
ios/SFStairways/Views/Map/StairwayAnnotation.swift    — Pass updated colors through (if hardcoded)
ios/SFStairways/Assets.xcassets/AppIcon.appiconset/   — Replace app icon assets with v8 design
```

### No changes expected
```
ios/SFStairways/Views/Map/SearchPanel.swift           — Triggered differently but internals unchanged
ios/SFStairways/Views/Map/AroundMeManager.swift       — Called from different button but logic unchanged
ios/SFStairways/Views/Map/StairwayBottomSheet.swift   — Unchanged
ios/SFStairways/Models/                               — No data model changes
ios/SFStairways/Services/                             — No service changes
```
