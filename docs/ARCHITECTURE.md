# Architecture — sf-stairways

## Single-File App Structure

The entire application lives in `index.html`. Sections in order:

1. `<head>` — meta, Leaflet CSS link, inline `<style>`
2. `<body>` — header, toggle buttons, map container `<div id="map">`
3. `<script>` — config block, then all JS inline

No modules, no bundler. All JS runs in a single script block after the DOM.

## CONFIG Block

At the top of the `<script>` section:

```javascript
const CONFIG = {
  githubOwner: 'o4dvasq',
  githubRepo:  'sf-stairways',
  dataPath:    'data/target_list.json',
  branch:      'main'
};
```

Cloudinary values (cloud name, upload preset) are stored in `localStorage` and entered by the user via the Settings modal.

## Leaflet Marker Layers and Z-Ordering

Three custom Leaflet panes control rendering order (highest z-index renders on top):

| Pane | Contents | Fill | Z-index |
|---|---|---|---|
| `walkedPane` | Walked target stairways | Green `#22c55e` | Top |
| `targetPane` | Unwatched target stairways | Red `#ef4444` | Middle |
| `cityPane` | All 382 SF stairways | Gray `#94a3b8` | Bottom |

All markers use `L.circleMarker`. Walked/target markers have radius 10; city markers have radius 6.

## GitHub API Read/Write Flow

**Read (on load):**
```
fetch('data/target_list.json') → parse JSON → render markers
```
Data is fetched from the repo directly (via GitHub Pages static file), not the API.

**Write (on save):**
1. GET `https://api.github.com/repos/{owner}/{repo}/contents/{path}` — retrieves current file SHA
2. PUT same endpoint with `{ message, content: btoa(JSON.stringify(data)), sha, branch }` — commits update

Token is read from `localStorage['gh_token']`. If missing, the Settings modal is shown automatically.

**Error handling:**
- 401 → clear token, re-show Settings modal
- 409 SHA conflict → prompt user to reload
- Network error → show Retry button, set `pendingChanges` flag in memory

## Cloudinary Upload Flow

1. User taps "Add Photo" on a walked stairway popup
2. File input opens; user selects image
3. Browser POSTs to `https://api.cloudinary.com/v1_1/{cloudName}/image/upload` with `upload_preset` (unsigned)
4. Response contains `secure_url` — this is saved to `target_list.json` under the stairway's `photos` array
5. GitHub API write flow commits the updated `target_list.json`

No API secret required — unsigned presets are safe for browser-side uploads.

## Data File Schemas

### `data/target_list.json` — array of objects

```json
{
  "id": "16th-avenue-tiled-steps",
  "name": "16th Avenue Tiled Steps",
  "neighborhood": "Golden Gate Heights",
  "lat": 37.7562,
  "lng": -122.4732,
  "step_count": 163,
  "walked": true,
  "date_walked": "2026-03-08",
  "notes": "Mosaic sea-to-stars theme.",
  "photos": []
}
```

### `data/all_stairways.json` — array of objects

```json
{
  "id": "vulcan-stairway",
  "name": "Vulcan Stairway",
  "neighborhood": "Corona Heights",
  "lat": 37.7635,
  "lng": -122.4420,
  "height_ft": 115,
  "closed": false,
  "geocode_source": "page",
  "source_url": "https://www.sfstairways.com/stairways/vulcan-stairway"
}
```

Records with `lat: null` or `lng: null` are silently skipped — no marker is rendered.

## iOS App Structure

Source at `ios/SFStairways/`. **iOS is the sole active platform** — web app deprecated 2026-03-25.

### Entry Point

`SFStairwaysApp.swift` — creates `ModelContainer` (CloudKit-backed, falls back to local), creates `SyncStatusManager`, injects both into the SwiftUI environment.

### Services

