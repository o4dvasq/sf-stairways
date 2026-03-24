# Project State — sf-stairways

_Last updated: 2026-03-23_

## Platforms

### Web App (shipped)
- Interactive Leaflet.js map showing all 382 SF stairways
- Walk logging, target list management, photo uploads via Cloudinary
- Deployed on GitHub Pages: https://o4dvasq.github.io/sf-stairways/

### iOS App (archived, running on device)
- Swift/SwiftUI/iOS 17+ with Map, List, and Progress tabs
- SwiftData + CloudKit — container init with CloudKit configured; falls back to local-only with detailed error logging if CloudKit fails
- `SyncStatusManager` tracks live CloudKit event notifications; cloud icon in Progress tab shows sync state
- Photo capture with thumbnails, location services, seed data import
- Successfully archived in Xcode on 2026-03-23
- See `docs/HANDOFF_iOS.md` for full build details

## Current Data

| Metric | Value |
|---|---|
| Target stairways | 13 |
| Walked | 8 |
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

### 1. Solo UX — Refine iOS app for personal use
**Current priority:** Verify CloudKit sync is live on device after the fix
- Just completed: CloudKit sync fix (SyncStatusManager, seed guard, sync indicator)
- To verify: build and run on physical device; check Progress tab cloud icon turns green
- Manual Xcode step still needed: Background Modes → Remote Notifications capability
- Backlog: photo workflow improvements, walking directions, web-iOS data sync

### 2. App Store — Scaffold multi-user architecture
**Current priority:** Supabase project setup + SDK integration
- Spec ready: `docs/specs/SPEC_multi-user-backend-architecture.md`
- Architecture decided: Supabase backend, Sign in with Apple, Supabase Storage → R2
- Next: create Supabase project, run schema SQL, add supabase-swift to Xcode
- Backlog: auth + user accounts, App Store prep (icon, metadata, TestFlight)

## Known Issues

- CloudKit sync may still fall back to local if Xcode target lacks Background Modes → Remote Notifications capability (manual Xcode step — not in repo)
- No .xcodeproj in repo — Xcode project configured manually at `~/Desktop/SFStairways/`

## Repository

- `sf-stairways` (Dropbox) is the official project repository for both web and iOS
- iOS source lives at `ios/SFStairways/` (22 Swift files)
- `HANDOFF_iOS.md` in `docs/HANDOFF_iOS.md`
