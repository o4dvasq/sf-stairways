# Project State — sf-stairways

_Last updated: 2026-03-27_

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

### 1. Solo UX — Bug Fixes Round 2 (just completed 2026-03-27)

Three bugs found during on-device testing (post-round-1):

**Bug A — Map pins still rendering poorly.** Abandoned teardrop shape entirely. Switched to `Circle()` — state-based colors (gray/orange/green) and sizes (12/16/24pt selected). Selected state uses darker color variant.

**Bug B — Curator section visible to all users on walked stairways.** The "Stairway Info" editor (stair count, height, description TextFields) was gated only on `isWalked`, not on curator role. All users saw "Add stair count" / "Add height" / "Add description..." prompts. Fixed: gated on `isWalked && authManager.isCurator && curatorModeActive`.

**Bug C — Sign in with Apple still failing.** Code path confirmed correct from round 1. Added visible error feedback: `signInError: String?` on `AuthManager`, surfaced in `SettingsView` below the sign-in button. Supabase dashboard config must be manually verified (Apple provider enabled, Service ID = `com.o4dvasq.SFStairways`).

### Previous completions
- Bug Fixes Round 1: map pins, Sign in with Apple code path, Hard Mode toggle
- Curator social layer: photo carousel, curator commentary, photo likes, user-level Hard Mode (Supabase)
- Supabase iOS integration: SDK, AuthManager, Sign in with Apple, SettingsView
- Curator data layer: `StairwayOverride` model, verified stats with badge
- UI Improvements v2: slimmer nav bar, icon-free pins, ProgressCard width fix, detail mini-map, Save button
- Hard Mode: per-stairway proximity-gated walk verification with unverified badge
- See: `docs/specs/implemented/` for full spec history

### 2. App Store — Scaffold multi-user architecture

- Supabase project: create project, run `supabase/schema.sql`, configure Apple provider in Dashboard
- No pending specs in `docs/specs/`

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
