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

`SFStairwaysApp.swift` — creates `ModelContainer` (CloudKit-backed, falls back to local), creates `SyncStatusManager` and `AuthManager`, injects all three into the SwiftUI environment via `.environment()`.

### Services

| File | Role |
|---|---|
| `SyncStatusManager.swift` | `@Observable` — listens to `NSPersistentCloudKitContainer.eventChangedNotification`, exposes `.state` enum |
| `SeedDataService.swift` | Seeds `WalkRecord` data from `target_list.json` on first launch; skips if records already exist (CloudKit delivery) or UserDefaults flag set |
| `LocationManager.swift` | CLLocationManager wrapper for current location; `isWithinRadius(_:ofLatitude:longitude:)` for Hard Mode proximity check |
| `PhotoService.swift` | Photo capture, thumbnail generation |
| `SupabaseManager.swift` | Singleton Supabase client; reads project URL + anon key from `Config/Supabase.plist` (gitignored); crashes with clear message if plist is missing |
| `AuthManager.swift` | `@Observable` — wraps Supabase Auth session; restores session from Keychain on init; `handleAppleAuthorization(_:)` receives credential from `SignInWithAppleButton.onCompletion` and calls `signInWithIdToken` directly; injected via `.environment()` |

### Models (SwiftData)

| Model | Key fields |
|---|---|
| `WalkRecord` | `stairwayID`, `walked`, `dateWalked`, `notes`, `stepCount`, `photos: [WalkPhoto]?`, `hardMode: Bool`, `proximityVerified: Bool?` |
| `WalkPhoto` | `imageData` (externalStorage), `thumbnailData` (externalStorage), `caption`, `walkRecord` |
| `StairwayOverride` | `stairwayID`, `verifiedStepCount: Int?`, `verifiedHeightFt: Double?`, `stairwayDescription: String?`, `createdAt`, `updatedAt` |
| `Stairway` | Value type loaded from `all_stairways.json` bundle resource |

#### Three-State Stairway Model

Every stairway exists in one of three states, derived from `WalkRecord`:
- **Unsaved** — no `WalkRecord`
- **Saved** — `WalkRecord.walked == false`
- **Walked** — `WalkRecord.walked == true`

**Pins** are colored circles: gray (`Color(white: 0.55)`) for unsaved, `brandOrange` for saved, `walkedGreen` for walked. Selected pins use darker variants (`Color(white: 0.7)` / `brandOrangeDark` / `walkedGreenDark`) and expand to 24pt diameter. Unselected sizes: 12pt (unsaved), 16pt (saved/walked). Thin dark stroke overlay (0.3 opacity, 1pt). Dimmed pins render at 30% opacity. Closed stairways use `unwalkedSlate` at 40% opacity. `TeardropShape` and `StairShape` are kept in `TeardropPin.swift` for future use.

**Unverified badge:** Walked pins with `hardMode = true` and `proximityVerified = false` display a 10pt amber (`accentAmber` #E8A838) circle with an exclamation mark at the top-right of the bulb. Computed via `WalkRecord.showUnverifiedBadge`, passed through `StairwayAnnotation` to `StairwayPin.showUnverifiedBadge`.

#### StairwayOverride Fallback Chain

For any stat display (stair count, height): use `StairwayOverride` value if non-nil → else catalog value (`Stairway.heightFt`) → else nothing. The `StairwayStore` provides `resolvedStepCount(for:override:)` and `resolvedHeightFt(for:override:)` helpers. Views that display stats query `StairwayOverride` records and look up by `stairwayID`. Verified values render with a `checkmark.seal.fill` badge in `forestGreen`.

### Views

- `ContentView` — `TabView` (Map / List / Progress)
- `MapTab` — MapKit full-screen map (dark appearance), plain `brandOrange` top bar with trailing icon buttons (search, Around Me), filter pills (All/Saved/Walked/Nearby), floating `ProgressCard` (bottom-right, 120pt wide) with `brandOrange` header
- `ListTab` — searchable, filterable stairway list (All/Walked/Saved); `NavigationLink` to detail; queries `StairwayOverride` and passes to each row
- `ProgressTab` — completion ring, stats grid, neighborhood breakdown, recent walks; toolbar has sync icon + gear icon; height stat uses `resolvedHeightFt`
- `SettingsView` — sheet from gear icon in ProgressTab toolbar; Account section (Sign in with Apple / signed-in state + Sign Out); iCloud Sync section (mirrors sync status)
- `StairwayDetail` — focused mini-map at top (non-interactive, 200pt), walk logging, Save button in toolbar (when unsaved), curator data section (walked-only, inline editable fields), Hard Mode toggle, notes, photo grid
- `StairwayAnnotation` — delegates to `StairwayPin` with three-state + dimming + unverified badge support
- `TeardropPin` — `StairwayPin` view (colored circles, three-state colors + dimming); `TeardropShape` and `StairShape` structs kept for future use; `showUnverifiedBadge` amber overlay
- `StairwayBottomSheet` — three-state action buttons; Hard Mode toggle row; proximity-gated Mark Walked
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
- Entitlements: `aps-environment: development`, iCloud container + CloudKit service, `com.apple.developer.applesignin`
- Required manual Xcode step: Background Modes → Remote Notifications (enables push-triggered sync); Sign in with Apple capability
- Xcode project at `ios/SFStairways.xcodeproj` (in repo)

## iOS Data Flow

```
all_stairways.json ──► StairwayStore ──► MapTab / ListTab / SearchPanel
                            │
neighborhood_centroids.json ─┬─► AroundMeManager ──► pin dimming + neighborhood chip
neighborhood_adjacency.json ─┘

SwiftData (WalkRecord)       ◄──► CloudKit ──► synced across devices
SwiftData (StairwayOverride) ◄──► CloudKit ──► synced across devices
         │
         └──► resolvedStepCount / resolvedHeightFt ──► stats display everywhere

Supabase.plist (gitignored) ──► SupabaseManager ──► AuthManager ──► SettingsView
                                                          │
                                              session (Keychain) + auth state changes
```

`StairwayStore` loads stairway data at init and exposes search/filter/region/resolver helpers. `WalkRecord` and `StairwayOverride` are independent write paths, both keyed by `stairwayID`. `AuthManager` manages the Supabase session independently of SwiftData — the two persistence layers coexist without interaction in the current phase.
