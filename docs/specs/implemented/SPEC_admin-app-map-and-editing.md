SPEC: Admin App Map & Editing Upgrade | Project: sf-stairways | Date: 2026-04-04 | Status: Ready for implementation

---

# 1. Objective

Upgrade the iOS Admin app (`SFStairwaysAdmin`) from a flat list browser into a proper maintenance tool with map-based spatial context, inline stairway editing, and a new app icon that visually distinguishes it from the main app. The Admin app is curator-only -- it's not distributed to users and doesn't need Supabase, HealthKit, or user-facing polish. It needs to be functional and efficient for catalog maintenance in the field.

# 2. Scope

**In scope:**
- Add a map tab to the Admin app showing all stairways with color-coded pins (walked, unwalked, has override, has issues)
- Map tap → stairway editing (overrides, tags, deletion) via the existing `AdminDetailView`
- Tab-based navigation (Map + List) replacing the current single-view `AdminBrowser`
- New app icon: main app icon with wrench badge overlay (all three variants: light, dark, tinted) -- **already generated and placed in Assets**
- Update `Contents.json` to reference new icon files -- **already done**

**Out of scope:**
- Neighborhood polygon overlays (not needed for maintenance workflows)
- Photo management (stays out of Admin app per existing architecture)
- Supabase integration
- User-facing UI polish (no celebration animations, share cards, etc.)

# 3. Business Rules

1. **Admin app is curator-only.** It is sideloaded or TestFlight-distributed to Oscar only. It shares the same CloudKit container and SwiftData schema as the main app.
2. **Map is a maintenance tool.** Its purpose is spatial awareness for field work: "which stairways near me need overrides? which ones have issues?" Color-coded pins answer these questions at a glance.
3. **All editing flows go through `AdminDetailView`.** The map is a navigation entry point to the same editing UI that the list provides today. No duplicate editing surfaces.
4. **Pin colors encode maintenance state**, not just walked/unwalked. The Admin map uses a 4-state color scheme: default (catalog data only), walked (has WalkRecord), has override (curator has edited), has issues (flagged by data hygiene checks -- missing height, missing coordinates, etc.).

# 4. Data Model / Schema Changes

None. The Admin app already has access to all required SwiftData models (WalkRecord, StairwayOverride, StairwayTag, TagAssignment, StairwayDeletion) via CloudKit sync. The map is purely a new view layer.

# 5. UI / Interface

## New: Tab-based navigation

Replace the current `AdminBrowser` as root view with a `TabView`:

| Tab | Icon | View |
|-----|------|------|
| Map | `map` | `AdminMapTab` (new) |
| List | `list.bullet` | `AdminBrowser` (existing, unchanged) |

Both tabs share the same `@Query` data and `StairwayStore`. Tag Manager and Removed Stairways remain accessible from the List tab's toolbar (unchanged).

## New: `AdminMapTab`

### Map setup
- Full-screen `Map` using MapKit, same default center as main app (37.76, -122.44), default span 0.06
- Standard map style (`.standard`), no elevation
- `MapUserLocationButton()` for centering on current location
- No neighborhood polygons, no centroid labels, no progress card

### Pin rendering
- Use simple colored circle pins (no need for the full `StairwayAnnotation`/`StairwayPin` stack from the main app)
- 4-state color scheme:

| State | Color | Priority |
|-------|-------|----------|
| Has issues | `Color.red` (0.8 opacity) | Highest |
| Has override | `Color.blue` (0.8 opacity) | |
| Walked | `Color.walkedGreen` | |
| Default (unwalked, no override, no issues) | `Color.brandAmber` | Lowest |

- "Has issues" detection reuses the same logic from `DataHygieneView` on macOS: missing height (`heightFt == nil` and no override), missing coordinates (`lat == 0 || lng == 0`).
- Pin size: 14pt base, 20pt selected. No zoom scaling needed for Admin (simpler than main app).
- Tap target: `max(44, pinSize)` via outer frame + `.contentShape`.

### Pin labels
- Show stairway `displayName` when map span < 0.02 (same threshold as main app).
- Font: `.caption2`, design: `.rounded`, 60% opacity.

### Pin tap → detail sheet
- Tapping a pin sets `@State selectedStairway: Stairway?`
- Opens `AdminDetailView` as a `.sheet` presentation, passing the selected stairway
- `AdminDetailView` is already fully functional (catalog info, override editing, tag management, deletion)
- Dismissing the sheet deselects the pin

