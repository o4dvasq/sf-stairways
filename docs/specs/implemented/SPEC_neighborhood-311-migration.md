SPEC: Neighborhood 311 Migration — Replace DataSF with SF 311 Boundaries | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

Depends on: SPEC_neighborhood-foundation.md (already implemented; this spec replaces its data source)

---

## 1. Objective

Replace the DataSF Analysis Neighborhoods GeoJSON (41 neighborhoods) with the SF 311 Neighborhoods dataset (117 neighborhoods). The Analysis Neighborhoods dataset merges locally-recognized neighborhoods into large census-tract groupings (e.g., Forest Hill absorbed into "West of Twin Peaks"), which breaks the app's identity as a neighborhood-aware local companion. The 311 dataset preserves the granular neighborhoods SF residents actually identify with.

This is a data-swap spec. The architecture (NeighborhoodStore, Neighborhood model, computed centroids/adjacency) remains unchanged. Only the GeoJSON file and the stairway-to-neighborhood mapping change.

## 2. Scope

**In scope:**
- Replace `sf_neighborhoods.geojson` with the SF 311 Neighborhoods GeoJSON
- Re-run spatial join migration: reassign every stairway's `neighborhood` field using point-in-polygon against the 311 polygons
- Manually assign the 15 stairways that have no coordinates
- Update `target_list.json` neighborhood values
- Verify NeighborhoodStore loads correctly with the new GeoJSON (property key is `name`, not `nhood`)

**Out of scope:**
- Changes to NeighborhoodStore architecture (it's fine as-is)
- Changes to Neighborhood model
- Any UI changes
- Map overlays or NeighborhoodDetail (those specs depend on this data being correct first)

## 3. Data Source

**SF 311 Neighborhoods** from DataSF:
- Dataset: https://data.sfgov.org/Geographic-Locations-and-Boundaries/SF-Find-Neighborhoods/pty2-tcw4
- Also available from: https://github.com/sfchronicle/sf-shapefiles (file: `SF neighborhoods/sf-neighborhoods-311.json`)
- 117 neighborhoods with polygon boundaries
- GeoJSON property for neighborhood name: `name` (NOT `nhood` like the Analysis dataset)
- Defined in 2006 by the Mayor's Office of Neighborhood Services

## 4. Migration Results (Pre-validated)

A spatial join was run against the 311 dataset during spec development. Results:

- **367 of 382 stairways** matched via point-in-polygon
- **15 stairways** have no coordinates (lat/lng are null) and need manual assignment
- **66 unique neighborhoods** have at least one stairway
- **51 neighborhoods** in the 311 dataset have zero stairways (parks, industrial areas, etc.)

### Manual assignments for 15 coordinate-less stairways

These stairways have null lat/lng. Assign based on their current (DataSF Analysis) neighborhood, mapped to the most appropriate 311 neighborhood:

| Stairway | Current neighborhood | Assign to (311) |
|----------|---------------------|-----------------|
| Hudson Avenue to Hawkins Lane | Bayview Hunters Point | Bayview |
| Pemberton Place at Crown Terrace | Twin Peaks | Upper Market |
| Miguel Street to Beacon Street | Glen Park | Glen Park |
| Clover Lane - 19th Street to Kite Hill | Castro/Upper Market | Eureka Valley |
| Acme Alley - Corwin Street to Grand View Avenue | Castro/Upper Market | Eureka Valley |
| Moraga Street east of 14th Avenue | Inner Sunset | Inner Sunset |
| Ingleside Path | Oceanview/Merced/Ingleside | Ingleside Terraces |
| Kirkham Street to 5th Avenue | Inner Sunset | Inner Sunset |
| Lyon Street between Broadway and Pacific Avenue | Pacific Heights | Pacific Heights |
| Summit Way to Gonzalez Drive | Lakeshore | Stonestown |
| Summit Way to Font Boulevard | Lakeshore | Stonestown |
| 28th Avenue south of Vicente Street | Sunset/Parkside | Parkside |
| Mariposa Street west of Utah Street (North side) | Potrero Hill | Potrero Hill |
| Reno Place | North Beach | North Beach |
| Dixie Alley - Corbett Avenue to Burnett Avenue | Twin Peaks | Upper Market |

Note: The above assignments are best guesses based on stairway names and streets. Claude Code should verify these by looking up the street intersections. If a stairway's street clearly falls in a different 311 neighborhood, use that instead.

## 5. NeighborhoodStore Update

The only code change needed in NeighborhoodStore is the GeoJSON property key for neighborhood names:
- Current: reads `properties.nhood` (DataSF Analysis format)
- New: must read `properties.name` (SF 311 format)

Everything else (centroid computation, adjacency, color assignment, point-in-polygon) works identically with the new GeoJSON.

The color palette (currently 8 colors) should be reviewed. With 66 active neighborhoods (vs 34 before), more colors or a smarter graph-coloring pass may be needed to ensure adjacent neighborhoods don't share colors.

## 6. Acceptance Criteria

- [ ] `sf_neighborhoods.geojson` in Resources contains the SF 311 dataset (117 features, property key `name`)
- [ ] `all_stairways.json` has been re-migrated: every stairway's `neighborhood` matches a 311 neighborhood name
- [ ] All 382 stairways are accounted for (none lost, none orphaned)
- [ ] Forest Hill exists as a neighborhood with stairways assigned to it
- [ ] Corona Heights, Diamond Heights, Eureka Valley, Clarendon Heights, Dolores Heights all exist as separate neighborhoods
- [ ] The 15 coordinate-less stairways are assigned to appropriate 311 neighborhoods
- [ ] NeighborhoodStore loads correctly (reads `name` property from GeoJSON)
- [ ] AroundMeManager works correctly (detects neighborhoods by proximity)
- [ ] App builds and runs without errors
- [ ] `target_list.json` updated with new neighborhood names
- [ ] Feedback loop prompt has been run

## 7. Files Likely Touched

- `ios/SFStairways/Resources/sf_neighborhoods.geojson` — replaced with 311 dataset
- `data/all_stairways.json` — re-migrated neighborhood values
- `data/target_list.json` — updated neighborhood values
- `ios/SFStairways/Models/NeighborhoodStore.swift` — change property key from `nhood` to `name`, possibly expand color palette
- `scripts/migrate_neighborhoods.py` — updated to use 311 GeoJSON and manual assignments
