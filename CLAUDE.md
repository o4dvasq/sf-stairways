# sf-stairways

SF stairway exploration tracker — native iOS app.

## iOS App

- Swift / SwiftUI / iOS 17+, SwiftData + CloudKit
- Source + Xcode project: `ios/` (SFStairways.xcodeproj + SFStairways/ source)
- Bundle ID: `com.o4dvasq.SFStairways`
- CloudKit container: `iCloud.com.o4dvasq.sfstairways`
- See `docs/IOS_REFERENCE.md` for full build details and known issues

## Repo

https://github.com/o4dvasq/sf-stairways

## Active Workstreams

1. **Solo UX** — refine the iOS app for personal use (CloudKit sync, photo workflow, directions)
2. **App Store** — scaffold multi-user architecture for eventual public release

## File Map

```
sf-stairways/
├── index.html                  ← web app (deprecated, kept for reference)
├── data/
│   └── all_stairways.json      ← all 382 SF stairways from scraper
├── ios/
│   ├── SFStairways.xcodeproj/  ← Xcode project (open this in Xcode)
│   ├── SFStairways.entitlements
│   └── SFStairways/            ← iOS app source (Swift/SwiftUI)
│       ├── Models/             ← Stairway, WalkRecord, WalkPhoto, StairwayOverride, StairwayStore
│       ├── Views/              ← Map, List, Detail, Progress, Settings, SplashView
│       ├── Services/           ← LocationManager, PhotoService, SeedDataService, SyncStatusManager, SupabaseManager, AuthManager
│       ├── Config/             ← Supabase.plist (gitignored — not in repo)
│       ├── Resources/          ← AppColors, bundled JSON data
│       └── Assets.xcassets/    ← App icon, accent color
├── scripts/
│   └── scrape_stairways.py     ← one-time data collector
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DECISIONS.md
│   ├── PROJECT_STATE.md
│   ├── IOS_REFERENCE.md        ← iOS build details and known issues
│   └── specs/
│       ├── implemented/        ← completed specs
│       └── (pending specs)     ← active work
└── README.md
```

## Local Dev

iOS: Open `ios/SFStairways.xcodeproj` in Xcode, run on device or simulator

## Workflow

- Specs live in `docs/specs/` (pending) and `docs/specs/implemented/` (done)
- After implementing a spec: move spec file to `docs/specs/implemented/`, commit, push
