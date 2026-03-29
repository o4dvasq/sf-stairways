SPEC: Neighborhood Foundation + Data Migration | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

Depends on: Nothing (this is the foundation)

---

## 1. Objective

Make neighborhoods a first-class architectural concept in the app by creating a `Neighborhood` model, a `NeighborhoodStore` that serves as the single source of truth for all neighborhood data, and migrating the stairway catalog from 53 scraped neighborhood names to the official DataSF Analysis Neighborhoods boundaries.

This is a data + architecture spec. No visible UI changes except that existing views will show the new neighborhood names (roughly 41 instead of 53).

## 2. Scope

**In scope:**
- Download and bundle the DataSF Analysis Neighborhoods GeoJSON
- Create `Neighborhood` struct (not SwiftData, in-memory from bundled data)
- Create `NeighborhoodStore` that loads GeoJSON and computes centroids, adjacency, and color assignments
- Migrate `all_stairways.json`: reassign every stairway's `neighborhood` field using point-in-polygon spatial join against the GeoJSON
- Eliminate `neighborhood_centroids.json` (computed from GeoJSON polygons instead)
- Eliminate `neighborhood_adjacency.json` (computed from shared polygon borders instead)
- Refactor `AroundMeManager` to use `NeighborhoodStore` instead of loading its own JSON files
- Fix the existing typo "Mission Distrtict" → correct DataSF name

**Out of scope:**
- Map polygon overlays (Phase 2)
- Neighborhood detail view (Phase 2)
- Progress tab redesign (Phase 3)
- Any UI changes beyond the name swap

## 3. Business Rules

- Every stairway must belong to exactly one neighborhood after migration
- Neighborhood assignment is determined by geographic containment: each stairway's (lat, lng) falls within exactly one DataSF polygon
- Some DataSF neighborhoods may have zero stairways (e.g., Golden Gate Park, Presidio, Treasure Island). This is fine. They exist in the model but won't appear in stairway-derived views.
- Stairway IDs do not change. WalkRecords, WalkPhotos, StairwayOverrides, and all other SwiftData entities are unaffected.
- The `neighborhood` field on `Stairway` continues to be a plain string. It now matches a `Neighborhood.name` from the store.

## 4. Data Model / Schema Changes

### New: `Neighborhood` struct (in-memory, not SwiftData)

```
struct Neighborhood: Identifiable, Codable {
    let name: String               // DataSF "nhood" value, e.g. "Noe Valley"
    let polygon: [CLLocationCoordinate2D]  // Boundary coordinates from GeoJSON
    let multiPolygon: [[CLLocationCoordinate2D]]?  // Some neighborhoods have multiple polygons
    var centroid: CLLocationCoordinate2D   // Computed: average of polygon vertices (or geometric centroid)
    var color: Color                // Assigned pastel color for map overlays (Phase 2 uses this)

    var id: String { name }
}
```

### New: `NeighborhoodStore`

```
@Observable class NeighborhoodStore {
    let neighborhoods: [Neighborhood]           // All neighborhoods from GeoJSON
    let adjacency: [String: Set<String>]        // Computed from shared borders

    func neighborhood(for coordinate: CLLocationCoordinate2D) -> Neighborhood?  // Point-in-polygon lookup
    func neighborhood(named: String) -> Neighborhood?                           // Name lookup
    func neighbors(of name: String) -> Set<String>                              // Adjacency lookup
    func centroid(for name: String) -> CLLocationCoordinate2D?                  // Centroid lookup
}
```

### Deleted files (after migration):
- `ios/SFStairways/Resources/neighborhood_centroids.json`
- `ios/SFStairways/Resources/neighborhood_adjacency.json`

### Modified files:
- `data/all_stairways.json` — neighborhood field values updated
- `data/target_list.json` — neighborhood field values updated (if present)

### New bundled resource:
- `ios/SFStairways/Resources/sf_neighborhoods.geojson` — DataSF Analysis Neighborhoods GeoJSON

## 5. UI / Interface

No UI changes in this phase. Existing views that display `stairway.neighborhood` will automatically show the new names. The number of neighborhood groups in ListTab, SearchPanel, and ProgressTab will change from 53 to roughly 35-41 (however many have stairways).

## 6. Integration Points

