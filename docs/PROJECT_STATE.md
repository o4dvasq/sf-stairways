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

### 1. Solo UX — Expandable Bottom Sheet (just completed 2026-03-28)

Replaced the two-view map flow (bottom sheet → NavigationLink → StairwayDetail) with a single expandable bottom sheet.

- **Collapsed state (.height(390)):** header (name, neighborhood, camera menu), stats row, walk status card (Mark as Walked / walked date + edit), action buttons (Save/Unsave/Mark Walked/Unmark/Remove)
- **Expanded state (.large):** curator commentary, notes (Add/Edit/Save/Cancel), Supabase photo carousel, curator editor, curator data section (StairwayOverride fields), source link
- `StairwayBottomSheet` is now fully self-contained: `@Query` for live data, `@Environment(\.dismiss)` for self-dismissal on remove, all walk record actions handled internally
- `StairwayDetail.swift` deleted — no longer referenced anywhere
- `MapTab` simplified: no callback parameters, no action functions, no `AuthManager` environment
- `ListTab` updated: NavigationLink replaced with Button + `.sheet(item:)` using the same `StairwayBottomSheet`
- Map remains interactive at the collapsed detent via `.presentationBackgroundInteraction(.enabled(upThrough: .height(390)))`

### Previous completions
- UI overhaul: amber accent, top bar redesign, splash fix, pin colors
- Round 2 bug fixes: circle pins, curator gate, auth error
- Bug Fixes Round 1: map pins, Sign in with Apple code path, Hard Mode toggle
- Curator social layer: photo carousel, curator commentary, photo likes, user-level Hard Mode (Supabase)
- Supabase iOS integration: SDK, AuthManager, Sign in with Apple, SettingsView
- Curator data layer: `StairwayOverride` model, verified stats with badge
- UI Improvements v2: slimmer nav bar, icon-free pins, ProgressCard width fix, detail mini-map, Save button
- Hard Mode: per-stairway proximity-gated walk verification with unverified badge
- See: `docs/specs/implemented/` for full spec history

### 2. App Store — Scaffold multi-user architecture

- Supabase project: create project, run `supabase/schema.sql`, configure Apple provider in Dashboard
- No pending specs in `docs/specs/` except `SPEC_curator-notes-to-commentary.md`

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
