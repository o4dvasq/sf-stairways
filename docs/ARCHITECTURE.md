# Architecture — sf-stairways

## GitHub Pages (Static Web)

### Files

| File | Purpose |
|---|---|
| `index.html` | Landing page — beta signup, hero, features, story |
| `privacy.html` | Privacy policy — required for Apple TestFlight external distribution |
| `legacy/index.html` | Deprecated Leaflet web app — preserved for reference |

### Landing Page Structure

Single HTML file, inline CSS, no JavaScript. Google Fonts CDN is the only external dependency.

- **Hero** — `min-height: 100svh`, background image from Unsplash CDN (Oscar will replace with original photography), dark gradient overlay, Instrument Serif heading, brand orange `#E8602C` CTA button
- **Features** — 5 items with inline SVG icons
- **Story** — 3-paragraph personal narrative with blockquote
- **CTA strip** — secondary call to action in brand orange background
- **Footer** — copyright + link to `privacy.html`

**Fonts:** Instrument Serif (headlines) + DM Sans (body) via Google Fonts CDN.

**TestFlight link:** Both CTA buttons link to `https://testflight.apple.com/join/PLACEHOLDER`. Update the `href` in `index.html` (two occurrences) when the TestFlight public link is live.

### Data File Schema

`data/all_stairways.json` — array of objects (read by iOS app only, not the web pages):

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

## macOS Admin Dashboard

Source at `ios/SFStairwaysMac/`. Added as a second target in `SFStairways.xcodeproj` on 2026-03-29.

### Entry Point

`SFStairwaysMacApp.swift` — creates `ModelContainer` using the same CloudKit container as iOS (`iCloud.com.o4dvasq.sfstairways`), falls back to local storage on failure. Sets default window size 1200×720.

### Shared Code (macOS target membership)

The following iOS source files are also compiled into the macOS target:

- `Models/WalkRecord.swift`, `WalkPhoto.swift`, `StairwayOverride.swift`, `StairwayTag.swift`, `TagAssignment.swift`
- `Models/StairwayStore.swift`, `Stairway.swift`, `SupabaseModels.swift`, `PhotoSource.swift`
- `Resources/AppColors.swift`
- `all_stairways.json`, `sf_neighborhoods.geojson` bundle resources

`WalkPhoto.swift` uses `#if canImport(UIKit)` guards around `UIImage`-specific computed properties and `UIGraphicsImageRenderer` thumbnail generation, which are iOS-only. macOS views access photo data via raw `Data` → `NSImage(data:)` directly.

### macOS Views

| File | Purpose |
|---|---|
| `Views/StairwayBrowser.swift` | Three-column `NavigationSplitView`: sidebar with neighborhood walked/total counts + Tags section (per-tag counts, clickable filter); **fully sortable `Table`** (Name, Height, Photos, Date Walked — nil values sort to bottom in both directions via `nilLastSorted`); detail column; toolbar with Tags, Data Hygiene, Bulk Actions, and **Acknowledgements (info.circle)** buttons; `AcknowledgementsSheet` defined at bottom of file |
| `Views/TagManagerSheet.swift` | Full tag CRUD: preset tags (read-only list with assignment counts); custom tags (inline rename, delete with cascade confirmation, assignment counts); new-tag creation with slug ID generation and uniqueness validation |
| `Views/StairwayDetailPanel.swift` | Catalog vs. walk data comparison grid; editable curator overrides (height, description) with Save; notes → promote to curator description; tag add/remove via `Menu` with "Create & Assign…" inline option; local photo grid (NSImage from Data) with per-photo delete confirm; drag-drop + NSOpenPanel photo import |
| `Views/DataHygieneView.swift` | Two-column issue browser: sidebar with issue type filter + counts, `Table` of flagged stairways; detects: missing height, missing coordinates, promotion candidates (notes without curator description), proximity-unverified walks |
| `Views/BulkOperationsSheet.swift` | Bulk tag assign (with "Create new tag…" inline option); **Remove Tag from All Selected** section (picker shows only tags on selected stairways); bulk mark walked with `DatePicker`; CSV export via `NSSavePanel` (name, neighborhood, height, walked, date walked) |

### macOS Data Flow

```
all_stairways.json ──► StairwayStore ──► StairwayBrowser (sidebar + table)

CloudKit ──► SwiftData (same container as iOS) ──► @Query in StairwayBrowser
                                                         │
                              WalkRecord, StairwayOverride, StairwayTag, TagAssignment
                                                         │
                                               StairwayDetailPanel (read + write)
                                               DataHygieneView (read only)
                                               BulkOperationsSheet (write)
```