### AroundMeManager refactor
- Currently loads `neighborhood_centroids.json` and `neighborhood_adjacency.json` in its own `init()`
- Refactor to accept `NeighborhoodStore` as a dependency
- Use `NeighborhoodStore.centroid(for:)` and `NeighborhoodStore.neighbors(of:)` instead of its own data
- The 5000m proximity threshold and dimming logic remain unchanged

### StairwayStore
- Currently has `stairways: [Stairway]` loaded from bundled JSON
- No structural change needed. The `neighborhood` string on each `Stairway` will have new values after the JSON migration.
- The `region(for neighborhood:)` function (used for fly-to-neighborhood) continues to work since it computes bounding box from stairway coordinates.

### NeighborhoodStore initialization
- Load and parse `sf_neighborhoods.geojson` at app startup
- Compute centroids from polygon geometry
- Compute adjacency from shared polygon borders (two neighborhoods are adjacent if their polygons share at least one border segment or are within a small distance threshold)
- Assign colors from a fixed palette (see Phase 2 spec for palette, but the assignment logic lives here)
- Inject into the SwiftUI environment so all views can access it

### SearchPanel
- `store.searchByNeighborhood(query)` groups stairways by `stairway.neighborhood`. This works unchanged with the new names.

### Migration script (one-time, run at build time or as a preprocessing step)
- For each stairway in `all_stairways.json`, use its `(latitude, longitude)` to determine which DataSF polygon contains it
- Update the `neighborhood` field to the DataSF `nhood` value
- Verify: all 382 stairways have a neighborhood assignment (no orphans)
- Verify: no stairway falls outside all polygons (if any do, assign to nearest polygon by centroid distance)
- Write updated `all_stairways.json`
- This can be a Python script in `scripts/` or done manually. The result is committed to the repo. This is NOT a runtime migration.

## 7. Constraints

- The DataSF GeoJSON must be downloaded from https://data.sfgov.org/Geographic-Locations-and-Boundaries/Analysis-Neighborhoods/p5b7-5n3h (export as GeoJSON). This is a free, public dataset.
- The actual number of Analysis Neighborhoods is approximately 41 (not 37 as previously estimated). Use whatever the GeoJSON contains.
- Point-in-polygon testing requires a geometric algorithm (ray casting or winding number). This is standard and can be implemented in Swift or Python for the migration script.
- GeoJSON coordinates are [longitude, latitude] (note the order). Convert appropriately.
- Some DataSF polygons may be MultiPolygons (multiple disjoint areas for one neighborhood). Handle this.

## 8. Acceptance Criteria

- [ ] `sf_neighborhoods.geojson` is bundled in the app resources
- [ ] `Neighborhood` struct and `NeighborhoodStore` exist and load correctly from GeoJSON
- [ ] `NeighborhoodStore` computes centroids from polygon geometry (no separate centroids JSON)
- [ ] `NeighborhoodStore` computes adjacency from polygon borders (no separate adjacency JSON)
- [ ] `neighborhood_centroids.json` and `neighborhood_adjacency.json` are deleted from the project
- [ ] `all_stairways.json` has been migrated: every stairway's `neighborhood` matches a DataSF `nhood` name
- [ ] All 382 stairways are accounted for (none lost, none orphaned)
- [ ] `AroundMeManager` uses `NeighborhoodStore` for centroids and adjacency
- [ ] Around Me feature works correctly with the new neighborhood data
- [ ] ListTab, SearchPanel, ProgressTab all display the new neighborhood names correctly
- [ ] App builds and runs without errors
- [ ] The "Mission Distrtict" typo no longer exists anywhere in the codebase
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `scripts/migrate_neighborhoods.py` — new: one-time migration script
- `data/all_stairways.json` — updated neighborhood values
- `data/target_list.json` — updated neighborhood values
- `ios/SFStairways/Resources/sf_neighborhoods.geojson` — new bundled resource
- `ios/SFStairways/Resources/neighborhood_centroids.json` — deleted
- `ios/SFStairways/Resources/neighborhood_adjacency.json` — deleted
- `ios/SFStairways/Models/Neighborhood.swift` — new: Neighborhood struct
- `ios/SFStairways/Models/NeighborhoodStore.swift` — new: NeighborhoodStore
- `ios/SFStairways/Views/Map/AroundMeManager.swift` — refactored to use NeighborhoodStore
- `ios/SFStairways/SFStairwaysApp.swift` — initialize and inject NeighborhoodStore into environment
