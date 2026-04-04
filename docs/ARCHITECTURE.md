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

Source at `ios/SFStairwaysAdmin/`. Separate iOS target in `SFStairways.xcodeproj`, bundle ID `com.o4dvasq.SFStairways.admin`. Field maintenance tool for catalog corrections, deletion, tag management, and spatial review. No photo management, no HealthKit, no Supabase.

### Shared Code (admin target membership)

- All `Models/*.swift` (WalkRecord, WalkPhoto, StairwayOverride, StairwayTag, TagAssignment, StairwayDeletion)
- `Models/StairwayStore.swift`, `Models/Stairway.swift`
- `Resources/AppColors.swift`
- `Services/SyncStatusManager.swift`
- `all_stairways.json`, `tags_preset.json` bundle resources

### Admin Views

| File | Purpose |
|---|---|
| `SFStairwaysAdminApp.swift` | App entry point; same schema + CloudKit setup as iOS and macOS; root view is `AdminContentView` |
| `Views/AdminContentView.swift` | Root `TabView`: Map tab (`AdminMapTab`) + List tab (`AdminBrowser`) |
| `Views/AdminMapTab.swift` | Full-screen MapKit map; default center SF (37.76, -122.44) span 0.06; all stairways as colored circle pins with 4-state priority: red/0.8 (has issues) > blue/0.8 (has override) > `walkedGreen` (walked) > `brandAmber` (default); `AdminMapFilter` enum (All/Has Issues/Has Overrides/Unwalked/Walked); labels at span < 0.02; tap pin → `AdminDetailView` sheet; `MapUserLocationButton`; Tag Manager toolbar button |
| `Views/AdminBrowser.swift` | Searchable stairway list; filter chips (All/Walked/Unwalked/Has Override/Has Issues); sort menu (Name/Neighborhood/Date Walked); row shows walked icon, override indicator, tag count badge; toolbar: Tag Manager + Removed Stairways |
| `Views/AdminDetailView.swift` | Detail (push-navigation or sheet): catalog data (read-only), editable override fields (height ft, curator description) with Save/Cancel, tag chips with X-to-remove + Add Tag, "Remove Stairway" destructive action |
| `Views/AdminTagManager.swift` | Modal: preset tags (read-only, counts); custom tags (inline rename, delete with cascade count confirmation, create new) |
| `Views/RemovedStairwaysView.swift` | Modal: list of StairwayDeletion records (name, date, reason); swipe to restore (deletes the record, stairway reappears everywhere) |

### Admin Data Flow

```
all_stairways.json ──► StairwayStore ──► AdminMapTab (map pins)
                                      ──► AdminBrowser (list)
                                              │
                              StairwayDeletion (CloudKit) ──► applyDeletions → filtered out
                              WalkRecord (CloudKit, read-only) ──► walked state (pin color + list badge)
                              StairwayOverride (CloudKit, read+write) ──► pin color + override fields
                              StairwayTag + TagAssignment (CloudKit, read+write) ──► tag management
```

---

## iOS App Structure

Source at `ios/SFStairways/`. iOS is the primary user-facing platform. Web app deprecated 2026-03-25.

### Entry Point

`SFStairwaysApp.swift` — creates `ModelContainer` (CloudKit-backed, falls back to local), creates `SyncStatusManager`, `AuthManager`, `NeighborhoodStore`, and `CommunityService`, injects all into the SwiftUI environment via `.environment()`. On `ContentView.onAppear`, calls `communityService.fetchClimbCounts()` to prime the cache.

### Services

