# Project State — sf-stairways

_Last updated: 2026-03-29 (ios-admin-app)_

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
| All SF stairways (catalog) | **1,144** (was 382) |
| Neighborhoods | **61** (53 original + 8 new) |

## Recent Completions

### 2026-03-29 (this session)
- **iOS Admin App** — new iOS target `SFStairwaysAdmin` (bundle: `com.o4dvasq.SFStairways.admin`); shares CloudKit container and all SwiftData models; `AdminBrowser` with search/filter/sort, `AdminDetailView` with editable overrides + tag management + stairway removal, `AdminTagManager` CRUD sheet, `RemovedStairwaysView` for restore flow; `StairwayDeletion` model added to all three targets' ModelContainer schemas; `StairwayStore.applyDeletions()` filters deleted IDs from `stairways` computed property; main iOS app, macOS app, and admin app all respect deletions.
- **HealthKit diagnostics** — added debug logging and 1-second post-walk delay in `HealthKitService.fetchWalkStats` to allow HealthKit time to flush walk data before querying; toast on nil stats result.
- **Visual refresh phase 1** — light mode as default appearance (removed `.preferredColorScheme(.dark)` from Map); warm terracotta `brandOrange` (#D4724E light / #E07A52 dark, adaptive via `UIColor(dynamicProvider:)`); six new adaptive surface/text tokens; progress ring stroke changed to `brandOrange`; SF Pro Rounded on all display numbers, stat card labels, neighborhood headers, search tab pills, and nav bar titles; splash screen background changed to `brandOrange`; stat cards use `surfaceCardElevated` token.

### 2026-03-29 (earlier)
- **Map label cleanup** — `Stairway.displayName` computed property truncates names to first 4 words, stripping trailing `.,;`; labels hidden at `mapSpan > 0.02`; full `name` unchanged everywhere else.
- **UX fixes round 3** — `forestGreen` brightened; notes Save button only; collapsible neighborhood `DisclosureGroup` in Stats; Stats card orange bar with "Stats" label; Search as 4th tab; `NavigationCoordinator` for cross-tab navigation.
- **Attribution & acknowledgements** — "View on Urban Hiker SF Map" link for urban-hiker stairways; iOS Settings Acknowledgements section; macOS `AcknowledgementsSheet`.
- **macOS tag management** — `TagManagerSheet` CRUD; sidebar Tags filter; nil-last table sorting; "Create & Assign…" inline option; iOS tags read-only; macOS app icon.
- **Urban Hiker SF data import** — 762 new stairways imported (1,144 total), 8 new neighborhoods.
- **macOS photo add + notes editing**, **HealthKit data accuracy fix**, **macOS Admin Dashboard**, **Photo sync fix**, **Map launch cleanup**.

### 2026-03-28
- Remove Saved concept, HealthKit walk stats display, camera during active walk, Hard Mode confirmation prompt, Stairway Tags v1, Active walk mode, Photo suggestions, Photo camera roll save, photo persistence fix, Launch zoom to nearest, map pin tap targets, curator notes-to-commentary, expandable bottom sheet.

### 2026-03-27 and earlier
- UI overhaul: amber accent, top bar redesign, splash fix, pin colors
- Curator social layer, Supabase integration, curator data layer
- See: `docs/specs/implemented/` for full spec history

## Pending Specs

- `docs/specs/SPEC_healthkit-stats-and-sync-diagnosis.md`

## Known Issues

- **macOS CloudKit sync:** first launch on Mac requires a few minutes for CloudKit to sync iOS walk data down.
- **HealthKit:** entitlement added to `.entitlements`; HealthKit capability must also be manually enabled in Xcode target Signing & Capabilities.
- **CloudKit sync:** may fall back to local if Xcode target lacks Background Modes → Remote Notifications capability (manual Xcode step).
- **CKErrorDomain error 2** (not authenticated) surfaces as red error icon on Stats tab — requires CloudKit investigation.
- **supabase-swift** package not confirmed added to Xcode target membership.
- **Sign in with Apple:** `signInError` display is temporary for debugging.
- **Supabase Apple provider** config not yet manually verified.
- **Stairway count in iOS app** may still show 382 — `all_stairways.json` bundle resource needs to be re-bundled into the Xcode build for the expanded 1,144-entry dataset to appear on device.
- **Admin app Xcode target**: file memberships and capabilities must be manually verified in Xcode after pulling — the target config is in `project.pbxproj` but CloudKit + Background Modes capabilities require Signing & Capabilities UI.

## Repository

- sf-stairways (Dropbox) is the official project repository
- Xcode project: `ios/SFStairways.xcodeproj` (in repo)
- iOS source: `ios/SFStairways/` (Swift/SwiftUI)
- macOS source: `ios/SFStairwaysMac/` (Swift/SwiftUI, macOS)
- iOS Admin source: `ios/SFStairwaysAdmin/` (Swift/SwiftUI, iOS utility)
- See `docs/IOS_REFERENCE.md` for build details
