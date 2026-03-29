# Project State — sf-stairways

_Last updated: 2026-03-28_

## Platform

### iOS App (sole platform)
- Swift/SwiftUI/iOS 17+ with Map, List, and Progress tabs
- SwiftData + CloudKit — container init with CloudKit configured; falls back to local-only with detailed error logging if CloudKit fails
- `SyncStatusManager` tracks live CloudKit event notifications; cloud icon in Progress tab shows sync state
- Supabase SDK integrated; `AuthManager` manages Sign in with Apple session
- Photo capture with thumbnails, location services, seed data import
- Successfully archived in Xcode on 2026-03-23
- See `docs/IOS_REFERENCE.md` for full build details

### Web App (deprecated)
- `index.html` remains in the repo for historical reference
- No further development — see DECISIONS.md for rationale

## Current Data

| Metric | Value |
|---|---|
| Walked stairways | 8 |
| Saved (un-walked) | 5 |
| With photos | 0 |
| All SF stairways (catalog) | 382 |

## Active Workstreams

### 1. Solo UX — recent completions (2026-03-28)

- **Hard Mode confirmation prompt** — Mark Walked is never disabled; Hard Mode ON + out of range shows confirmation alert ("Mark Anyway" logs with `proximityVerified = false`). Amber `xmark.seal.fill` badge on unverified walks in list rows and detail sheet. Active Walk Mode completion auto-sets `proximityVerified = true`.
- **Stairway Tags v1** — personal tagging system: `StairwayTag` + `TagAssignment` SwiftData models, tag editor sheet on detail view, tag pills in detail + search, map filter button (additive with state filter), preset tags from bundled JSON.
- **Active walk mode** — timer, HealthKit steps/elevation, end/cancel flow
- **Photo suggestions** — suggested photos from walk day; PHAsset dedup, dismiss, add actions
- **Photo camera roll save** — in-app camera captures saved via `PHPhotoLibrary`
- **Photo persistence fix** — local photos visible in carousel; `PhotoSource` enum; `is_public` fix

### Previous completions (2026-03-28)
- Launch zoom to nearest stairway after splash dismisses
- Map pin tap targets 44pt min; zoom-responsive scale 1x–2x
- Curator notes-to-commentary promotion flow wired
- Expandable bottom sheet replaces two-view map flow, deletes `StairwayDetail`

### Previous completions (2026-03-27 and earlier)
- UI overhaul: amber accent, top bar redesign, splash fix, pin colors
- Round 2 bug fixes: circle pins, curator gate, auth error
- Bug Fixes Round 1: map pins, Sign in with Apple code path, Hard Mode toggle
- Curator social layer: photo carousel, curator commentary, photo likes, user-level Hard Mode (Supabase)
- Supabase iOS integration: SDK, AuthManager, Sign in with Apple, SettingsView
- Curator data layer: `StairwayOverride` model, verified stats with badge
- See: `docs/specs/implemented/` for full spec history

### 2. Pending Specs

No specs currently pending. `docs/specs/` is empty.

### 3. App Store — Scaffold multi-user architecture

- Supabase project: create project, run `supabase/schema.sql`, configure Apple provider in Dashboard

## Known Issues

- CloudKit sync may still fall back to local if Xcode target lacks Background Modes → Remote Notifications capability (manual Xcode step — not in repo)
- CKErrorDomain error 2 (not authenticated) surfaces as red error icon on Progress tab — separate from Supabase auth; requires CloudKit investigation
- `supabase-swift` package + new files from curator social layer not yet confirmed added to Xcode target
- Sign in with Apple: `signInError` display is temporary for debugging — remove after auth is confirmed working
- Supabase Apple provider config not yet manually verified (required for Sign in with Apple to work)

## Repository

- `sf-stairways` (Dropbox) is the official project repository
- Xcode project: `ios/SFStairways.xcodeproj` (in repo)
- iOS source: `ios/SFStairways/` (Swift/SwiftUI)
- See `docs/IOS_REFERENCE.md` for build details
