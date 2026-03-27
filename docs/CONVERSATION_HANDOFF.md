# SF Stairways — Conversation Handoff

_Written: 2026-03-26 | For: next Cowork or Claude Code session_

---

## Project Summary

SF Stairways is a native iOS app (Swift/SwiftUI/iOS 17+) for tracking personal stairway walks across San Francisco. 382 stairways in the catalog, 8 walked so far, 0 with photos. The app has Map, List, and Progress tabs, with a dark map view as the primary interface.

**Repo:** `~/Dropbox/projects/sf-stairways/` (Dropbox folder, mounted as `sf-stairways` in Cowork)
**GitHub:** https://github.com/o4dvasq/sf-stairways
**Xcode project:** `ios/SFStairways.xcodeproj` (in repo — open this in Xcode)
**Bundle ID:** `com.o4dvasq.SFStairways`
**CloudKit container:** `iCloud.com.o4dvasq.sfstairways`

Read `CLAUDE.md` and `docs/PROJECT_STATE.md` for the full current state.

---

## Two Active Workstreams

### 1. Solo UX — Refine iOS app for personal use
Current focus: map visibility and usability. Recently completed a major map visual refresh (dark map, custom teardrop pins, search panel, Around Me filter, progress card overlay).

### 2. App Store — Scaffold multi-user architecture
Architecture decided: **Supabase** backend, Sign in with Apple, Supabase Storage → R2. Architecture spec is complete. Next: create Supabase project, run schema SQL, add supabase-swift to Xcode.

---

## What Needs Attention RIGHT NOW

### Pending Spec: Pin Visibility Fix (URGENT)
**File:** `docs/specs/SPEC_pin-visibility-fix.md`
**Status:** Ready for implementation — hand to Claude Code

The map pins are nearly invisible on the dark map. Three problems:
1. **Wrong icon:** Currently using SF Symbol `"stairs"` which renders as 5 descending steps. Must be replaced with a custom `StairShape` — exactly 3 steps, ascending left-to-right, solid white fill, matching the app icon silhouette.
2. **Too small:** Pins are 24-28pt. Need to be ~38-44pt (roughly 2x).
3. **Invisible opacity:** Unsaved pins use `opacity(0.5)` on a dark map. Remove all transparency — use full-opacity colors for all states.

The spec has complete Swift code for the custom `StairShape` and all the size/color changes.

### App Icon: v7 needs to be dragged into Xcode asset catalog
**File:** `ios/SFStairways/Resources/AppIcon_v7.png` (1024x1024)
**Design:** 3-step ascending staircase with reversed gradient fill, bold white border (~66px), yellow→burnt-orange background gradient.
**Action:** Oscar needs to manually drag this into the Xcode asset catalog.

### Splash Screen Image: needs to be placed
Oscar has a warm-toned "SF Stairs" illustration (retro/70s style, Golden Gate Bridge, person climbing stairways, "SF STAIRS" text). This needs to be saved as `ios/SFStairways/Resources/splash_image.png`. The `SplashView.swift` already exists and is wired up — it just needs the image file.

---

## Implemented Specs (completed work)

All in `docs/specs/implemented/`:

| Spec | What it did |
|---|---|
| `SPEC_workflow-bootstrap.md` | Initial repo structure, CLAUDE.md, PROJECT_STATE.md |
| `sf_stairways_map_spec_v3.md` | Original web app map spec |
| `sf_stairways_photo_spec.md` | Photo upload spec (web app, Cloudinary) |
| `SPEC_ui-improvements-v1.md` | Splash screen, app icon, marker sizing, bottom sheet redesign, progress card |
| `SPEC_cloudkit-sync-fix.md` | CloudKit init with detailed error logging, SyncStatusManager, fallback behavior |
| `SPEC_map-redesign-ios.md` | Custom teardrop pins, 3-state model, Around Me, search panel |
| `SPEC_map-visual-refresh-v2.md` | Dark map, amber branding, white top bar, filter pill redesign |
| `SPEC_multi-user-backend-architecture.md` | Supabase decision, schema design, auth strategy, cost model |
| `SPEC_xcode-project-consolidation.md` | Moved .xcodeproj into Dropbox repo (manual Xcode task, completed) |

---

## iOS Source File Map (30 files)

```
ios/SFStairways/
├── SFStairwaysApp.swift              ← App entry point, CloudKit container init, splash screen
├── Models/
│   ├── Stairway.swift                ← Codable model, 382 stairways from JSON
│   ├── StairwayStore.swift           ← Loads all_stairways.json, provides region lookups
│   ├── WalkRecord.swift              ← SwiftData @Model, CloudKit-synced
│   └── WalkPhoto.swift               ← SwiftData @Model, image data + thumbnail
├── Views/
│   ├── ContentView.swift             ← TabView (Map, List, Progress)
│   ├── SplashView.swift              ← Launch screen with fade-out
│   ├── Components/
│   │   └── ToastView.swift           ← Temporary notification overlay
│   ├── Map/
│   │   ├── MapTab.swift              ← Main map view, filter chips, progress card, top bar
│   │   ├── StairwayAnnotation.swift  ← Thin wrapper, passes state to StairwayPin
│   │   ├── TeardropPin.swift         ← Pin shape + StairwayPin view (NEEDS FIX — see spec)
│   │   ├── StairwayBottomSheet.swift ← Detail card on pin tap (3-state: unsaved/saved/walked)
│   │   ├── SearchPanel.swift         ← Full-screen search (Name/Street/Neighborhood tabs)
│   │   └── AroundMeManager.swift     ← Neighborhood detection + adjacent highlighting
│   ├── List/
│   │   ├── ListTab.swift             ← Scrollable stairway list
│   │   └── StairwayRow.swift         ← Row component
│   ├── Detail/
│   │   ├── StairwayDetail.swift      ← Full stairway detail view
│   │   └── PhotoViewer.swift         ← Photo gallery
│   └── Progress/
│       └── ProgressTab.swift         ← Stats + sync status
├── Services/
│   ├── LocationManager.swift         ← CLLocationManager wrapper
│   ├── PhotoService.swift            ← Camera/photo library integration
│   ├── SeedDataService.swift         ← Seeds WalkRecords from target_list.json on first launch
│   └── SyncStatusManager.swift       ← CloudKit sync event tracking
├── Resources/
│   ├── AppColors.swift               ← All color constants (pin, surface, brand)
│   ├── all_stairways.json            ← 382 stairways catalog
│   ├── target_list.json              ← Oscar's 13 target stairways
│   ├── AppIcon_v7.png                ← Final app icon (needs manual Xcode import)
│   └── (splash_image.png)            ← Oscar needs to place this
└── Assets.xcassets/                  ← Xcode asset catalog
```

---

## Key Design Decisions

- **Dark map** via `.preferredColorScheme(.dark)` on the Map view
- **Three pin states:** Unsaved (amber), Saved (light green), Walked (green) — all teardrop shape
- **Color hierarchy principle:** Bright = actionable ("click here"), dim = informational
- **Web app deprecated** — iOS is the sole platform going forward
- **CloudKit** for personal sync (private DB); **Supabase** for eventual multi-user
- **Specs workflow:** Design in Cowork → spec in `docs/specs/` → Claude Code implements → move to `implemented/`

---

## Oscar's Workflow Preferences

- Cowork does design, planning, and specs — NOT code changes (except quick layout/formatting fixes)
- Claude Code handles all implementation via specs
- Specs must be complete (all 9 sections, no placeholders) before handoff
- Terminal commands must be copy-pasteable (no inline comments)
- Oscar is not comfortable with manual git — uses Claude Code or in-app GitHub integration