No Supabase, no HealthKit on macOS. Legacy walk data field (`elevationGain`) from past active walks is displayed in the detail panel under "Walk Data (legacy)" for reference but is no longer actively populated.

---

## iOS Admin App

Source at `ios/SFStairwaysAdmin/`. Separate iOS target in `SFStairways.xcodeproj`, bundle ID `com.o4dvasq.SFStairways.admin`. Field maintenance tool for catalog corrections, deletion, and tag management. No map, no photo management, no HealthKit, no Supabase.

### Shared Code (admin target membership)

- All `Models/*.swift` (WalkRecord, WalkPhoto, StairwayOverride, StairwayTag, TagAssignment, StairwayDeletion)
- `Models/StairwayStore.swift`, `Models/Stairway.swift`
- `Resources/AppColors.swift`
- `Services/SyncStatusManager.swift`
- `all_stairways.json`, `tags_preset.json` bundle resources

### Admin Views

| File | Purpose |
|---|---|
| `SFStairwaysAdminApp.swift` | App entry point; same schema + CloudKit setup as iOS and macOS (all six SwiftData models); falls back to local storage on CloudKit failure |
| `Views/AdminBrowser.swift` | Root: searchable stairway list; filter chips (All/Walked/Unwalked/Has Override/Has Issues); sort menu (Name/Neighborhood/Date Walked); row shows walked icon, override indicator (pencil), tag count badge; toolbar: Tag Manager + Removed Stairways buttons |
| `Views/AdminDetailView.swift` | Push-navigation detail: catalog data (read-only), editable override fields (height ft, curator description) with Save/Cancel, tag chips with X-to-remove + Add Tag (picker + "Create Tag…" inline), "Remove Stairway" destructive action with optional reason field |
| `Views/AdminTagManager.swift` | Modal: preset tags (read-only, counts); custom tags (inline rename, delete with cascade count confirmation, create new) |
| `Views/RemovedStairwaysView.swift` | Modal: list of StairwayDeletion records (name, date, reason); swipe to restore (deletes the record, stairway reappears everywhere) |

### Admin Data Flow

```
all_stairways.json ──► StairwayStore ──► AdminBrowser (all stairways)
                                              │
                              StairwayDeletion (CloudKit) ──► applyDeletions → filtered out
                              WalkRecord (CloudKit, read-only) ──► walked state + detail
                              StairwayOverride (CloudKit, read+write) ──► override fields
                              StairwayTag + TagAssignment (CloudKit, read+write) ──► tag management
```

---

## iOS App Structure

Source at `ios/SFStairways/`. iOS is the primary user-facing platform. Web app deprecated 2026-03-25.

### Entry Point

`SFStairwaysApp.swift` — creates `ModelContainer` (CloudKit-backed, falls back to local), creates `SyncStatusManager`, `AuthManager`, and `NeighborhoodStore`, injects all into the SwiftUI environment via `.environment()`.

### Services

| File | Role |
|---|---|
| `SyncStatusManager.swift` | `@Observable` — listens to `NSPersistentCloudKitContainer.eventChangedNotification`, exposes `.state` enum |
| `SeedDataService.swift` | Seeds `WalkRecord` data from `target_list.json` on first launch (key: `com.sfstairways.hasSeededData`); seeds preset `StairwayTag` records from `tags_preset.json` on first launch (key: `com.sfstairways.hasSeededTags`); deletes `WalkRecord` where `walked==false` once (key: `com.sfstairways.hasCleanedUnwalked`) to migrate away from the removed Saved state; all seed paths check existing record count first to handle CloudKit delivery; `cleanRetroactiveStatsIfNeeded` was removed after its one-time migration ran |
| `LocationManager.swift` | CLLocationManager wrapper for current location; `isWithinRadius(_:ofLatitude:longitude:)` for Hard Mode proximity check |
| `PhotoService.swift` | Photo capture, thumbnail generation; `CameraPicker.Coordinator` saves to system camera roll via `PHPhotoLibrary.performChanges` (fire-and-forget, silent failure on permission denial) |
| `SupabaseManager.swift` | Singleton Supabase client; reads project URL + anon key from `Config/Supabase.plist` (gitignored); crashes with clear message if plist is missing |
| `AuthManager.swift` | `@Observable` — wraps Supabase Auth session; restores session from Keychain on init; `handleAppleAuthorization(_:)` receives credential from `SignInWithAppleButton.onCompletion` and calls `signInWithIdToken` directly; injected via `.environment()` |
| `NavigationCoordinator.swift` | `@Observable` — cross-tab navigation state; `pendingStairway: Stairway?` and `pendingNeighborhood: String?` are set by SearchTab and consumed by MapTab to trigger fly-to; injected via `.environment()` from ContentView |

