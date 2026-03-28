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

### 1. Solo UX — Bug Fixes (just completed 2026-03-27)

Three bugs found during on-device testing:

**Bug A — Map pins** were rendering as tiny hollow/chevron shapes. Fixed:
- Removed white shadow (was creating hollow appearance on dark map)
- Added thin dark stroke overlay for defined edge
- Increased pin sizes: unsaved 36×45, saved/walked 40×50, selected 48×60

**Bug B — Sign in with Apple** was completing OS auth but never updating app state. Root cause: `SettingsView` discarded the credential from `SignInWithAppleButton`'s `onCompletion` and launched a second `ASAuthorizationController`. Fixed:
- `onCompletion` now passes the `ASAuthorization` directly to `AuthManager.handleAppleAuthorization(_:)`
- New method extracts identity token and calls `signInWithIdToken` — no second controller

**Bug C — Hard Mode toggle** was permanently disabled. Resolved automatically by Bug B fix.

### Previous completions
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
- CKErrorDomain error 2 (not authenticated) surfaces as red error icon on Progress tab — separate from Supabase auth; requires CloudKit investigation (see note in SPEC_bugfix-pins-auth-hardmode.md)
- `supabase-swift` package + new files from curator social layer not yet confirmed added to Xcode target

## Repository

- `sf-stairways` (Dropbox) is the official project repository
- Xcode project: `ios/SFStairways.xcodeproj` (in repo)
- iOS source: `ios/SFStairways/` (Swift/SwiftUI)
- See `docs/IOS_REFERENCE.md` for build details
