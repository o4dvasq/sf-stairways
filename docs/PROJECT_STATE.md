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

### 1. Solo UX — Curator Data Layer (just completed)

New `StairwayOverride` SwiftData model lets Oscar record authoritative stairway measurements:
- **Stair count** (physical stairs, not pedometer) — `verifiedStepCount: Int?`
- **Height** (elevation gain in feet) — `verifiedHeightFt: Double?`
- **Description** — curator blurb — `stairwayDescription: String?`

**Display behavior:**
- Verified values override catalog values everywhere stats appear
- Verified values show a `checkmark.seal.fill` badge (forestGreen) in stats row, list row, bottom sheet
- Label changes: "stairs" (not "steps") when showing verified stair count
- Catalog height used as fallback when no override exists

**Curator section in StairwayDetail:**
- Appears only for walked stairways
- Inline editable fields (number pad, decimal pad, TextEditor)
- Saves on keyboard dismiss / focus loss / view disappear
- Creating override: first edit on any field; deleting: clearing all three fields
- Section header "Stairway Info" with checkmark.seal.fill when any value exists

**Previously completed this session:**
- All map pins changed to solid orange (`brandOrange` / `brandOrangeDark`) — three-state color system (amber/light green/green) dropped
- Stair icon removed from MapTab top bar — nav bar is now icon-free orange bar
- `brandOrangeDark` (#BF4A1F) added to AppColors as selected-pin color

### Previous completions
- UI Improvements v2: slimmer nav bar, icon-free pins, ProgressCard width fix, detail mini-map, Save button
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
- `SPEC_curator-social-layer.md` — photo carousel, photo likes, curator commentary, hard mode as app-level setting

## Known Issues

- CloudKit sync may still fall back to local if Xcode target lacks Background Modes → Remote Notifications capability (manual Xcode step — not in repo)
- CKErrorDomain error 2 (not authenticated) surfaces as red error icon on Progress tab — to be fixed in curator-social-layer spec

## Repository

- `sf-stairways` (Dropbox) is the official project repository
- Xcode project: `ios/SFStairways.xcodeproj` (in repo)
- iOS source: `ios/SFStairways/` (Swift/SwiftUI)
- See `docs/HANDOFF_iOS.md` for build details
