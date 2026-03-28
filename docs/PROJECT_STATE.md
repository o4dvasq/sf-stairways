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

### 1. Solo UX — Map Pin UX (just completed 2026-03-28)

Improved map pin tap targets and zoom-responsive sizing:

- **Expanded tap targets:** `StairwayPin` now wraps the visual circle in a transparent `max(44, pinSize)` frame with `.contentShape(Rectangle())`. Tap target is at least 44pt regardless of visual size (Apple HIG minimum), larger at street-level zoom.
- **Zoom-responsive pin scaling:** `MapTab` tracks `mapSpan` via `.onMapCameraChange(frequency: .continuous)`. A `pinScale` computed property lerps from 1.0 (city view, `latitudeDelta >= 0.05`) to 2.0 (street level, `latitudeDelta <= 0.005`). Scale is passed through `StairwayAnnotation` → `StairwayPin` and applied to all base pin sizes.
- **No visual regressions:** dimming, closed-state opacity, selected state, and unverified badge logic untouched.

### Previous completions (2026-03-28)
- Curator notes-to-commentary promotion flow wired (pre-fill editor, scroll, binding)
- Expandable bottom sheet replaces two-view map flow, deletes `StairwayDetail`; `ListTab` updated to use same sheet; `MapTab` simplified

### Previous completions (2026-03-27 and earlier)
- UI overhaul: amber accent, top bar redesign, splash fix, pin colors
- Round 2 bug fixes: circle pins, curator gate, auth error
- Bug Fixes Round 1: map pins, Sign in with Apple code path, Hard Mode toggle
- Curator social layer: photo carousel, curator commentary, photo likes, user-level Hard Mode (Supabase)
- Supabase iOS integration: SDK, AuthManager, Sign in with Apple, SettingsView
- Curator data layer: `StairwayOverride` model, verified stats with badge
- UI Improvements v2: slimmer nav bar, icon-free pins, ProgressCard width fix, detail mini-map, Save button
- Hard Mode: per-stairway proximity-gated walk verification with unverified badge
- See: `docs/specs/implemented/` for full spec history

### 2. Pending Specs (ready for Claude Code)

Two specs in `docs/specs/` awaiting implementation:

- **SPEC_photo-persistence-fix.md** — Photos added during walks don't appear in UI. Two bugs: (1) carousel only reads Supabase, ignores local SwiftData photos; (2) `PhotoInsert` doesn't set `is_public = true` so even uploaded photos are filtered out.
- **SPEC_launch-zoom-nearest.md** — On launch, auto-zoom to nearest stairway after location fix arrives. Falls back to city-wide default if no permission.

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