### Models (SwiftData)

| Model | Key fields |
|---|---|
| `WalkRecord` | `stairwayID`, `walked`, `dateWalked`, `notes`, `photos: [WalkPhoto]?`, `hardMode: Bool`, `proximityVerified: Bool?`; legacy fields retained for CloudKit schema compatibility: `elevationGain`, `walkStartTime`, `walkEndTime` (no longer populated or displayed in iOS) |
| `WalkPhoto` | `imageData` (externalStorage), `thumbnailData` (externalStorage), `caption`, `walkRecord` |
| `StairwayOverride` | `stairwayID`, `verifiedHeightFt: Double?`, `stairwayDescription: String?`, `createdAt`, `updatedAt` |
| `StairwayTag` | `id` (slug), `name`, `isPreset: Bool`, `createdAt` |
| `TagAssignment` | `stairwayID`, `tagID`, `assignedAt` — many-to-many join; independent of `WalkRecord` |
| `StairwayDeletion` | `stairwayID` (@Attribute(.unique)), `deletedAt`, `reason: String?` — inserted when a stairway is hidden/removed from the catalog; syncs via CloudKit; all targets (iOS, macOS, admin) filter stairways against this table via `StairwayStore.applyDeletions(_:)`; delete the record to restore |
| `Stairway` | Value type loaded from `all_stairways.json` bundle resource; computed `displayName` truncates to first 4 words, stripping trailing `.,;` from each word (no ellipsis) — used for map annotation labels only; full `name` used everywhere else |
| `PhotoSource` | Enum (not SwiftData): `.remote(SupabasePhoto)` / `.local(WalkPhoto)`; `Identifiable`; `createdAt` for merged sort |

#### Two-State Stairway Model

Every stairway exists in one of three states, derived from `WalkRecord`:
- **Unsaved** — no `WalkRecord`

- **Walked** — `WalkRecord.walked == true`

**Pins** are colored circles: `brandAmber` for unsaved, `walkedGreen` for walked. Selected pins use darker variants and expand to 24pt diameter. Unselected base sizes: 12pt (unsaved), 16pt (walked). All sizes are multiplied by a `scale` factor (1.0–2.0) driven by map zoom level. Tap target is `max(44, scaledSize)` via an outer frame + `.contentShape(Rectangle())`. Thin dark stroke overlay (0.3 opacity, 1pt). Dimmed pins render at 30% opacity. Closed stairways use `unwalkedSlate` at 40% opacity. `TeardropShape` and `StairShape` are kept in `TeardropPin.swift` for future use.

**Unverified badge:** Walk records with `proximityVerified == false` show an amber `xmark.seal.fill` icon — same shape as the green `checkmark.seal.fill` verified badge, different color and icon. Shown inline next to "Walked" in `StairwayBottomSheet` and replaces the green checkmark in `StairwayRow`.

#### StairwayOverride Fallback Chain

For height display: use `StairwayOverride.verifiedHeightFt` if non-nil → else catalog value (`Stairway.heightFt`) → else nothing. The `StairwayStore` provides `resolvedHeightFt(for:override:)`. Views that display stats query `StairwayOverride` records and look up by `stairwayID`. Verified values render with a `checkmark.seal.fill` badge in `forestGreen`.

### Views

