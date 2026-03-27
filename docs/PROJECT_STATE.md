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

### 1. Solo UX — Supabase Auth (just completed)

`supabase-swift` SDK integrated. New files:

- **`SupabaseManager`** — singleton; reads `Config/Supabase.plist` (gitignored) for project URL + anon key; crashes with clear message if plist missing
- **`AuthManager`** — `@Observable`; restores session from Keychain on init; subscribes to auth state changes; handles Sign in with Apple via `ASAuthorizationController` → Supabase `signInWithIdToken`; exposes `signOut()`
- **`SettingsView`** — presented as a sheet from a gear icon in the ProgressTab toolbar; Account section shows sign-in state (signed-in email + Sign Out, or Sign in with Apple button); iCloud section shows sync status

Sign in with Apple entitlement added to `SFStairways.entitlements`. `AuthManager` injected via `.environment()` in `SFStairwaysApp`.

**Pending manual Xcode steps (must be done before building):**
1. File → Add Package Dependencies → `https://github.com/supabase/supabase-swift` → `Supabase` product ≥ 2.0.0
2. Add new Swift files to target: `SupabaseManager.swift`, `AuthManager.swift`, `SettingsView.swift`
3. Add `Config/Supabase.plist` to Copy Bundle Resources
4. Target → Signing & Capabilities → + Sign in with Apple
5. Fill in real credentials in `Config/Supabase.plist`

### Previous completions
- Curator data layer: `StairwayOverride` model, verified stats with badge
- UI Improvements v2: slimmer nav bar, icon-free pins, ProgressCard width fix, detail mini-map, Save button
- Hard Mode: per-stairway proximity-gated walk verification with unverified badge
- Nav Bar Redesign + Progress Card Header: `brandOrange` top bar, progress card header bar
- Pin Visibility Fix: custom StairShape, 2x pin sizes, full-opacity unsaved
- Map Visual Refresh v2: amber pins, dark map, top bar, unified stair icon
- See: `docs/specs/implemented/` for full spec history

### 2. App Store — Scaffold multi-user architecture

- Supabase project: create project, run `supabase/schema.sql`, configure Apple provider in Dashboard
- `SPEC_curator-social-layer.md` — photo carousel, photo likes, curator commentary, hard mode as app-level setting (pending)

## Known Issues

- CloudKit sync may still fall back to local if Xcode target lacks Background Modes → Remote Notifications capability (manual Xcode step — not in repo)
- CKErrorDomain error 2 (not authenticated) surfaces as red error icon on Progress tab
- `supabase-swift` package + new files not yet added to Xcode target (required manual step)

## Repository

- `sf-stairways` (Dropbox) is the official project repository
- Xcode project: `ios/SFStairways.xcodeproj` (in repo)
- iOS source: `ios/SFStairways/` (Swift/SwiftUI)
- See `docs/IOS_REFERENCE.md` for build details
