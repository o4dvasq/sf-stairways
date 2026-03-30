SPEC: Neighborhood Map Overlays + Detail View | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

Depends on: SPEC_neighborhood-foundation.md (Neighborhood model, NeighborhoodStore — already implemented)
Depends on: SPEC_neighborhood-311-migration.md (311 GeoJSON replaces DataSF Analysis; 117 polygons, ~66 with stairways)
Depends on: SPEC_visual-refresh-phase-1.md (warm palette, typography — already implemented)

---

## 1. Objective

Bring neighborhoods to life visually on the map and give each neighborhood its own dedicated screen. Two deliverables:

1. Color-coded polygon overlays and labels on the map, making neighborhood boundaries visible and tappable
2. A `NeighborhoodDetail` view that serves as the hub for everything about a neighborhood: its stairways, progress, map, and photos

## 2. Scope

**In scope:**
- Render polygon overlays on the MapKit map with warm-toned pastel fills
- Render neighborhood name labels at polygon centroids
- Tap-to-navigate from polygon or label to NeighborhoodDetail
- New `NeighborhoodDetail` view with map, progress, photos, and stairway list
- Navigation entry points from everywhere a neighborhood name appears
- Color palette definition and assignment

**Out of scope:**
- Progress tab redesign (Phase 3)
- Custom map tiles or non-MapKit rendering
- Neighborhood-based walk planning or route suggestions
- Hand-drawn map aesthetic

## 3. Business Rules

- Every neighborhood in the GeoJSON gets a polygon overlay on the map, including those with zero stairways
- Neighborhoods with zero stairways still show their polygon but their detail view simply shows "No stairways in this neighborhood"
- Colors are fixed (not random) so the same neighborhood always has the same color across sessions
- Polygon taps and pin taps are independent: tapping a pin still opens the stairway bottom sheet, tapping the polygon area (not on a pin) navigates to NeighborhoodDetail

## 4. Data Model / Schema Changes

None. This phase uses `NeighborhoodStore` and `Neighborhood` from Phase 1. The `color` property on `Neighborhood` is assigned during store initialization.

### Color palette definition

Define approximately 12-14 warm-toned pastel colors that harmonize with the Phase 1 palette (more colors needed for 66 active neighborhoods vs the original 34) (`surfaceBackground`, `brandOrange`, `forestGreen`, `walkedGreen`). Suggested hues:

| Name | Light mode hex (approx) | Purpose |
|------|------------------------|---------|
| Peach | #FFE5D0 | Warm, inviting |
| Sand | #F5E6C8 | Neutral warm |
| Clay | #E8D5C4 | Earthy |
| Sage | #D4E2D4 | Natural green |
| Warm Rose | #F2D5D5 | Soft pink |
| Wheat | #F0E4C4 | Golden warm |
| Terracotta | #E8CFC0 | Rich warm |
| Muted Gold | #EDE0B8 | Sunny |
| Dusty Lavender | #DDD5E5 | Cool accent |
| Seafoam | #D0E5E0 | Cool accent |

Colors are cycled across neighborhoods in a deterministic order. Adjacent neighborhoods (per `NeighborhoodStore.adjacency`) should not share the same color. A simple graph coloring pass during store initialization handles this (greedy algorithm with the adjacency graph; 10 colors is more than enough for a planar map).

Dark mode: same hues at reduced opacity (~10-12% alpha vs ~15-20% in light mode). Define both variants.

## 5. UI / Interface

### Map overlays

**Polygon rendering:**
- Use SwiftUI Map's `MapPolygon` (iOS 17+) as the first approach
- Each polygon: fill at 15-20% alpha (light mode) or 10-12% (dark mode), stroke at 30% alpha, 1pt weight, slightly darker than fill
- Polygons render below stairway pin annotations (lower z-index / annotation priority)
- All polygons are always visible regardless of zoom level