| File | Role |
|---|---|
| `SyncStatusManager.swift` | `@Observable` — listens to `NSPersistentCloudKitContainer.eventChangedNotification`, exposes `.state` enum |
| `SeedDataService.swift` | Seeds `WalkRecord` data from `target_list.json` on first launch (key: `com.sfstairways.hasSeededData`); seeds preset `StairwayTag` records from `tags_preset.json` on first launch (key: `com.sfstairways.hasSeededTags`); deletes `WalkRecord` where `walked==false` once (key: `com.sfstairways.hasCleanedUnwalked`); `runTagDedupMigrationIfNeeded` deduplicates `StairwayTag` + `TagAssignment` and backfills `compoundKey` once (key: `hasRunTagDedupMigration_v1`); iOS only — Mac inlines the same logic in `SFStairwaysMacApp` |
| `LocationManager.swift` | CLLocationManager wrapper for current location; `isWithinRadius(_:ofLatitude:longitude:)` for Hard Mode proximity check |
| `PhotoService.swift` | Photo capture, thumbnail generation; `CameraPicker.Coordinator` saves to system camera roll via `PHPhotoLibrary.performChanges` (fire-and-forget, silent failure on permission denial) |
| `SupabaseManager.swift` | Singleton Supabase client; reads project URL + anon key from `Config/Supabase.plist` (gitignored); crashes with clear message if plist is missing |
| `AuthManager.swift` | `@Observable` — wraps Supabase Auth session; restores session from Keychain on init; `handleAppleAuthorization(_:)` receives credential from `SignInWithAppleButton.onCompletion` and calls `signInWithIdToken` directly; `hardModeEnabled` is UserDefaults-only (no Supabase sync); injected via `.environment()` |
| `NavigationCoordinator.swift` | `@Observable` — cross-tab navigation state; `pendingStairway: Stairway?` and `pendingNeighborhood: String?` are set by SearchTab and consumed by MapTab to trigger fly-to; injected via `.environment()` from ContentView |
| `NuggetProvider.swift` | Value type; loads `neighborhood_facts.json` from bundle at init; `fact(for:) -> String?` returns the static fact for a named neighborhood; `globalFact(seed:) -> String?` returns a global fact indexed by an integer seed (use day-of-year for daily rotation) |
| `CommunityService.swift` | `@Observable` — fetches `stairway_climb_counts` Supabase view on launch into `climbCounts: [String: Int]` cache; `climberCount(for:) -> Int` for per-stairway lookups; `reportWalk(stairwayID:userID:)` upserts into `stairway_walk_events` (fire-and-forget); `reportUnwalk(stairwayID:userID:)` sets `removed_at`; injected via `.environment()` from `SFStairwaysApp`; guarded by `authManager.isAuthenticated` at call sites |

### Models (SwiftData)

