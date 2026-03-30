# Project State — sf-stairways

_Last updated: 2026-03-30 (neighborhood-color-saturation)_

## Platforms

### iOS App (primary)
- Swift/SwiftUI/iOS 17+ with Map, List, Stats, and **Search** tabs
- SwiftData + CloudKit — container init with CloudKit configured; falls back to local-only with detailed error logging if CloudKit fails
- `SyncStatusManager` tracks live CloudKit event notifications; cloud icon in Stats tab shows sync state
- Supabase SDK integrated; `AuthManager` manages Sign in with Apple session
- Photo capture with thumbnails, location services, seed data import
- Tags are **read-only** on iOS (display + filter only) — all tag CRUD is macOS-only
- `StairwayStore` filters out deleted stairways via `applyDeletions(_:)` — map, list, search, progress all respect deletions
- **Visual design: light-first** — warm terracotta `brandOrange`, SF Pro Rounded for display text, `surfaceCardElevated` stat cards, orange progress ring
- **Neighborhoods: SF 311 Neighborhoods** — 117 granular neighborhoods (68 with stairways); powered by `NeighborhoodStore` (GeoJSON-backed, computes centroids + adjacency at startup)
- **No HealthKit, no active walk recording** — "Mark Walked" is the only walk-logging action
- Successfully archived in Xcode on 2026-03-23
- See `docs/IOS_REFERENCE.md` for full build details

### iOS Admin App (`SFStairwaysAdmin`)
- **`ios/SFStairwaysAdmin/`** — separate iOS target in `SFStairways.xcodeproj`, bundle ID `com.o4dvasq.SFStairways.admin`
- Shares the same CloudKit container (`iCloud.com.o4dvasq.sfstairways`) — all override, tag, and deletion changes sync automatically
- Shares SwiftData model files with both iOS and macOS targets
- **No map, no photo management, no HealthKit, no Supabase** — utility-only tool
- `AdminBrowser` — searchable list of all stairways; filter chips (All/Walked/Unwalked/Has Override/Has Issues); sort by Name/Neighborhood/Date Walked; row indicators for walked status, override, tag count; toolbar: Tag Manager + Removed Stairways buttons
- `AdminDetailView` — push-navigation detail: catalog data (read-only), editable overrides (step count, height, description) with Save/Cancel, tag chips with add/remove, "Remove Stairway" destructive action
- `AdminTagManager` — modal sheet: preset tags read-only with counts, custom tags with inline rename and delete (cascade confirmation), create new tag
- `RemovedStairwaysView` — modal sheet: list of `StairwayDeletion` records with name/date/reason; swipe to restore

### macOS Admin Dashboard
- **`ios/SFStairwaysMac/`** — macOS target in `SFStairways.xcodeproj`, bundle ID `com.o4dvasq.SFStairways.mac`
- Shares the same CloudKit container as iOS — all walk data, overrides, tags, deletions sync automatically
- Shares SwiftData model files with iOS (same `Models/*.swift`)
- Three-column `NavigationSplitView`: sidebar (neighborhoods + tags filter) → sortable stairway table → detail panel
- **Deletion filtering**: `StairwayBrowser` queries `StairwayDeletion` records and excludes matching stairways from the table
- **Sidebar Tags section**: lists tags with assignment counts; clicking a tag filters table; intersects with neighborhood filter
- **Table sorting**: Name, Height, Steps, Photos, Date Walked (nil values sort to bottom via `nilLastSorted`)
- **TagManagerSheet**: full tag CRUD — create custom tags, inline rename, delete with cascade confirmation, preset tags read-only
- Detail panel: catalog vs. walk data comparison (labeled "Walk Data (legacy)"), editable curator overrides, notes editing, tag add/remove, photo grid with delete + Add Photos
- Bulk Operations: bulk tag assign/remove, bulk mark walked, CSV export (name, neighborhood, height, walked, date walked)
- Data Hygiene sheet: flags missing height, missing coordinates, promotion candidates, proximity unverified
- **App icon**: white StairShape silhouette on brandOrange background
- **Acknowledgements**: `info.circle` toolbar button opens `AcknowledgementsSheet`
- No Supabase, no HealthKit on macOS

### Web App (deprecated)
- `index.html` remains in the repo for historical reference
- No further development — see DECISIONS.md for rationale

## Current Data

| Metric | Value |
|---|---|
| Walked stairways | 8 |
| With photos | 0 |
| All SF stairways (catalog) | **382** |
| SF 311 Neighborhoods | **117** total, **68** with stairways |

## Recent Completions

