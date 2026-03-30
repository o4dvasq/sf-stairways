# Project State — sf-stairways

_Last updated: 2026-03-29 (progress-reframe + ux-fixes-round4)_

## Platforms

### iOS App (primary)
- Swift/SwiftUI/iOS 17+ with Map, List, Stats, and **Search** tabs
- SwiftData + CloudKit — container init with CloudKit configured; falls back to local-only with detailed error logging if CloudKit fails
- `SyncStatusManager` tracks live CloudKit event notifications; cloud icon in Stats tab shows sync state
- Supabase SDK integrated; `AuthManager` manages Sign in with Apple session
- Photo capture with thumbnails, location services, seed data import
- Tags are **read-only** on iOS (display + filter only) — all tag CRUD is macOS-only; `TagEditorSheet` removed
- `StairwayStore` filters out deleted stairways via `applyDeletions(_:)` — map, list, search, progress all respect deletions
- **Visual design: light-first** — warm terracotta `brandOrange`, SF Pro Rounded for display text, `surfaceCardElevated` stat cards, orange progress ring
- **Neighborhoods: SF 311 Neighborhoods** — 117 granular neighborhoods (as defined by Mayor's Office of Neighborhood Services, 2006), 68 with stairways; powered by `NeighborhoodStore` (GeoJSON-backed, computes centroids + adjacency at startup); property key `name`
- Successfully archived in Xcode on 2026-03-23
- See `docs/IOS_REFERENCE.md` for full build details

### iOS Admin App (`SFStairwaysAdmin`)
- **`ios/SFStairwaysAdmin/`** — separate iOS target in `SFStairways.xcodeproj`, bundle ID `com.o4dvasq.SFStairways.admin`
- Shares the same CloudKit container (`iCloud.com.o4dvasq.sfstairways`) — all override, tag, and deletion changes sync automatically
- Shares SwiftData model files with both iOS and macOS targets
- **No map, no photo management, no HealthKit, no Supabase** — utility-only tool
- `AdminBrowser` — searchable list of all stairways; filter chips (All/Walked/Unwalked/Has Override/Has Issues); sort by Name/Neighborhood/Date Walked; row indicators for walked status, override, tag count; toolbar: Tag Manager + Removed Stairways buttons
- `AdminDetailView` — push-navigation detail: catalog data (read-only), walk data (read-only), editable overrides (step count, height, description) with Save/Cancel, tag chips with add/remove, "Remove Stairway" destructive action with reason field
- `AdminTagManager` — modal sheet: preset tags read-only with counts, custom tags with inline rename and delete (cascade confirmation), create new tag
- `RemovedStairwaysView` — modal sheet: list of `StairwayDeletion` records with name/date/reason; swipe to restore

### macOS Admin Dashboard
- **`ios/SFStairwaysMac/`** — macOS target in `SFStairways.xcodeproj`, bundle ID `com.o4dvasq.SFStairways.mac`
- Shares the same CloudKit container as iOS — all walk data, overrides, tags, deletions sync automatically
- Shares SwiftData model files with iOS (same `Models/*.swift`)
- Three-column `NavigationSplitView`: sidebar (neighborhoods + tags filter) → sortable stairway table → detail panel
- **Deletion filtering**: `StairwayBrowser` queries `StairwayDeletion` records and excludes matching stairways from the table
- **Sidebar Tags section**: lists tags with assignment counts; clicking a tag filters table; intersects with neighborhood filter
- **Table sorting**: all numeric columns sortable with nil-last logic via `nilLastSorted` helper
- **TagManagerSheet**: full tag CRUD — create custom tags, inline rename, delete with cascade confirmation, preset tags read-only
- Detail panel: catalog vs. walk data comparison, editable curator overrides, notes editing, tag add/remove + "Create & Assign…" option, photo grid with delete + Add Photos
- Bulk Operations: bulk tag assign + "Create new tag…" + "Remove Tag from All Selected," bulk mark walked, CSV export
- Data Hygiene sheet: flags missing height, missing coordinates, no HealthKit data, promotion candidates, proximity unverified
- **App icon**: white StairShape silhouette on brandOrange background
- **Acknowledgements**: `info.circle` toolbar button opens `AcknowledgementsSheet`
- No Supabase, no HealthKit fetching on macOS (displays synced walk data only)

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

### 2026-03-29 (this session)
- **Progress Tab Reframe** — Full rewrite of `ProgressTab`. Compact ring (~80pt, `brandOrange`) in HStack alongside text block (walked/total, %+height ft, neighborhood count). Hero content is a 2-column `LazyVGrid` of `NeighborhoodCard` components (name, walked/total fraction, mini progress bar) for neighborhoods with ≥1 walk, sorted by completion % descending (tie-break: most recent walk). Collapsible "Undiscovered" section (`@AppStorage("progress.undiscovered.collapsed")`, default collapsed) lists all neighborhoods with 0 walks but stairways in catalog; each name is a `NavigationLink(value:)` → `NeighborhoodDetail`. Old `StatCard` grid and `DisclosureGroup` neighborhood breakdown removed. `StatCard` struct deleted. `NeighborhoodCard.swift` created in `Views/Progress/`.
- **UX Fixes Round 4** — (A) HealthKit: checks `isAuthorized()` before re-requesting auth; logs error when auth throws; 2s post-walk delay (was 1s); retry once after 2s if both results nil; `fetchWalkStats` return type now includes `error: String?` with specific messages ("Health access denied…" vs "No step data recorded…"); `endWalkSession` toast shows specific error string. (B) Redundant mark-walked button: removed large "Mark as Walked" from `walkStatusCard` unwalked state (replaced with "Not yet walked" label); walked banner left-side is now tappable → "Mark as Not Walked?" confirmation alert (destructive Remove action) → calls `removeRecord()`; "Not Walked" `ActionButton` removed from walked state. (C) Photo badges: cloud badge hidden when `userId == nil`; only shows red `icloud.slash` for per-photo upload failures when signed in. (D) CloudKit error message: SwiftDataError code 1 maps to human-readable text about schema deployment.

### 2026-03-29 (earlier this session)
- **Neighborhood Map Overlays + Detail View** — `MapPolygon` overlays for all 117 neighborhoods with warm-toned pastel fills; centroid label annotations visible at mapSpan < 0.04 degrees; Around Me dimming applied to polygon opacity; label tap → `NeighborhoodDetail` sheet; `NeighborhoodDetail` view: progress bar, embedded 200pt map, horizontal photo scroll, stairway list; 4 navigation entry points: map label, ListTab section header, SearchPanel neighborhood tab, StairwayBottomSheet neighborhood name. `Views/Neighborhood/NeighborhoodDetail.swift` created.
- **Neighborhood 311 Migration** — Replaced DataSF Analysis Neighborhoods GeoJSON (41 hoods) with SF 311 Neighborhoods dataset (117 hoods); `NeighborhoodStore` updated to read `name` property; color palette expanded 8→12 colors; `all_stairways.json` re-migrated (367 PIP, 15 manual, 0 centroid fallbacks).
- **Neighborhood Foundation** — `Neighborhood` struct + `NeighborhoodStore` (`@Observable`); GeoJSON-backed centroids and adjacency; `SFStairwaysApp` initializes and injects `NeighborhoodStore`; `all_stairways.json` migrated from 53 scraped names → 41 DataSF names; `neighborhood_centroids.json` and `neighborhood_adjacency.json` deleted.

### 2026-03-29 (earlier sessions)
- **iOS Admin App**, **HealthKit diagnostics**, **Visual refresh phase 1**, **Map label cleanup**, **UX fixes round 3**, **Attribution & acknowledgements**, **macOS tag management**, **Urban Hiker SF data import**, **macOS photo add + notes editing**, **HealthKit data accuracy fix**, **macOS Admin Dashboard**, **Photo sync fix**, **Map launch cleanup**.

### 2026-03-28
- Remove Saved concept, HealthKit walk stats display, camera during active walk, Hard Mode confirmation prompt, Stairway Tags v1, Active walk mode, Photo suggestions, Photo camera roll save, photo persistence fix, Launch zoom to nearest, map pin tap targets, curator notes-to-commentary, expandable bottom sheet.

### 2026-03-27 and earlier
- UI overhaul: amber accent, top bar redesign, splash fix, pin colors
- Curator social layer, Supabase integration, curator data layer
- See: `docs/specs/implemented/` for full spec history

## Pending Specs

- `docs/specs/SPEC_neighborhood-311-migration.md` (implemented but spec file not yet moved)
- `docs/specs/SPEC_neighborhood-map-and-detail.md` (implemented but spec file not yet moved)

## Known Issues

- **CloudKit schema:** SwiftDataError code 1 on first launch after new model types added means CloudKit schema needs deploying from Xcode to Dashboard (container: `iCloud.com.o4dvasq.sfstairways`). Error now shows a human-readable message in Settings.
- **macOS CloudKit sync:** first launch on Mac requires a few minutes for CloudKit to sync iOS walk data down.
- **HealthKit:** entitlement added to `.entitlements`; HealthKit capability must also be manually enabled in Xcode target Signing & Capabilities.
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
