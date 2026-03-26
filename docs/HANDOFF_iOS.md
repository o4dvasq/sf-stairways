# SF Stairways iOS App — CoWork Handoff Summary

**Project:** sf-stairways-ios | **Date:** 2026-03-22 | **Status:** Working build on device

---

## What was built

A native iOS app (Swift / SwiftUI / iOS 17+) for tracking personal exploration of San Francisco's 382 public stairways. The app is running on Oscar's iPhone (Oscar-Air) from Xcode.

### Core features working:
- **Map tab** — Full-screen Apple Maps view centered on SF with pins for all 382 stairways. Filter chips: All / Walked / To Do / Nearby. Tapping a pin opens a bottom sheet with stairway summary, walk toggle, and navigation to detail view.
- **List tab** — Searchable list grouped by neighborhood with segment filter (All / Walked / To Do). Shows step count, height, photo count, and walk status per row.
- **Progress tab** — Completion ring (X of 382), stat cards (height climbed, steps, neighborhoods, walk days), neighborhood progress bars, recent walks list.
- **Detail view** — Photo carousel, stats row, walk status toggle with editable date, notes editor, photo grid with add button, source link to sfstairways.com.
- **Photo capture** — Camera and photo library picker, full-res stored with auto-generated 300px thumbnails.
- **Photo viewer** — Full-screen viewer with delete confirmation.
- **CloudKit sync** — SwiftData models configured for CloudKit private database. Falls back gracefully to local-only storage if CloudKit container isn't available.
- **Seed data** — First-launch import of 13 stairways from target_list.json (8 walked, 5 to-do) with dates and notes.
- **Location services** — Current location blue dot, proximity-based "Nearby" filter (1500m radius).

### Architecture:
- **Two-layer data model:** 382-stairway catalog is bundled JSON (read-only). Personal walk data (WalkRecord, WalkPhoto) lives in SwiftData synced to CloudKit.
- **CloudKit container:** `iCloud.com.o4dvasq.sfstairways` (registered in Developer Portal, capability enabled in Xcode)
- **All SwiftData attributes have defaults** (CloudKit requirement) — no unique constraints, all relationships optional.
- **@Observable pattern** for StairwayStore and LocationManager (iOS 17+)

### Known issues resolved during build:
1. **CloudKit schema compatibility** — CloudKit requires all attributes optional with defaults, no unique constraints, optional relationships. Models were updated accordingly.
2. **Null coordinates in data** — Entry 367 in all_stairways.json has null lat/lng. Stairway model now uses optional lat/lng with `hasValidCoordinate` guard.
3. **Bundle resource loading** — JSON files must be in Copy Bundle Resources (not nested in a subfolder group). StairwayStore has fallback search logic.
4. **CloudKit fallback** — App gracefully falls back to local-only SwiftData if CloudKit container fails to initialize.

### What's NOT in the Xcode project file:
The Xcode project now lives in the repo at `ios/SFStairways.xcodeproj`. The following were configured manually in Xcode and would need to be reconfigured if the project is recreated:
- Signing & Capabilities: iCloud (CloudKit), Push Notifications
- CloudKit container: `iCloud.com.o4dvasq.sfstairways`
- Info.plist keys: NSLocationWhenInUseUsageDescription, NSCameraUsageDescription, NSPhotoLibraryUsageDescription
- Deployment target: iOS 17.0
- Bundle ID: com.o4dvasq.SFStairways

---

## File inventory (21 files)

```
SFStairways/
├── SFStairwaysApp.swift              — App entry, CloudKit container config with fallback
├── SFStairways.entitlements          — CloudKit + push notification entitlements
├── Models/
│   ├── Stairway.swift                — Catalog model (Codable, optional lat/lng)
│   ├── WalkRecord.swift              — SwiftData @Model, CloudKit-compatible
│   ├── WalkPhoto.swift               — SwiftData @Model, external storage for images
│   └── StairwayStore.swift           — Loads bundled JSON, search, debug logging
├── Views/
│   ├── ContentView.swift             — TabView (Map, List, Progress)
│   ├── Map/
│   │   ├── MapTab.swift              — Map with annotations, filters, bottom sheet
│   │   ├── StairwayAnnotation.swift  — Custom color-coded map pins
│   │   └── StairwayBottomSheet.swift — Pin tap summary sheet
│   ├── List/
│   │   ├── ListTab.swift             — Searchable grouped list
│   │   └── StairwayRow.swift         — List row component
│   ├── Detail/
│   │   ├── StairwayDetail.swift      — Full detail with photos, notes, walk status
│   │   └── PhotoViewer.swift         — Full-screen photo viewer with delete
│   └── Progress/
│       └── ProgressTab.swift         — Stats dashboard with completion ring
├── Services/
│   ├── LocationManager.swift         — CLLocationManager @Observable wrapper
│   ├── PhotoService.swift            — PHPickerViewController + UIImagePickerController
│   └── SeedDataService.swift         — First-launch target_list.json import
└── Resources/
    ├── AppColors.swift               — Color definitions (forestGreen, walkedGreen, etc.)
    ├── all_stairways.json            — 382 stairway catalog
    └── target_list.json              — 13 seed stairways with walk data
```

---

## Design decisions

- **Color system:** Forest green (#2D5F3F) primary, walked green (#4CAF50), unwalked slate (#78909C), closed red (#B0706F), amber accent (#E8A838). Defined in AppColors.swift as static Color extensions.
- **Pin colors:** Green = walked, gray = not walked, muted red = closed. Blue dot = user location.
- **CloudKit fallback:** App tries CloudKit first, catches the error, falls back to local SwiftData. This means the app works even without proper CloudKit setup — it just won't sync.
- **Photo storage:** Full-res JPEG (0.85 quality) + 300px thumbnail, both marked `@Attribute(.externalStorage)` so SwiftData stores them as CKAssets, not inline blobs.
- **No Info.plist file in the project** — permission strings were added directly in Xcode's Info tab to avoid the "multiple commands produce Info.plist" build error.

---

## Next steps / backlog ideas

- [ ] Fix CloudKit to work properly (currently falls back to local — may need Background Modes → Remote Notifications in capabilities)
- [ ] Add walking directions / navigation from current location to stairway
- [ ] Add photo captions
- [ ] Sort neighborhoods by proximity in list view
- [ ] Add stairway rating system
- [ ] Integrate with sf-stairways GitHub Pages site (sync walk data to web)
- [ ] App icon design
- [ ] Widget showing nearby unwalked stairways