- `ContentView` — `TabView` (Map / List / Stats / Search); holds `NavigationCoordinator` in `@State` and injects via `.environment(coordinator)`; `SearchTab` inner view wraps `SearchPanel` with `isTabMode: true` and its own `StairwayStore` + `LocationManager`; cross-tab navigation via coordinator + 0.1s `asyncAfter` to allow tab switch before map fly-to; calls `applyRoundedNavBarAppearance()` on appear to set `UINavigationBarAppearance` globally with SF Pro Rounded large-title and inline-title fonts
- `MapTab` — MapKit full-screen map (follows system light/dark — no forced color scheme), `brandAmber` top bar with leading gear (settings) and trailing Around Me + Tag Filter; filter pills (All/Walked/Nearby); floating `ProgressCard` (bottom-right, 120pt wide); launches at default city-wide view (latDelta ~0.06); tracks `mapSpan` via `.onMapCameraChange(frequency: .onEnd)`; annotation labels use `stairway.displayName` and are hidden when `mapSpan > 0.02`; **neighborhood polygon overlays** (`MapPolygon` per ring, drawn first in Map content below all annotations): fill 30% alpha light / 20% dark, stroke 50%/40%; dimmed to 5%/10% when Around Me active and neighborhood not highlighted; **centroid label annotations**: `caption2` Rounded font at 60% opacity, visible only when `mapSpan < 0.04`; tapping a label opens `NeighborhoodDetail` as a sheet (wrapped in `NavigationStack`); pin taps unaffected (polygon tap is visual-only per fallback strategy); consumes `NavigationCoordinator` from environment
- `ListTab` — searchable, filterable stairway list (All/Walked); tap row → `StairwayBottomSheet` sheet; **section headers are `NavigationLink(value: group.name)`** → push `NeighborhoodDetail` onto the NavigationStack; `navigationDestination(for: String.self)` registered on the List
- `ProgressTab` (tab label: "Stats") — compact ring (~80pt, `brandOrange` stroke, spring animation) in HStack alongside text block (walked/total in `.title3` Rounded, %+height ft + neighborhood count in `.subheadline` Rounded secondary); **2-column `LazyVGrid` of `NeighborhoodCard` views** for neighborhoods with ≥1 walk, sorted by completion % descending (tie-break: most recent `dateWalked`); card data derived by grouping `StairwayStore.stairways` by `.neighborhood` field; collapsible "Undiscovered" section (`@AppStorage("progress.undiscovered.collapsed")`) lists neighborhoods with 0 walks as tappable `NavigationLink` rows; all cards and undiscovered names navigate to `NeighborhoodDetail` via `NavigationLink(value: name)` + `.navigationDestination(for: String.self)`; toolbar has sync icon; height stat uses `resolvedHeightFt`; `StatCard` struct removed; `NeighborhoodCard.swift` in `Views/Progress/`
- `SettingsView` — sheet from gear icon in ProgressTab toolbar; Account section (Sign in with Apple / signed-in state + Sign Out); iCloud Sync section (mirrors sync status); Walking section (Hard Mode toggle only — no HealthKit); **Acknowledgements section** (SF Stairways credit + link, Urban Hiker SF credit + links, Buy a Matcha link with amber cup icon, book credit)
- `StairwayBottomSheet` — **single detail surface for the whole app**; self-contained with `@Query`, `@Environment(\.modelContext)`, `@Environment(\.dismiss)`; two detent states: collapsed `.height(390)` and expanded `.large`; **neighborhood name in header is a tappable button** (chevron indicator) → opens `NeighborhoodDetail` as a sheet; "Mark Walked" is the only action for unwalked stairways (no Start Walk); walk status card shows walked date + proximity badge; tags section; `mergedPhotos: [PhotoSource]` combines remote + local photos; `PhotoSuggestionService` uses full calendar day of `dateWalked` as photo search window; **share button** (`square.and.arrow.up`, brandOrange) in header for walked stairways only → `generateShareCard()` renders `ShareCardView` via `ImageRenderer` at 3× and opens `ActivityShareSheet`
- `ShareCardView` (`Views/ShareCardView.swift`) — SwiftUI view rendered via `ImageRenderer` to produce a 1080×1920 share card (360×640pt @ scale 3.0); photo-backed layout (top 60% `UIImage` fill, bottom cream text panel) or no-photo layout (brand orange bg, white text); also defines `ActivityShareSheet` (`UIViewControllerRepresentable` wrapping `UIActivityViewController`); entire file wrapped in `#if canImport(UIKit)` — iOS target only
- `StairwayAnnotation` — delegates to `StairwayPin` with three-state + dimming + unverified badge support; accepts `scale: CGFloat` and passes through to `StairwayPin`
- `TeardropPin` — `StairwayPin` view (colored circles, three-state colors + dimming); `TeardropShape` and `StairShape` structs kept for future use; `showUnverifiedBadge` amber overlay
- `SearchPanel` — search UI with Name/Street/Neighborhood/Tags tabs; `isTabMode: Bool` parameter hides the dismiss button when used as a persistent tab; Tags tab shows pill grid of all assigned tags → tap to drill into stairway list; **Neighborhood tab rows are `NavigationLink(value:)`** → push `NeighborhoodDetail` onto the inner `NavigationStack` (replaces old fly-to-map behavior); `navigationDestination(for: String.self)` registered on the NavigationStack's VStack
- `NeighborhoodDetail` (`Views/Neighborhood/NeighborhoodDetail.swift`) — neighborhood hub view; receives `neighborhoodName: String`; resolves polygon + stairways via `@Environment(NeighborhoodStore.self)` + local `StairwayStore`; shows: large navigation title, progress bar (walked/total, `brandOrange` tint), embedded 200pt `Map` (neighborhood polygon fill + stairway pins, region fitted to polygon bounds), horizontal photo scroll (hidden if none; tapping opens `PhotoViewer` sheet with deletion support), stairway list (walked first sorted by `dateWalked` desc, unwalked alphabetical); tap any stairway row → `StairwayBottomSheet` sheet; presented as pushed destination from ListTab/SearchPanel, or wrapped in `NavigationStack` sheet from MapTab/StairwayBottomSheet
- `AroundMeManager` — `@Observable`; nearest-centroid neighborhood detection using `NeighborhoodStore`, adjacency lookup, pin dimming state; store passed at `activate(location:store:)` call site
- `ToastView` + `.toast()` modifier — auto-dismissing toast messages

