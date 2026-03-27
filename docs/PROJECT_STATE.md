# Project State — sf-stairways

_Last updated: 2026-03-27_

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

### 1. Solo UX — UI Improvements v2 (just completed)

Five targeted UI polish changes:

- **Slimmer nav bar**: `brandOrange` top bar reduced to 6pt vertical padding. White `StairShape` icon centered via ZStack. "SF Stairways" text removed.
- **Cleaner map pins**: `StairShape` icon removed from pin bulb — pins are now solid color teardrop only. All pin sizes reduced ~20% (unsaved 30×38pt, saved/walked 36×45pt, selected 42×53pt).
- **ProgressCard width fix**: outer VStack fixed at 120pt; orange "Progress" header now matches the grey content box width instead of expanding to full screen width.
- **StairwayDetail mini-map**: photo carousel at top replaced with a non-interactive `Map` (200pt height, `latitudeDelta: 0.004`) showing an orange `Marker` at the stairway's location. Placeholder shown if coordinates unavailable.
- **StairwayDetail Save button**: "Save" button in toolbar visible when `walkRecord == nil`. Creates `WalkRecord(walked: false)` on tap.

See: `docs/specs/implemented/SPEC_ui-improvements-v2.md`

### Previous completions
- Hard Mode: per-stairway proximity-gated walk verification with unverified badge
- Nav Bar Redesign + Progress Card Header: `brandOrange` top bar, progress card header bar
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
- (none — specs directory is clean)

## Known Issues

- CloudKit sync may still fall back to local if Xcode target lacks Background Modes → Remote Notifications capability (manual Xcode step — not in repo)

## Repository

- `sf-stairways` (Dropbox) is the official project repository
- Xcode project: `ios/SFStairways.xcodeproj` (in repo)
- iOS source: `ios/SFStairways/` (Swift/SwiftUI)
- See `docs/HANDOFF_iOS.md` for build details
