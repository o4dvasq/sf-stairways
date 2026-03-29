# Project State — sf-stairways

_Last updated: 2026-03-29 (visual refresh)_

## Platforms

### iOS App (primary)
- Swift/SwiftUI/iOS 17+ with Map, List, Stats, and **Search** tabs
- SwiftData + CloudKit — container init with CloudKit configured; falls back to local-only with detailed error logging if CloudKit fails
- `SyncStatusManager` tracks live CloudKit event notifications; cloud icon in Stats tab shows sync state
- Supabase SDK integrated; `AuthManager` manages Sign in with Apple session
- Photo capture with thumbnails, location services, seed data import
- Tags are **read-only** on iOS (display + filter only) — all tag CRUD is macOS-only; `TagEditorSheet` removed
- Successfully archived in Xcode on 2026-03-23
- See `docs/IOS_REFERENCE.md` for full build details

### macOS Admin Dashboard
- **`ios/SFStairwaysMac/`** — macOS target in `SFStairways.xcodeproj`, bundle ID `com.o4dvasq.SFStairways.mac`
- Shares the same CloudKit container (`iCloud.com.o4dvasq.sfstairways`) as iOS — all walk data, overrides, tags sync automatically
- Shares SwiftData model files with iOS (same `Models/*.swift`)
- Three-column `NavigationSplitView`: sidebar (neighborhoods + tags filter) → sortable stairway table → detail panel
- **Sidebar Tags section**: lists tags with assignment counts; clicking a tag filters table; intersects with neighborhood filter
- **Table sorting**: all numeric columns sortable (Height, Steps, Elev. Gain, Photos, Date Walked + Name); nil values sort to bottom in both directions via `nilLastSorted` helper
- **TagManagerSheet**: full tag CRUD — create custom tags (slug ID generation), inline rename, delete with cascade confirmation, preset tags displayed read-only with counts
- Detail panel: catalog vs. walk data comparison, editable curator overrides, notes editing, tag add/remove + **"Create & Assign…" inline option**, photo grid with delete + Add Photos (NSOpenPanel + drag-drop)
- Bulk Operations: bulk tag assign + **"Create new tag…" inline option** + **"Remove Tag from All Selected"** section, bulk mark walked, CSV export
- Data Hygiene sheet: flags missing height, missing coordinates, no HealthKit data, promotion candidates, proximity unverified
- **App icon**: white StairShape silhouette on brandOrange (#E8602C) background, all 10 required macOS sizes generated
- **Acknowledgements**: `info.circle` toolbar button opens `AcknowledgementsSheet` with data source credits and links
- No Supabase, no HealthKit fetching on macOS (displays synced walk data only)

### Web App (deprecated)
- `index.html` remains in the repo for historical reference
- No further development — see DECISIONS.md for rationale

## Current Data

| Metric | Value |
|---|---|
| Walked stairways | 8 |
| With photos | 0 |
| All SF stairways (catalog) | **1,144** (was 382) |
| Neighborhoods | **61** (53 original + 8 new) |

## Recent Completions

### 2026-03-29 (this session)
- **Visual refresh phase 1** — Light mode as default appearance (removed `.preferredColorScheme(.dark)` from Map); warm terracotta `brandOrange` (#D4724E light / #E07A52 dark, adaptive via `UIColor(dynamicProvider:)`); six new adaptive surface/text tokens (`surfaceBackground`, `surfaceCard`, `surfaceCardElevated`, `textPrimary`, `textSecondary`, `divider`); progress ring stroke changed from `walkedGreen` → `brandOrange`; SF Pro Rounded on all display numbers, stat card labels, neighborhood headers, search tab pills, and nav bar titles (via `UINavigationBarAppearance` in ContentView); splash screen background changed from `brandAmber` → `brandOrange`; stat card backgrounds use warm `surfaceCardElevated` token.

### 2026-03-29 (earlier)
- **Map label cleanup** — `Stairway.displayName` computed property truncates names to first 4 words, stripping trailing `.,;` from each word; used only for map annotation labels; at `mapSpan > 0.02` (city-wide zoom) labels are hidden entirely (`""` passed to `Annotation`); at `mapSpan <= 0.02` (neighborhood zoom or closer) the truncated `displayName` appears; full `name` unchanged everywhere else.

### 2026-03-29 (earlier)
- **UX fixes round 3** — `forestGreen` brightened to RGB 80/200/120 (#50C878) for dark-mode readability; notes auto-save on dismiss removed (explicit Save button only); collapsible `DisclosureGroup` neighborhoods in Stats tab (collapsed by default, expand to show walks sorted by date with name/steps/date); Stats card orange bar now contains "Stats" label (white text on brandAmber, replaces 4pt stripe); search promoted from floating circle to 4th tab (Map | List | Stats | Search) via new `SearchTab` wrapper in ContentView; `NavigationCoordinator` (`@Observable`) enables cross-tab stairway/neighborhood selection from Search; floating search circle + `showSearch` state removed from MapTab; annotation labels use `displayName` (first 4 words, trailing punctuation stripped, no ellipsis); labels hidden at `mapSpan > 0.02` (wider than neighborhood level).

### 2026-03-29 (earlier)
- **Attribution & acknowledgements** — iOS bottom sheet shows "View on Urban Hiker SF Map" link for stairways with `geocodeSource == "urban_hiker"` (alongside existing sfstairways.com link for stairways with both sources); macOS detail panel adds "UH Map" row in data comparison grid for Urban Hiker stairways; iOS Settings gains a new "Acknowledgements" section (SF Stairways attribution, Urban Hiker SF attribution + Stairway Map link, Buy a Matcha link with amber cup icon, book credit); macOS gets an `info.circle` toolbar button opening `AcknowledgementsSheet` with the same content.
- **macOS tag management** — `TagManagerSheet.swift` with full CRUD (create, inline rename, delete with cascade to TagAssignments, preset tags read-only); sidebar Tags section in `StairwayBrowser` with per-tag counts and filter intersecting neighborhood filter; all numeric table columns sortable with nil-last logic; "Create & Assign…" inline option in detail panel Add Tag menu; Remove Tag and Create New Tag sections in BulkOperationsSheet; iOS `TagEditorSheet` deleted and tags made fully read-only on iOS; macOS app icon generated (white StairShape on brandOrange, all 10 sizes).

### 2026-03-29 (earlier)
- **Urban Hiker SF data import** — `scripts/import_urban_hiker_locations.py` imports 762 new stairways from Urban Hiker SF (Alexandra Kenin) KMZ data. 4 coordinate gap-fills applied. 8 new neighborhoods created. Script is idempotent with `--dry-run` / `--apply` modes.
- **macOS photo add + notes editing** — "Add Photos..." button (NSOpenPanel) + drag-drop in detail panel photos section; inline notes editing; proper macOS thumbnail generation.
- **HealthKit data accuracy fix** — removed retroactive full-day pull; stats display restricted to active walks only; one-time migration clears bad data.
- **macOS Admin Dashboard** — three-column browser, detail panel, data hygiene, bulk operations + CSV export.
- **Photo sync fix** — upload logging, auth check, failed vs pending badge.
- **Map launch cleanup** — removed auto-zoom-to-nearest; HealthKit entitlement; ProgressCard amber bar header.

### 2026-03-28
- **Remove Saved concept + layout tweaks** — two-state model; search bottom-right; settings leading; Progress tab renamed Stats; one-time migration.
- **HealthKit walk stats display** — walk method badge, retroactive pull flow (now removed), HealthKit auth in Settings.
- **Camera during active walk** — camera button in activeSessionBanner; WalkRecord created on walk start.
- **Hard Mode confirmation prompt** — amber badge for unverified walks; confirmation alert flow.
- **Stairway Tags v1** — StairwayTag + TagAssignment models, tag editor, map filter, preset tags.
- **Active walk mode** — timer, HealthKit steps/elevation, end/cancel flow.
- **Photo suggestions** — PHAsset dedup, dismiss, add from walk day.
- **Photo camera roll save** and **photo persistence fix**.
- Launch zoom to nearest, map pin tap targets, curator notes-to-commentary, expandable bottom sheet.

### 2026-03-27 and earlier
- UI overhaul: amber accent, top bar redesign, splash fix, pin colors
- Curator social layer, Supabase integration, curator data layer
- See: `docs/specs/implemented/` for full spec history

## Pending Specs

- `docs/specs/SPEC_ios-admin-app.md` (iOS Admin App)

## Known Issues

- **macOS CloudKit sync:** first launch on Mac requires a few minutes for CloudKit to sync iOS walk data down. Leave both apps open; data appears automatically once sync completes.
- **HealthKit:** entitlement added to `.entitlements`; HealthKit capability must also be manually enabled in Xcode target Signing & Capabilities (links HealthKit.framework).
- **CloudKit sync:** may still fall back to local if Xcode target lacks Background Modes → Remote Notifications capability (manual Xcode step — not in repo).
- **CKErrorDomain error 2** (not authenticated) surfaces as red error icon on Stats tab — separate from Supabase auth; requires CloudKit investigation.
- **supabase-swift** package + new files from curator social layer not yet confirmed added to Xcode target.
- **Sign in with Apple:** `signInError` display is temporary for debugging — remove after auth is confirmed working.
- **Supabase Apple provider** config not yet manually verified (required for Sign in with Apple to work).
- **Stairway count in iOS app** still shows 382 — `all_stairways.json` bundle resource needs to be re-bundled into the Xcode build for the expanded 1,144-entry dataset to appear on device.

## Repository

- sf-stairways (Dropbox) is the official project repository
- Xcode project: `ios/SFStairways.xcodeproj` (in repo)
- iOS source: `ios/SFStairways/` (Swift/SwiftUI)
- macOS source: `ios/SFStairwaysMac/` (Swift/SwiftUI, macOS)
- See `docs/IOS_REFERENCE.md` for build details
