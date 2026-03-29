# Project State — sf-stairways

_Last updated: 2026-03-29_

## Platform

### iOS App (sole platform)
- Swift/SwiftUI/iOS 17+ with Map, List, and **Progress** tabs
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
| With photos | 0 |
| All SF stairways (catalog) | 382 |

## Active Workstreams

### 1. Solo UX — recent completions (2026-03-29)

- **Map UI fixes + bottom sheet cleanup** — floating ProgressCard now labeled "Stats"; tab bar third tab and navigation title now "Progress"; search button moved to standalone floating circle at bottom-right (tab-bar level); bottom sheet hides HealthKit status text, photo count, and walk method text from end users; walkStatusCard shows only "Walked" + date + edit pencil.
- **Photo sync fix** — photo upload logging, auth check, failed vs pending badge. (see SPEC_photo-sync-fix.md)
- **Map launch cleanup** — removed auto-zoom-to-nearest on launch (map stays at city view); HealthKit entitlement added.

### Previous completions (2026-03-28)
- **Remove Saved concept + layout tweaks** — two-state model; search bottom-right; settings leading; Progress tab renamed Stats; one-time migration.
- **HealthKit walk stats display** — walk method badge, diagnostic in stats row, retroactive pull flow, HealthKit auth in Settings.
- **Camera during active walk** — camera button in activeSessionBanner; WalkRecord created on walk start.
- **Hard Mode confirmation prompt** — amber badge for unverified walks; confirmation alert flow.
- **Stairway Tags v1** — StairwayTag + TagAssignment models, tag editor, map filter, preset tags.
- **Active walk mode** — timer, HealthKit steps/elevation, end/cancel flow.
- **Photo suggestions** — PHAsset dedup, dismiss, add from walk day.
- **Photo camera roll save** and **photo persistence fix** (PhotoSource enum, is_public fix).
- Launch zoom to nearest, map pin tap targets, curator notes-to-commentary, expandable bottom sheet.

### Previous completions (2026-03-27 and earlier)
- UI overhaul: amber accent, top bar redesign, splash fix, pin colors
- Curator social layer, Supabase integration, curator data layer
- See: docs/specs/implemented/ for full spec history

### 2. Pending Specs

- `SPEC_admin-dashboard-design.md`

### 3. App Store — Scaffold multi-user architecture

- Supabase project: create project, run supabase/schema.sql, configure Apple provider in Dashboard

## Known Issues

- HealthKit: entitlement added to .entitlements file; HealthKit capability must also be manually enabled in Xcode target Signing & Capabilities (links HealthKit.framework)
- CloudKit sync may still fall back to local if Xcode target lacks Background Modes → Remote Notifications capability (manual Xcode step — not in repo)
- CKErrorDomain error 2 (not authenticated) surfaces as red error icon on Progress tab — separate from Supabase auth; requires CloudKit investigation
- supabase-swift package + new files from curator social layer not yet confirmed added to Xcode target
- Sign in with Apple: signInError display is temporary for debugging — remove after auth is confirmed working
- Supabase Apple provider config not yet manually verified (required for Sign in with Apple to work)

## Repository

- sf-stairways (Dropbox) is the official project repository
- Xcode project: ios/SFStairways.xcodeproj (in repo)
- iOS source: ios/SFStairways/ (Swift/SwiftUI)
- See docs/IOS_REFERENCE.md for build details