| File | Role |
|---|---|
| `SyncStatusManager.swift` | `@Observable` — listens to `NSPersistentCloudKitContainer.eventChangedNotification`, exposes `.state` enum |
| `SeedDataService.swift` | Seeds `WalkRecord` data from `target_list.json` on first launch; skips if records already exist (CloudKit delivery) or UserDefaults flag set |
| `LocationManager.swift` | CLLocationManager wrapper for current location |
| `PhotoService.swift` | Photo capture, thumbnail generation |

### Models (SwiftData)

| Model | Key fields |
|---|---|
| `WalkRecord` | `stairwayID`, `walked`, `dateWalked`, `notes`, `stepCount`, `photos: [WalkPhoto]?` |
| `WalkPhoto` | `imageData` (externalStorage), `thumbnailData` (externalStorage), `caption`, `walkRecord` |
| `Stairway` | Value type loaded from `all_stairways.json` bundle resource |

#### Three-State Stairway Model

Every stairway exists in one of three states, derived from `WalkRecord`:
- **Unsaved** — no `WalkRecord`; amber (#D4882B) teardrop pin at 50% opacity, 3-step stair icon (24×30pt)
- **Saved** — `WalkRecord.walked == false`; light green (#81C784) pin, 3-step stair icon (28×35pt)
- **Walked** — `WalkRecord.walked == true`; green (#4CAF50) pin, 3-step stair icon (28×35pt)

All three states use the same `"stairs"` SF Symbol. Selected pins darken one step and scale to 34×42pt. Dimmed pins (Around Me active, out of zone) render at 30% opacity.

### Views

- `ContentView` — `TabView` (Map / List / Progress)
- `MapTab` — MapKit full-screen map (dark appearance), white top bar with amber logo + search/Around Me circle buttons, filter pills (All/Saved/Walked/Nearby) with dark-inactive/amber-active styling, no bottom bar
- `ListTab` — searchable, filterable stairway list (All/Walked/Saved); `NavigationLink` to detail
- `ProgressTab` — completion ring, stats grid, neighborhood breakdown, recent walks; sync status icon in toolbar
- `StairwayDetail` — walk logging, photo management
- `StairwayAnnotation` — delegates to `StairwayPin` with three-state + dimming support
- `TeardropPin` — reusable SwiftUI teardrop `Shape` + `StairwayPin` view
- `StairwayBottomSheet` — three-state action buttons (Save/Unsave/Mark Walked/Unmark/Remove)
- `SearchPanel` — full-screen search modal with Name/Street/Neighborhood tabs
- `AroundMeManager` — `@Observable`; nearest-centroid neighborhood detection, adjacency lookup, pin dimming state
- `ToastView` + `.toast()` modifier — auto-dismissing toast messages

### Bundled Resources

| File | Purpose |
|------|---------|
| `all_stairways.json` | 382 SF stairways catalog (read-only) |
| `neighborhood_centroids.json` | Avg lat/lng per neighborhood (from `scripts/build_neighborhood_adjacency.py`) |
| `neighborhood_adjacency.json` | Neighborhood → neighbors map (≤2.5km centroid distance) |

To regenerate neighborhood data: `python3 scripts/build_neighborhood_adjacency.py`

### CloudKit Setup

- Container: `iCloud.com.o4dvasq.sfstairways`
- Entitlements: `aps-environment: development`, iCloud container + CloudKit service
- Required manual Xcode step: Background Modes → Remote Notifications (enables push-triggered sync)
- Xcode project at `ios/SFStairways.xcodeproj` (in repo)

## iOS Data Flow

```
all_stairways.json ──► StairwayStore ──► MapTab / ListTab / SearchPanel
                            │
neighborhood_centroids.json ─┬─► AroundMeManager ──► pin dimming + neighborhood chip
neighborhood_adjacency.json ─┘

SwiftData (WalkRecord) ◄──► CloudKit ──► synced across devices
```

`StairwayStore` loads stairway data at init and exposes search/filter/region helpers. `WalkRecord` is the only write path — all stairway state is derived from walk records.