### 2026-03-30 (this session)
- **Neighborhood Color Saturation** — Increased polygon overlay opacity (fill 0.17→0.30 light / 0.11→0.20 dark; stroke 0.30→0.50 / 0.22→0.40; dimmed 0.03→0.05 fill / 0.05→0.10 stroke). Replaced the 12-color pastel palette in `NeighborhoodStore` with more saturated equivalents (same hue families, reduced high channels for contrast). Bumped `NeighborhoodDetail` polygon to fill 0.30 / stroke 0.60 to match new baseline.
- **Remove HealthKit & Walk Recording** — Deleted `HealthKitService.swift` and `ActiveWalkManager.swift` entirely. Removed "Start Walk" / active session banner / "End Walk" / "Cancel" UI from `StairwayBottomSheet`. "Mark Walked" is now the only walk-logging action. Removed HealthKit authorization section from `SettingsView`. Removed `com.apple.developer.healthkit` from both `.entitlements` files. Removed `walkMethod` computed property from `WalkRecord`. Removed `cleanRetroactiveStatsIfNeeded()` from `SeedDataService`. Removed `walkStartTime`/`walkEndTime` params from `PhotoSuggestionService.fetch` (falls back to full-day window). Removed `missingHealthKit` issue category from `DataHygieneView`. Relabeled Mac detail panel "Walk Data" column to "Walk Data (legacy)"; removed Walk Method row. Removed Elev. Gain column from `StairwayBrowser` table. Removed elevation/steps from CSV export. Removed Walk Data section from `AdminDetailView`. WalkRecord fields (`stepCount`, `elevationGain`, `walkStartTime`, `walkEndTime`) retained in schema to avoid CloudKit migration issues — existing data preserved, just no longer displayed or populated.

### 2026-03-29
- **Progress Tab Reframe** — Compact ring + 2-column `NeighborhoodCard` grid in `ProgressTab`; collapsible "Undiscovered" section. `StatCard` removed. `NeighborhoodCard.swift` created in `Views/Progress/`.
- **UX Fixes Round 4** — HealthKit retry/error improvements, no-duplicate mark button, photo badges, iCloud error messages (all HealthKit-related improvements now superseded by removal).
- **Neighborhood Map Overlays + Detail View** — `MapPolygon` overlays for 117 neighborhoods; centroid label annotations; `NeighborhoodDetail` view with 4 navigation entry points.
- **Neighborhood 311 Migration** — Replaced DataSF GeoJSON with SF 311 Neighborhoods (117 hoods); re-migrated 382 stairways.
- **Neighborhood Foundation** — `NeighborhoodStore`, GeoJSON-backed centroids and adjacency; migrated 53→41→117 neighborhoods.

### Earlier sessions
- **iOS Admin App**, **Visual refresh**, **Map label cleanup**, **UX fixes**, **Attribution & acknowledgements**, **macOS tag management**, **Urban Hiker SF data import**, **macOS photo add + notes editing**, **macOS Admin Dashboard**, **Photo sync**, **Active walk mode** (now removed), **HealthKit integration** (now removed).

## Known Issues

- **CloudKit schema:** SwiftDataError code 1 on first launch after new model types added means CloudKit schema needs deploying from Xcode to Dashboard (container: `iCloud.com.o4dvasq.sfstairways`). Error now shows a human-readable message in Settings.
- **macOS CloudKit sync:** first launch on Mac requires a few minutes for CloudKit to sync iOS walk data down.
- **CloudKit sync:** may fall back to local if Xcode target lacks Background Modes → Remote Notifications capability (manual Xcode step).
- **CKErrorDomain error 2** (not authenticated) surfaces as red error icon on Stats tab — requires CloudKit investigation.
- **supabase-swift** package not confirmed added to Xcode target membership.
- **Sign in with Apple:** `signInError` display is temporary for debugging.
- **Supabase Apple provider** config not yet manually verified.
- **Admin app Xcode target**: file memberships and capabilities must be manually verified in Xcode after pulling — the target config is in `project.pbxproj` but CloudKit + Background Modes capabilities require Signing & Capabilities UI.

## Repository

- sf-stairways (Dropbox) is the official project repository
- Xcode project: `ios/SFStairways.xcodeproj` (in repo)
- iOS source: `ios/SFStairways/` (Swift/SwiftUI)
- macOS source: `ios/SFStairwaysMac/` (Swift/SwiftUI, macOS)
- iOS Admin source: `ios/SFStairwaysAdmin/` (Swift/SwiftUI, iOS utility)
- See `docs/IOS_REFERENCE.md` for build details