| Model | Key fields |
|---|---|
| `WalkRecord` | `stairwayID`, `walked`, `dateWalked`, `notes`, `photos: [WalkPhoto]?`, `hardMode: Bool`, `proximityVerified: Bool?`; legacy fields retained for CloudKit schema compatibility: `elevationGain`, `walkStartTime`, `walkEndTime` (no longer populated or displayed in iOS) |
| `WalkPhoto` | `imageData` (externalStorage), `thumbnailData` (externalStorage), `caption`, `walkRecord` |
| `StairwayOverride` | `stairwayID`, `verifiedHeightFt: Double?`, `stairwayDescription: String?`, `createdAt`, `updatedAt` |
| `StairwayTag` | `@Attribute(.unique) id` (slug), `name`, `isPreset: Bool`, `createdAt`, `colorIndex: Int` (default 0; random on user creation, sequential 0–11 for preset seeds; indexes into `Color.tagPalette` in `AppColors`); unique constraint causes CloudKit sync to upsert instead of duplicating |
| `TagAssignment` | `compoundKey` (`stairwayID::tagID`, set by `init`), `stairwayID`, `tagID`, `assignedAt` — many-to-many join; `@Attribute(.unique)` on `compoundKey` deferred until after all rows are backfilled; duplicate prevention via code-level guards + view-layer dedup |
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
- `MapTab` — MapKit full-screen map (follows system light/dark — no forced color scheme), `brandAmber` top bar with leading gear (settings) and trailing Around Me + Tag Filter; filter pills (All/Walked/Nearby); floating `ProgressCard` (bottom-right, 120pt wide); launches at default city-wide view (latDelta ~0.06); tracks `mapSpan` via `.onMapCameraChange(frequency: .onEnd)`; annotation labels use `stairway.displayName` and are hidden when `mapSpan > 0.02`; **neighborhood polygon overlays** (`MapPolygon` per ring, drawn first in Map content below all annotations): completed neighborhoods use `Color.walkedGreen` fill (35% alpha) + stroke (65%) + 1.5pt lineWidth; incomplete neighborhoods use their assigned color at 30%/20% fill / 50%/40% stroke (light/dark); dimmed to 5%/10% when Around Me active and neighborhood not highlighted; `completedNeighborhoodNames: Set<String>` is a computed property derived from `walkedStairwayIDs` + `store.stairways`; **centroid label annotations**: `caption2` Rounded font at 60% opacity, visible only when `mapSpan < 0.04`; tapping a label opens `NeighborhoodDetail` as a sheet (wrapped in `NavigationStack`); pin taps unaffected (polygon tap is visual-only per fallback strategy); consumes `NavigationCoordinator` from environment
- `ListTab` — searchable, filterable stairway list (All/Walked); tap row → `StairwayBottomSheet` sheet; **section headers are `NavigationLink(value: group.name)`** → push `NeighborhoodDetail` onto the NavigationStack; `navigationDestination(for: String.self)` registered on the List
- `ProgressTab` (tab label: "Stats") — compact ring (~80pt, `brandOrange` stroke, spring animation) in HStack alongside text block (walked/total in `.title3` Rounded, %+height ft in `.subheadline` secondary, neighborhood count with optional "· N verified" suffix appended when `verifiedCount > 0`); **daily rotating global nugget** (tertiary caption below ring, seeded by `Calendar.ordinality(of: .day, in: .year)` into `NuggetProvider.globalFact`); **2-column `LazyVGrid` of `NeighborhoodCard` views** for neighborhoods with ≥1 walk, sorted by completion % descending (tie-break: most recent `dateWalked`); `NeighborhoodCard` shows `checkmark.seal.fill` walkedGreen badge when `walked == total`; card data derived by grouping `StairwayStore.stairways` by `.neighborhood` field; collapsible "Undiscovered" section (`@AppStorage("progress.undiscovered.collapsed")`) lists neighborhoods with 0 walks as tappable `NavigationLink` rows; all cards and undiscovered names navigate to `NeighborhoodDetail` via `NavigationLink(value: name)` + `.navigationDestination(for: String.self)`; toolbar has sync icon; height stat uses `resolvedHeightFt`; `StatCard` struct removed; `NeighborhoodCard.swift` in `Views/Progress/`
- `SettingsView` — sheet from gear icon in ProgressTab toolbar; Account section (Sign in with Apple / signed-in state + Sign Out); iCloud Sync section (mirrors sync status); Walking section (Hard Mode toggle — always enabled regardless of auth state, UserDefaults-backed); **Acknowledgements section** (SF Stairways credit + link, Urban Hiker SF credit + links, Buy a Matcha link with amber cup icon, book credit)
- `StairwayBottomSheet` — **single detail surface for the whole app**; self-contained with `@Query`, `@Environment(\.modelContext)`, `@Environment(\.dismiss)`, `@Environment(CommunityService.self)`; two detent states: collapsed `.height(390)` and expanded `.large`; **neighborhood name in header is a tappable button** → opens `NeighborhoodDetail` as a sheet; "Mark Walked" is the only action for unwalked stairways; **tags section is read-only** (no Add Tag button; section hidden when stairway has no tags); `climberCountBadge` in `statsRow` shows "N climbers" (secondary) or "You're the first!" (brandOrange, when count==1 && isWalked); `markWalked()` fires `communityService.reportWalk` for authenticated users; `removeRecord()` fires `communityService.reportUnwalk`; `mergedPhotos: [PhotoSource]` combines remote + local photos; **share button** for walked stairways only
- `ShareCardView` (`Views/ShareCardView.swift`) — SwiftUI view rendered via `ImageRenderer` to produce a 1080×1920 share card (360×640pt @ scale 3.0); takes `stairwayName`, `neighborhood`, `heightFt`, `photoImage`, `neighborhoodWalked`, `neighborhoodTotal`; **photo layout**: 16pt brandAmber frame around inset photo, white `StairShape`+"SF Stairways" logo overlay (dark pill, top-left), "N of M" progress pill (bottom-right), cream bottom panel with stairway name/neighborhood/stat pills/tagline/URL; **no-photo layout**: brandAmber frame around solid brandOrange content area, stairway name+neighborhood in white inside orange area, larger progress block, cream bottom panel with stat pills/tagline/URL only; also defines `ActivityShareSheet` (`UIViewControllerRepresentable` wrapping `UIActivityViewController`); entire file wrapped in `#if canImport(UIKit)` — iOS target only
- `StairwayAnnotation` — delegates to `StairwayPin` with three-state + dimming + unverified badge support; accepts `scale: CGFloat` and passes through to `StairwayPin`
- `TeardropPin` — `StairwayPin` view (colored circles, three-state colors + dimming); `TeardropShape` and `StairShape` structs kept for future use; `showUnverifiedBadge` amber overlay
- `SearchPanel` — search UI with Name/Street/Neighborhood/Tags tabs; `isTabMode: Bool` parameter hides the dismiss button when used as a persistent tab; Tags tab shows pill grid of all assigned tags → tap to drill into stairway list; **Neighborhood tab rows are `NavigationLink(value:)`** → push `NeighborhoodDetail` onto the inner `NavigationStack` (replaces old fly-to-map behavior); `navigationDestination(for: String.self)` registered on the NavigationStack's VStack
- `NeighborhoodDetail` (`Views/Neighborhood/NeighborhoodDetail.swift`) — neighborhood hub view; receives `neighborhoodName: String`; resolves polygon + stairways via `@Environment(NeighborhoodStore.self)` + local `StairwayStore`; consumes `@Environment(CommunityService.self)` for community stats; shows: large navigation title, **progress section** (when complete: "All X stairways walked ✓" label + walkedGreen `ProgressView`; otherwise standard walked/total + brandOrange bar; **community aggregate** "N total climbers across M stairways" line when > 0; always followed by a per-neighborhood fact from `NuggetProvider`), embedded 200pt `Map`, horizontal photo scroll, stairway list (walked first sorted by `dateWalked` desc, unwalked alphabetical); tap any stairway row → `StairwayBottomSheet` sheet; presented as pushed destination from ListTab/SearchPanel, or wrapped in `NavigationStack` sheet from MapTab/StairwayBottomSheet
- `AroundMeManager` — `@Observable`; nearest-centroid neighborhood detection using `NeighborhoodStore`, adjacency lookup, pin dimming state; store passed at `activate(location:store:)` call site
- `ToastView` + `.toast()` modifier — auto-dismissing toast messages