**Neighborhood labels:**
- Render at each neighborhood's centroid as a `MapAnnotation` or `Annotation`
- Typography: SF Pro Rounded, caption2 or footnote size
- Color: `textSecondary` at ~60% opacity
- Lower annotation priority than stairway pins (MapKit handles collision avoidance)
- Visible at mid-to-close zoom levels; hidden at full-city zoom. Use a zoom threshold: labels appear when the map span is less than ~0.04 degrees latitude (roughly 6-8 neighborhoods visible)

**Tap interaction:**
- Tapping the polygon area (not on a pin) should navigate to `NeighborhoodDetail`
- Implementation approach: use `MapReader` to get tap coordinates, then `NeighborhoodStore.neighborhood(for: coordinate)` (point-in-polygon) to determine which neighborhood was tapped
- If the tap is on a stairway pin, the existing bottom sheet takes priority (pin annotations have higher priority)
- If SwiftUI Map's tap handling proves unreliable for distinguishing polygon taps from pin taps, fall back to making neighborhood labels the tap target instead (labels as `Annotation` views with `onTapGesture`)

### NeighborhoodDetail view

**Navigation entry points (all push to NeighborhoodDetail via NavigationStack):**
- Tap polygon or neighborhood label on the map
- Tap neighborhood section header in ListTab
- Tap neighborhood row in SearchPanel (Neighborhood tab)
- Tap neighborhood name on StairwayBottomSheet (currently shows as secondary label)
- Tap neighborhood card in ProgressTab (Phase 3 adds this, but the view itself is built now)

**Layout:**

```
┌──────────────────────────────────┐
│  ← Back                         │
│                                  │
│  Noe Valley              4 / 12 │  ← Name (Rounded, title) + walked/total
│  ━━━━━━━━━━━░░░░░░░░░░░░░░░░░  │  ← Progress bar (brandOrange)
│                                  │
│  ┌────────────────────────────┐  │
│  │                            │  │
│  │    Zoomed map showing      │  │  ← This neighborhood's polygon (pastel fill)
│  │    this neighborhood's     │  │     + stairway pins, zoomed to fit
│  │    polygon + stairway pins │  │     ~200pt height
│  │                            │  │
│  └────────────────────────────┘  │
│                                  │
│  ┌─ Photos ───────────────────┐  │  ← Horizontal scroll, hidden if no photos
│  │ [img] [img] [img] [img]    │  │     From WalkRecords in this neighborhood
│  └────────────────────────────┘  │     Sorted newest first, tappable
│                                  │
│  Stairways                       │
│                                  │
│  ✓ Saturn Street Steps    65 ft  │  ← Walked first (by date, newest first)
│  ✓ Vulcan Stairway        45 ft  │
│  ○ 19th St Stairs         30 ft  │  ← Then unwalked (alphabetical)
│  ○ Mono Street Steps      40 ft  │
│                                  │
└──────────────────────────────────┘
```

**Embedded map behavior:**
- Shows only this neighborhood's polygon (highlighted with its assigned pastel color) plus its stairway pins
- Map region zoomed to fit the polygon bounds with ~20% padding
- Pin colors follow existing walked/unwalked state styling
- Tapping a pin on the embedded map navigates to that stairway's detail (push onto the NavigationStack, not a bottom sheet, since we're already in a detail context)

**Photo row:**
- Queries all `WalkPhoto` records where the associated `WalkRecord.stairwayID` belongs to a stairway in this neighborhood
- Horizontal scroll, thumbnail size (~80pt square), rounded corners
- Sorted by date, newest first
- Tapping a photo opens the existing photo viewer
- Hidden entirely if no photos exist for this neighborhood

**Stairway list:**
- Walked stairways first, sorted by `dateWalked` descending (most recent first)
- Then unwalked stairways, sorted alphabetically
- Each row shows: walked indicator (checkmark or circle), stairway name, height (if known)
- Tapping a row navigates to stairway detail (push onto NavigationStack)
- If zero stairways have been walked: no grouping, just alphabetical list of all stairways

