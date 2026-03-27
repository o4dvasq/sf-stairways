# Project State — sf-stairways

_Last updated: 2026-03-26_

## Platform

### iOS App (sole platform)
- Swift/SwiftUI/iOS 17+ with Map, List, and Progress tabs
- SwiftData + CloudKit — container init with CloudKit configured; falls back to local-only with detailed error logging if CloudKit fails
- `SyncStatusManager` tracks live CloudKit event notifications; cloud icon in Progress tab shows sync state
- Photo capture with thumbnails, location services, seed data import
- Successfully archived in Xcode on 2026-03-23
- See `docs/HANDOFF_iOS.md` for full build details

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

### Walked Stairways

1. 16th Avenue Tiled Steps
2. Hidden Garden Steps
3. Lincoln Park Steps
4. Vulcan Stairway
5. Saturn Street Steps
6. Pemberton Place Steps
7. Filbert Steps
8. Greenwich Street (Sansome to Montgomery)

## Active Workstreams

### 1. Solo UX — Nav Bar Redesign + Pin Icon Fix + Progress Card Header (just completed)
- `brandOrange` (#E8602C) added to AppColors.swift as the unified app brand color
- `topBarBackground` and `topBarText` semantic tokens updated to `brandOrange` / white
- Top nav bar: orange background, white "SF Stairways" title, white icons with translucent circle backgrounds, no drop shadow
- `accentAmber` usage confirmed splash-screen only; all other orange UI now uses `brandOrange`
- Progress card: `brandOrange` header bar with white "Progress" text, clipped to card corner radius
- StairShape pin positioning already correct (ZStack .top + pinWidth square frame centers icon in bulb)
- See: `docs/specs/implemented/SPEC_nav-pin-progress-visual.md`

### Previous completions
- Pin Visibility Fix: custom StairShape, 2x pin sizes, full-opacity unsaved
- Map Visual Refresh v2: amber pins, dark map, top bar, unified stair icon
- Custom teardrop pins with three-state model (Unsaved / Saved / Walked)
- "Around Me" neighborhood-aware filter with adjacent neighborhood highlighting
- Full-screen search panel (Name / Street / Neighborhood tabs)
- Filter chips: All / Saved / Walked / Nearby
- See: `docs/specs/implemented/` for full spec history

### 2. App Store — Scaffold multi-user architecture
**Current priority:** Supabase project setup + SDK integration
- Architecture spec complete: `docs/specs/implemented/SPEC_multi-user-backend-architecture.md`
- Architecture decided: Supabase backend, Sign in with Apple, Supabase Storage → R2
- Next: create Supabase project, run schema SQL, add supabase-swift to Xcode
- Backlog: auth + user accounts, App Store prep (icon, metadata, TestFlight)

### 3. Pending specs
- `SPEC_hard-mode.md` — Hard Mode feature (backlog)

## Known Issues

- CloudKit sync may still fall back to local if Xcode target lacks Background Modes → Remote Notifications capability (manual Xcode step — not in repo)
- No standalone staircase logo asset for nav bar center logo — TODO comment in MapTab.swift. Only AppIcon.appiconset exists; iOS does not support rendering via `Image("AppIcon")`.

## Repository

- `sf-stairways` (Dropbox) is the official project repository
- Xcode project: `ios/SFStairways.xcodeproj` (in repo)
- iOS source: `ios/SFStairways/` (Swift/SwiftUI)
- See `docs/HANDOFF_iOS.md` for build details