### Bundled Resources

| File | Purpose |
|------|---------|
| `all_stairways.json` | 382 SF stairways catalog (read-only); neighborhood field uses SF 311 Neighborhood names |
| `sf_neighborhoods.geojson` | 117 SF 311 Neighborhood polygons (property key `name`); loaded by `NeighborhoodStore` at startup to compute centroids + adjacency |
| `tags_preset.json` | 9 preset tag suggestions seeded into SwiftData on first launch |
| `neighborhood_facts.json` | 28 curated facts: 18 neighborhood-specific (one per named neighborhood, includes accurate stairway count) + 10 global SF stairway trivia; loaded by `NuggetProvider` |

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
                                                          │
                              CommunityService ──────────────────► stairway_climb_counts (Supabase view, read)
                                    │                             ► stairway_walk_events (Supabase table, write)
                                    └──► .environment() ──► StairwayBottomSheet (climberCountBadge, reportWalk/Unwalk)
                                                        ──► NeighborhoodDetail (neighborhoodTotalClimbers)

NavigationCoordinator (ContentView @State) ──► .environment() ──► MapTab (consumes pendingStairway/pendingNeighborhood)
                                                                ──► SearchTab → sets pendingStairway/pendingNeighborhood → switches to tab 0
```

`StairwayStore` loads stairway data at init and exposes search/filter/region/resolver helpers. The `stairways` computed property filters `_allStairways` against `deletedIDs` (a `Set<String>` updated via `applyDeletions(_:)`); views call `applyDeletions` in `.onAppear` and `.onChange(of: deletions)` to keep the exclusion set current. `WalkRecord`, `StairwayOverride`, `StairwayTag`, `TagAssignment`, and `StairwayDeletion` are independent write paths, all keyed by `stairwayID` (or `tagID`). `AuthManager` manages the Supabase session independently of SwiftData — the two persistence layers coexist without interaction in the current phase.