### Toolbar
- **Filter menu** (top trailing): segmented or menu control for pin filter state:
  - All (default)
  - Has Issues (shows only issue pins)
  - Has Overrides
  - Unwalked
  - Walked
- **Tag Manager** button (same as List tab, for convenience)

## Existing: `AdminBrowser` (List tab)

No changes. Continues to work exactly as it does today with search, filtering, sorting, and navigation to `AdminDetailView`.

## App Icon

Three icon variants already generated and placed at:
- `ios/SFStairwaysAdmin/Assets.xcassets/AppIcon.appiconset/AdminIcon.png` (light)
- `ios/SFStairwaysAdmin/Assets.xcassets/AppIcon.appiconset/AdminIcon_dark.png` (dark)
- `ios/SFStairwaysAdmin/Assets.xcassets/AppIcon.appiconset/AdminIcon_tinted.png` (tinted)

`Contents.json` already updated to reference these files with the correct appearance/luminosity entries.

Design: same amber gradient + white stair silhouette as the main app, with a dark circular badge in the upper-right containing a white wrench icon. Instantly recognizable as the "maintenance" variant of SF Stairs.

# 6. Integration Points

- **CloudKit:** Unchanged. Admin app reads/writes to the same `iCloud.com.o4dvasq.sfstairways` container.
- **SwiftData models:** Shared via target membership (already configured). No new models.
- **StairwayStore:** Already available in Admin target. Map tab creates its own instance or shares via environment (same pattern as `AdminBrowser`).
- **Main app:** No impact. Admin app is a separate target with separate bundle ID.

# 7. Constraints

- Admin app does not import `NeighborhoodStore` or load `sf_neighborhoods.geojson`. The map shows stairway pins only -- no neighborhood polygons or centroids.
- `AdminMapTab` should not import or reference any main app view files (`MapTab.swift`, `StairwayAnnotation.swift`, `TeardropPin.swift`). Keep the Admin map simple and self-contained.
- Admin app does not need dark mode polish, animation refinement, or brand consistency beyond the icon. Functional > beautiful.
- The existing `LocationManager.swift` is not in the Admin target. If "locate me" functionality is needed, add `CLLocationManager` usage inline or add `LocationManager` to the Admin target membership. Minimal approach preferred.

# 8. Acceptance Criteria

- [ ] Admin app opens to a `TabView` with Map and List tabs
- [ ] Map tab shows all stairways as colored circle pins
- [ ] Pin colors correctly reflect 4-state priority (issues > override > walked > default)
- [ ] Tapping a pin opens `AdminDetailView` as a sheet
- [ ] Editing an override in the detail sheet and dismissing shows updated pin color on the map
- [ ] Filter menu works: filtering to "Has Issues" shows only issue-state pins
- [ ] List tab works identically to current `AdminBrowser`
- [ ] Tag Manager accessible from both Map and List tabs
- [ ] App icon shows stair + wrench badge on home screen (light, dark, tinted variants)
- [ ] `Contents.json` references the correct admin icon filenames
- [ ] Admin app builds and runs on device with no new warnings
- [ ] Feedback loop prompt has been run

# 9. Files Likely Touched

**Admin app (new):**
- `SFStairwaysAdmin/Views/AdminMapTab.swift` — new map view with pins, filtering, detail sheet presentation
- `SFStairwaysAdmin/Views/AdminContentView.swift` — new root `TabView` wrapping Map + List tabs (or inline in `SFStairwaysAdminApp.swift`)

**Admin app (modify):**
- `SFStairwaysAdmin/SFStairwaysAdminApp.swift` — switch root view from `AdminBrowser` to new `TabView` / `AdminContentView`

**Admin app (already done):**
- `SFStairwaysAdmin/Assets.xcassets/AppIcon.appiconset/Contents.json` — updated with icon filenames
- `SFStairwaysAdmin/Assets.xcassets/AppIcon.appiconset/AdminIcon.png` — generated
- `SFStairwaysAdmin/Assets.xcassets/AppIcon.appiconset/AdminIcon_dark.png` — generated
- `SFStairwaysAdmin/Assets.xcassets/AppIcon.appiconset/AdminIcon_tinted.png` — generated

**Xcode project (manual):**
- `SFStairways.xcodeproj/project.pbxproj` — add new `.swift` files to Admin target membership; optionally add `LocationManager.swift` to Admin target if user-location button is desired

**No changes:**
- `AdminBrowser.swift` — unchanged, now embedded in List tab
- `AdminDetailView.swift` — unchanged, presented from both Map and List
- `AdminTagManager.swift`, `RemovedStairwaysView.swift` — unchanged
- All main app files — no impact