### Bundled Resources

| File | Purpose |
|------|---------|
| `all_stairways.json` | 382 SF stairways catalog (read-only); neighborhood field uses SF 311 Neighborhood names |
| `sf_neighborhoods.geojson` | 117 SF 311 Neighborhood polygons (property key `name`); loaded by `NeighborhoodStore` at startup to compute centroids + adjacency |
| `tags_preset.json` | 9 preset tag suggestions seeded into SwiftData on first launch |

Neighborhood data (centroids, adjacency) is computed at runtime from the GeoJSON — no separate pre-computed JSON files.

### CloudKit Setup

- Container: `iCloud.com.o4dvasq.sfstairways`
- Entitlements: `aps-environment: development`, iCloud container + CloudKit service, `com.apple.developer.applesignin` (HealthKit entitlement removed)
- Required manual Xcode step: Background Modes → Remote Notifications (enables push-triggered sync); Sign in with Apple capability
- Xcode project at `ios/SFStairways.xcodeproj` (in repo)

## iOS Data Flow

```
all_stairways.json ──► StairwayStore ──► MapTab / ListTab / SearchPanel

sf_neighborhoods.geojson ──► NeighborhoodStore (startup) ──► centroids, adjacency, PiP lookup
                                      │
                              .environment() ──► MapTab ──► polygon overlays + centroid labels
                                              │          ──► AroundMeManager.activate(location:store:)
                                              │          ──► pin dimming + neighborhood chip
                                              └──► NeighborhoodDetail ──► embedded map polygon
                                                                       ──► progress + stairway list

SwiftData (WalkRecord)       ◄──► CloudKit ──► synced across devices
SwiftData (StairwayOverride) ◄──► CloudKit ──► synced across devices
SwiftData (StairwayTag)      ◄──► CloudKit ──► synced across devices
SwiftData (TagAssignment)    ◄──► CloudKit ──► synced across devices
         │
         └──► resolvedHeightFt ──► stats display everywhere

tags_preset.json ──► SeedDataService.seedTagsIfNeeded ──► StairwayTag (preset records, once)

Supabase.plist (gitignored) ──► SupabaseManager ──► AuthManager ──► SettingsView
                                                          │
                                              session (Keychain) + auth state changes

NavigationCoordinator (ContentView @State) ──► .environment() ──► MapTab (consumes pendingStairway/pendingNeighborhood)
                                                                ──► SearchTab → sets pendingStairway/pendingNeighborhood → switches to tab 0
```

`StairwayStore` loads stairway data at init and exposes search/filter/region/resolver helpers. The `stairways` computed property filters `_allStairways` against `deletedIDs` (a `Set<String>` updated via `applyDeletions(_:)`); views call `applyDeletions` in `.onAppear` and `.onChange(of: deletions)` to keep the exclusion set current. `WalkRecord`, `StairwayOverride`, `StairwayTag`, `TagAssignment`, and `StairwayDeletion` are independent write paths, all keyed by `stairwayID` (or `tagID`). `AuthManager` manages the Supabase session independently of SwiftData — the two persistence layers coexist without interaction in the current phase.
