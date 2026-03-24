# sf-stairways

SF stairway exploration tracker — web app + native iOS app.

## Two Platforms

### Web App (shipped)
- Live at https://o4dvasq.github.io/sf-stairways/
- Vanilla JS + HTML/CSS, Leaflet.js, GitHub Contents API, Cloudinary photos
- Entry point: `index.html` (single-file app)

### iOS App (archived, running on device)
- Swift / SwiftUI / iOS 17+, SwiftData + CloudKit
- Source: `ios/SFStairways/` (21 files — no .xcodeproj, configured manually in Xcode)
- Bundle ID: `com.o4dvasq.SFStairways`
- CloudKit container: `iCloud.com.o4dvasq.sfstairways`
- See `docs/HANDOFF_iOS.md` for full build details and known issues

## Repo

https://github.com/o4dvasq/sf-stairways

## Active Workstreams

1. **Solo UX** — refine the iOS app for personal use (CloudKit sync, photo workflow, directions)
2. **App Store** — scaffold multi-user architecture for eventual public release

## File Map

```
sf-stairways/
├── index.html                  ← web app (single file)
├── data/
│   ├── target_list.json        ← personal walk log (13 stairways)
│   └── all_stairways.json      ← all 382 SF stairways from scraper
├── ios/SFStairways/            ← iOS app source (Swift/SwiftUI)
│   ├── Models/                 ← Stairway, WalkRecord, WalkPhoto, StairwayStore
│   ├── Views/                  ← Map, List, Detail, Progress tabs
│   ├── Services/               ← LocationManager, PhotoService, SeedDataService
│   └── Resources/              ← AppColors, bundled JSON data
├── scripts/
│   └── scrape_stairways.py     ← one-time data collector
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DECISIONS.md
│   ├── PROJECT_STATE.md
│   ├── HANDOFF_iOS.md          ← iOS build details and known issues
│   └── specs/
│       ├── implemented/        ← completed specs
│       └── (pending specs)     ← active work
└── README.md
```

## Local Dev

Web: `python3 -m http.server 8080` → http://localhost:8080
iOS: Open Xcode project at `~/Desktop/SFStairways/`, run on device or simulator

## Workflow

- Specs live in `docs/specs/` (pending) and `docs/specs/implemented/` (done)
- After implementing a spec: move spec file to `docs/specs/implemented/`, commit, push