## 6. Integration Points

### MapTab.swift
- Add polygon overlays from `NeighborhoodStore.neighborhoods`
- Add label annotations at centroids
- Add `MapReader` tap handler for polygon-to-NeighborhoodDetail navigation
- Existing pin rendering and bottom sheet behavior unchanged
- Around Me dimming should also dim polygon opacity (not just pins)

### ListTab.swift
- Section headers (neighborhood names) become tappable
- Tap navigates to `NeighborhoodDetail` for that neighborhood
- Add a disclosure indicator or chevron to signal tappability

### SearchPanel.swift
- Neighborhood tab rows become tappable → `NeighborhoodDetail`
- Currently triggers `onSelectNeighborhood` which flies to the map location
- Change behavior: tap navigates to `NeighborhoodDetail`, which has its own embedded map

### StairwayBottomSheet.swift
- The neighborhood name label (line ~258) becomes tappable → `NeighborhoodDetail`
- Style as a tappable link (e.g., secondary color with chevron, or underline)

### Navigation architecture
- `NeighborhoodDetail` should be a NavigationStack destination, routable by neighborhood name
- Use `NavigationLink(value:)` pattern or a coordinator/router if the app has one
- The view receives a neighborhood name string and resolves everything from `NeighborhoodStore` and `StairwayStore`

## 7. Constraints

- SwiftUI Map polygon rendering and tap detection are the primary technical risk. If `MapPolygon` doesn't support distinguishing polygon taps from pin taps cleanly, the fallback is: polygon overlays are visual-only, and the tap target for navigating to NeighborhoodDetail is the centroid label annotation.
- Photo aggregation traverses WalkPhoto → WalkRecord → stairwayID → Stairway.neighborhood. This is an in-memory join, not a database query. For 382 stairways and a few hundred walk records, performance should be fine.
- The embedded map in NeighborhoodDetail is a separate Map view, not the main MapTab. Keep it simple: static display with pins, no search panel or Around Me.
- MultiPolygon neighborhoods need all their sub-polygons rendered as separate overlays.

## 8. Acceptance Criteria

- [ ] All neighborhoods from the GeoJSON have polygon overlays on the map with warm-toned pastel fills
- [ ] Polygon colors are consistent (same neighborhood = same color every time)
- [ ] Adjacent neighborhoods do not share the same color
- [ ] Neighborhood labels appear at centroids at mid-to-close zoom levels
- [ ] Tapping a polygon area (or label) on the map navigates to NeighborhoodDetail
- [ ] Tapping a pin still opens the stairway bottom sheet (not overridden by polygon tap)
- [ ] NeighborhoodDetail shows: name, progress fraction, progress bar, embedded map, photo row (if photos), stairway list
- [ ] NeighborhoodDetail is reachable from: map polygon/label tap, ListTab section header, SearchPanel neighborhood tab, StairwayBottomSheet neighborhood label
- [ ] Walked stairways appear first in NeighborhoodDetail's stairway list
- [ ] Photo row aggregates photos from all walked stairways in the neighborhood
- [ ] Dark mode polygon fills have reduced opacity
- [ ] Around Me dimming applies to polygon overlays (not just pins)
- [ ] App builds and runs without errors
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/MapTab.swift` — polygon overlays, label annotations, tap handling
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — tappable neighborhood name
- `ios/SFStairways/Views/Map/SearchPanel.swift` — neighborhood tap → NeighborhoodDetail
- `ios/SFStairways/Views/Map/AroundMeManager.swift` — dimming polygons
- `ios/SFStairways/Views/List/ListTab.swift` — tappable section headers
- `ios/SFStairways/Views/Neighborhood/NeighborhoodDetail.swift` — new file
- `ios/SFStairways/Resources/AppColors.swift` — pastel palette definitions (if not in NeighborhoodStore)
- `ios/SFStairways/Models/NeighborhoodStore.swift` — color assignment, graph coloring
