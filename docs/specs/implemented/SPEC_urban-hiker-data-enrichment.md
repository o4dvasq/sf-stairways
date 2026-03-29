SPEC: Urban Hiker SF Coordinate Import | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

---

## 1. Objective

Import 735 new stairway locations from the Urban Hiker SF map (Alexandra Kenin, 1,081 GPS placemarks). We use only public location data (names and coordinates). Ratings, descriptions, and photo links are UH's original content and are NOT imported. Preserve our existing neighborhood taxonomy.

## 2. Scope

One-time data import script that:
- Adds 735 new stairways to `all_stairways.json` (name + coordinates only)
- Fills in coordinates for our 15 stairways currently missing lat/lng
- Assigns all new entries to our neighborhood taxonomy using coordinate proximity
- Creates ~8 new neighborhoods for areas we don't cover (Presidio, Golden Gate Park, etc.)
- Produces a human-reviewable diff report before committing changes

## 3. Business Rules

### Matching

- Two entries match if they are within 50 meters of each other (haversine distance).
- Secondary matching: name similarity > 0.6 (SequenceMatcher) for entries that didn't match by coordinates.
- Matched entries: only used for coordinate gap-fills. No other data imported for matched stairways.

### What We Import

- Stairway name (from the KML placemark name)
- GPS coordinates (lat/lng from KML)
- Nothing else. No ratings, descriptions, or photo links.

### Neighborhood Assignment

- Use our 53-neighborhood taxonomy as the primary system.
- For each new UH entry, assign to the nearest neighborhood centroid within 800m.
- For entries > 800m from any centroid, assign to a new neighborhood based on these mappings:
  - Presidio (102 entries): lat 37.79-37.81, lng around -122.45 to -122.48
  - Golden Gate Park (50 entries): lat ~37.77, lng -122.46 to -122.51
  - Lands End (19 entries): lat ~37.78-37.79, lng ~-122.50 to -122.51
  - Fort Mason (10 entries): lat ~37.80, lng ~-122.43
  - Embarcadero (10 entries): lat ~37.79, lng ~-122.39
  - Downtown (5 entries): lat ~37.79, lng ~-122.40
  - Alcatraz Island (3 entries): lat ~37.83, lng ~-122.42
  - Marina (1 entry): lat ~37.80, lng ~-122.44
- Remaining "Other" entries (~105): assign via nearest-neighborhood with a relaxed 1500m threshold. Anything still unassigned gets neighborhood "Unclassified" for later curator review on macOS.

### Data Preservation

- Our existing `all_stairways.json` fields are authoritative and never overwritten.
- If a UH entry has coords and our matched entry is missing coords, fill them in with geocode_source "urban_hiker".
- The `id` for new stairways: lowercase the name, spaces to hyphens, alphanumeric + hyphens only, truncated to 60 chars, deduplicated with numeric suffix if needed.

### New Entry Defaults

New stairways from UH get these field values:
- `id`: generated from name (see above)
- `name`: from KML placemark name
- `neighborhood`: assigned per rules above
- `lat`, `lng`: from KML coordinates
- `height_ft`: null
- `closed`: false
- `geocode_source`: "urban_hiker"
- `source_url`: null

## 4. Data Model / Schema Changes

None. The existing Stairway struct and JSON schema are unchanged. New entries use the same fields as existing entries.

## 5. UI / Interface

No UI changes in this spec. The app will display new stairways on the map and in lists automatically since they follow the existing data format.

## 6. Integration Points

### Input files (already in `data/`)

- `data/urban_hiker_parsed.json` — 1,081 placemarks parsed from KMZ (name, lat, lng)
- `data/enrichment_analysis.json` — cross-reference analysis with match details
- `data/all_stairways.json` — our current 382 stairways

### Output files

- `data/all_stairways.json` — expanded with new entries (~1,117 total)
- `data/all_stairways_backup_YYYYMMDD.json` — backup of original before merge
- `data/import_report.md` — human-reviewable diff showing every change made

### Script

- `scripts/import_urban_hiker_locations.py` — one-time import script (idempotent)

## 7. Constraints

- Script must be idempotent: running it twice produces the same result.
- Back up `all_stairways.json` before any writes.
- Produce the import report FIRST, write changes only after confirmation flag (e.g., `--apply`).
- Do not delete or modify any existing stairway entry's fields (name, neighborhood, lat, lng, height_ft, closed).
- Do not import UH ratings, descriptions, or photo links. These are UH's original content.
- The typo "Mission Distrtict" in our existing data should be preserved as-is for now (fixing it is a separate concern).
- New stairway IDs must not collide with existing IDs.
- The `geocode_source` for new entries and coordinate gap-fills should be set to "urban_hiker".
- No changes to Stairway.swift or any iOS/macOS source code.

## 8. Acceptance Criteria

### Data import
- [ ] Backup created before any changes
- [ ] 735 new stairways added with name, coordinates, neighborhood, and defaults
- [ ] 15 coordinate-missing stairways filled where UH has a match
- [ ] All new stairways assigned to a neighborhood (our taxonomy or new neighborhoods)
- [ ] No existing field values overwritten
- [ ] No duplicate IDs in the merged dataset
- [ ] Total stairway count ~1,117
- [ ] No UH ratings, descriptions, or photo links in the output

### Neighborhood integrity
- [ ] All 53 existing neighborhoods preserved exactly as-is
- [ ] New neighborhoods added only for areas > 800m from existing centroids
- [ ] No UH neighborhood names used; our taxonomy is authoritative

### Script quality
- [ ] Script is idempotent (re-running produces identical output)
- [ ] `--dry-run` mode produces import_report.md without modifying data
- [ ] `--apply` mode writes changes after producing report
- [ ] import_report.md shows: match summary, new entries by neighborhood, coordinate fills

### General
- [ ] No source code changes (Stairway.swift unchanged)
- [ ] App builds and loads expanded JSON without errors
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

**New files:**
- `scripts/import_urban_hiker_locations.py` — import script
- `data/all_stairways_backup_YYYYMMDD.json` — pre-merge backup
- `data/import_report.md` — human-reviewable diff

**Modified files:**
- `data/all_stairways.json` — expanded dataset

**Reference files (read-only, already in place):**
- `data/urban_hiker_parsed.json` — 1,081 UH placemarks
- `data/enrichment_analysis.json` — cross-reference analysis
