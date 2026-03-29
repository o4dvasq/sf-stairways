# Project State — sf-stairways

_Last updated: 2026-03-29_

## Platforms

### iOS App (primary)
- Swift/SwiftUI/iOS 17+ with Map, List, and **Stats** tabs
- SwiftData + CloudKit — container init with CloudKit configured; falls back to local-only with detailed error logging if CloudKit fails
- `SyncStatusManager` tracks live CloudKit event notifications; cloud icon in Stats tab shows sync state
- Supabase SDK integrated; `AuthManager` manages Sign in with Apple session
- Photo capture with thumbnails, location services, seed data import
- Successfully archived in Xcode on 2026-03-23
- See `docs/IOS_REFERENCE.md` for full build details

### macOS Admin Dashboard
- **`ios/SFStairwaysMac/`** — macOS target in `SFStairways.xcodeproj`, bundle ID `com.o4dvasq.SFStairways.mac`
- Shares the same CloudKit container (`iCloud.com.o4dvasq.sfstairways`) as iOS — all walk data, overrides, tags sync automatically
- Shares SwiftData model files with iOS (same `Models/*.swift`)
- Three-column `NavigationSplitView`: neighborhood sidebar → sortable stairway table → detail panel
- Detail panel: catalog vs. walk data comparison, editable curator overrides, notes → promote, tag add/remove, local photo grid with delete
- Data Hygiene sheet: flags missing height, missing coordinates, no HealthKit data, promotion candidates, proximity unverified
- Bulk Operations sheet: bulk tag assign, bulk mark walked (with date picker), CSV export via NSSavePanel
- No Supabase, no HealthKit fetching on macOS (displays synced walk data only)

### Web App (deprecated)
- `index.html` remains in the repo for historical reference
- No further development — see DECISIONS.md for rationale

## Current Data

| Metric | Value |
|---|---|
| Walked stairways | 8 |
| With photos | 0 |
| All SF stairways (catalog) | 382 |

## Recent Completions

### 2026-03-29
- **HealthKit data accuracy fix** — removed retroactive full-day HealthKit pull (inaccurate per-stairway data); `statsRow` now only shows stepCount/elevationGain when `walkStartTime != nil` (active walks only); one-time migration clears bad full-day step counts from manually logged walks.
- **macOS Admin Dashboard** — new macOS target with three-column browser, detail panel (curator edits, tag mgmt, photo grid), data hygiene dashboard, bulk operations + CSV export. `WalkPhoto.swift` made cross-platform. `SupabaseModels.swift` guarded with `#if !os(macOS)`.
- **Photo sync fix** — photo upload logging, auth check, failed vs pending badge.
- **Map launch cleanup** — removed auto-zoom-to-nearest on launch; HealthKit entitlement added; ProgressCard header changed to amber accent bar.

### 2026-03-28
- **Remove Saved concept + layout tweaks** — two-state model; search bottom-right; settings leading; Progress tab renamed Stats; one-time migration.
- **HealthKit walk stats display** — walk method badge, retroactive pull flow (now removed), HealthKit auth in Settings.
- **Camera during active walk** — camera button in activeSessionBanner; WalkRecord created on walk start.
- **Hard Mode confirmation prompt** — amber badge for unverified walks; confirmation alert flow.
- **Stairway Tags v1** — StairwayTag + TagAssignment models, tag editor, map filter, preset tags.
- **Active walk mode** — timer, HealthKit steps/elevation, end/cancel flow.
- **Photo suggestions** — PHAsset dedup, dismiss, add from walk day.
- **Photo camera roll save** and **photo persistence fix** (PhotoSource enum, is_public fix).
- Launch zoom to nearest, map pin tap targets, curator notes-to-commentary, expandable bottom sheet.

### 2026-03-27 and earlier
- UI overhaul: amber accent, top bar redesign, splash fix, pin colors
- Curator social layer, Supabase integration, curator data layer
- See: `docs/specs/implemented/` for full spec history

## Pending Specs

- `SPEC_macos-photo-add.md`

## Known Issues

- **macOS CloudKit sync:** first launch on Mac requires a few minutes for CloudKit to sync iOS walk data down. Leave both apps open; data appears automatically once sync completes.
- **HealthKit:** entitlement added to `.entitlements`; HealthKit capability must also be manually enabled in Xcode target Signing & Capabilities (links HealthKit.framework).
- **CloudKit sync:** may still fall back to local if Xcode target lacks Background Modes → Remote Notifications capability (manual Xcode step — not in repo).
- **CKErrorDomain error 2** (not authenticated) surfaces as red error icon on Stats tab — separate from Supabase auth; requires CloudKit investigation.
- **supabase-swift** package + new files from curator social layer not yet confirmed added to Xcode target.
- **Sign in with Apple:** `signInError` display is temporary for debugging — remove after auth is confirmed working.
- **Supabase Apple provider** config not yet manually verified (required for Sign in with Apple to work).

## Repository

- sf-stairways (Dropbox) is the official project repository
- Xcode project: `ios/SFStairways.xcodeproj` (in repo)
- iOS source: `ios/SFStairways/` (Swift/SwiftUI)
- macOS source: `ios/SFStairwaysMac/` (Swift/SwiftUI, macOS)
- See `docs/IOS_REFERENCE.md` for build details
