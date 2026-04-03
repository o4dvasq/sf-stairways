# Project State — sf-stairways

_Last updated: 2026-04-03 (splash-image-update)_

## Platforms

### iOS App (primary)
- Swift/SwiftUI/iOS 17+ with Map, List, Stats, and **Search** tabs
- SwiftData + CloudKit — container init with CloudKit configured; falls back to local-only with detailed error logging if CloudKit fails
- `SyncStatusManager` tracks live CloudKit event notifications; cloud icon in Stats tab shows sync state
- Supabase SDK integrated; `AuthManager` manages Sign in with Apple session
- Photo capture with thumbnails, location services, seed data import
- Tags: display, filter, add, and create on iOS; full CRUD (rename, delete) on macOS/Admin only
- `StairwayStore` filters out deleted stairways via `applyDeletions(_:)` — map, list, search, progress all respect deletions
- **Visual design: light-first** — warm terracotta `brandOrange`, SF Pro Rounded for display text, `surfaceCardElevated` stat cards, orange progress ring
- **Neighborhoods: SF 311 Neighborhoods** — 117 granular neighborhoods (68 with stairways); powered by `NeighborhoodStore` (GeoJSON-backed, computes centroids + adjacency at startup)
- **No HealthKit, no active walk recording** — "Mark Walked" is the only walk-logging action; tapping it fires a medium haptic, animates the sheet background to soft green (`surfaceWalked`), bounces the checkmark icon, and reveals a "N of M in [neighborhood]" progress line in the walked status card
- **Hard Mode** — UserDefaults-only preference (no Supabase sync); toggle always enabled in Settings regardless of auth state; proximity check (150m) enforced at mark time; "Mark Anyway" override logs `proximityVerified = false`; Progress tab shows verified count only when > 0
- **Share card** — walked stairways show a share button (`square.and.arrow.up`, brandOrange) in the bottom sheet header; tapping generates a 1080×1920 portrait card via `ImageRenderer` and opens the native iOS share sheet. Card is branded: brandAmber frame around inset photo, white `StairShape` + "SF Stairways" logo overlay (dark pill) **bottom-left**, neighborhood progress pill ("N of M") bottom-right — both pills are in the bottom portion of the photo, safe from Messages and Instagram Post center crops. No-photo variant uses brandOrange solid content area with stairway name + progress in white.
- **Neighborhood badges** — `NeighborhoodCard` shows a `checkmark.seal.fill` (walkedGreen) badge when the neighborhood is 100% complete. `NeighborhoodDetail` progress section shows "All X stairways walked" label in walkedGreen + walkedGreen tinted `ProgressView` on completion. Completed neighborhoods on the map get a green polygon fill + slightly heavier stroke.
- **Discovery nuggets** — `NuggetProvider` loads `neighborhood_facts.json` (18 neighborhood-specific + 10 global facts). `NeighborhoodDetail` shows a per-neighborhood fact in tertiary text below the progress bar. `ProgressTab` shows a daily-rotating global fact (seeded by day-of-year) below the summary ring.
- Successfully archived in Xcode on 2026-03-23
- See `docs/IOS_REFERENCE.md` for full build details

### iOS Admin App (`SFStairwaysAdmin`)
- **`ios/SFStairwaysAdmin/`** — separate iOS target in `SFStairways.xcodeproj`, bundle ID `com.o4dvasq.SFStairways.admin`
- Shares the same CloudKit container (`iCloud.com.o4dvasq.sfstairways`) — all override, tag, and deletion changes sync automatically
- Shares SwiftData model files with both iOS and macOS targets
- **No map, no photo management, no HealthKit, no Supabase** — utility-only tool
- `AdminBrowser` — searchable list of all stairways; filter chips (All/Walked/Unwalked/Has Override/Has Issues); sort by Name/Neighborhood/Date Walked; row indicators for walked status, override, tag count; toolbar: Tag Manager + Removed Stairways buttons
- `AdminDetailView` — push-navigation detail: catalog data (read-only), editable overrides (height, description) with Save/Cancel, tag chips with add/remove, "Remove Stairway" destructive action
- `AdminTagManager` — modal sheet: preset tags read-only with counts, custom tags with inline rename and delete (cascade confirmation), create new tag
- `RemovedStairwaysView` — modal sheet: list of `StairwayDeletion` records with name/date/reason; swipe to restore

### macOS Admin Dashboard
- **`ios/SFStairwaysMac/`** — macOS target in `SFStairways.xcodeproj`, bundle ID `com.o4dvasq.SFStairways.mac`
- Shares the same CloudKit container as iOS — all walk data, overrides, tags, deletions sync automatically
- Shares SwiftData model files with iOS (same `Models/*.swift`)
- Three-column `NavigationSplitView`: sidebar (neighborhoods + tags filter) → sortable stairway table → detail panel
- **Deletion filtering**: `StairwayBrowser` queries `StairwayDeletion` records and excludes matching stairways from the table
- **Sidebar Tags section**: lists tags with assignment counts; clicking a tag filters table; intersects with neighborhood filter
- **Table sorting**: Name, Height, Photos, Date Walked (nil values sort to bottom via `nilLastSorted`)
- **TagManagerSheet**: full tag CRUD — create custom tags, inline rename, delete with cascade confirmation, preset tags read-only
- Detail panel: catalog vs. walk data comparison (labeled "Walk Data (legacy)"), editable curator overrides, notes editing, tag add/remove, photo grid with delete + Add Photos
- Bulk Operations: bulk tag assign/remove, bulk mark walked, CSV export (name, neighborhood, height, walked, date walked)
- Data Hygiene sheet: flags missing height, missing coordinates, promotion candidates, proximity unverified
- **App icon**: white StairShape silhouette on brandOrange background
- **Acknowledgements**: `info.circle` toolbar button opens `AcknowledgementsSheet`
- No Supabase, no HealthKit on macOS

### Web (GitHub Pages)
- **Landing page** — `index.html` at repo root; static HTML, no JS dependencies
  - Hero: full-viewport SF photo (Unsplash CDN), Instrument Serif display type, brand orange CTA
  - Features section (5 items), Story section, second CTA strip, footer
  - Google Fonts: Instrument Serif + DM Sans
  - TestFlight button links to `https://testflight.apple.com/join/PLACEHOLDER` — update when TestFlight is live
- **Privacy policy** — `privacy.html`; required for Apple external TestFlight distribution
- **Deprecated web app** — moved to `legacy/index.html` for historical reference

## Current Data

| Metric | Value |
|---|---|
| Walked stairways | 8 |
| With photos | 0 |
| All SF stairways (catalog) | **382** |
| SF 311 Neighborhoods | **117** total, **68** with stairways |

## Recent Completions

### 2026-04-03
- **Splash Image Update** — `splash.imageset` now references `splash_with_text.png` (new branded illustration with "SF Stairways" title and tagline baked in). Deleted `splash_image.jpeg` and `Gemini_Generated_Image_cfnhajcfnhajcfnh.png`. Font `.ttf` files (DM Sans, Instrument Serif variants) moved from `Assets.xcassets/` to `fonts/` at project root — they're web/design references, not iOS app resources. `SplashView.swift` unchanged.
- **Share Card Crop-Safe Layout** — Logo overlay moved from `.topLeading` to `.bottomLeading` in `ShareCardView`. Both the logo pill and progress pill now sit at the bottom of the photo inset (logo left, progress right), keeping all branding within the safe zone for Messages (square crop) and Instagram Posts (4:5 crop). No-photo layout unchanged.
- **Asset Cleanup** — `splash.imageset/Contents.json` updated to reference `splash_with_text.png` (was pointing to non-existent `splash_image.jpeg`). Deleted `Gemini_Generated_Image_cfnhajcfnhajcfnh.png`. Moved 4 `.ttf` font files (DM Sans, Instrument Serif variants) out of `Assets.xcassets` into `fonts/` at the project root — they're web font references, not iOS app resources.

### 2026-04-02
- **Progress Count Bugfix + Neighborhoods Visited** — `ProgressTab` now filters `walkedRecords` against `validStairwayIDs` (a `Set<String>` derived from `store.stairways`, which has deletions applied). This fixes the walked count (was showing 76 including deleted stairways; now matches the map's correct count). `verifiedCount` uses the same filter. All downstream stats (height, neighborhood cards, completion ring) are automatically correct since they derive from `walkedRecords`. Map `ProgressCard` now shows a "X hoods" line (only when > 0) counting neighborhoods with at least one walked stairway, computed from `store.stairways` grouped by neighborhood. Permission strings in `project.pbxproj` were already correct ("SF Stairways" with space) — no change needed.
- **Mark Walked Celebration** — `StairwayBottomSheet` now treats "Mark Walked" as a moment: (1) `UIImpactFeedbackGenerator(style: .medium)` fires instantly; (2) `withAnimation(.easeInOut(duration: 0.4))` wraps `modelContext.save()` so SwiftData's `@Query` update triggers the animation transaction; (3) the ScrollView background animates from `Color(.systemBackground)` to `Color.surfaceWalked` (`#F0FAF1` light / dark forest tint dark mode), driven by `.animation(.easeInOut(duration: 0.4), value: isWalked)` on the background modifier; (4) the checkmark icon gets `.symbolEffect(.bounce, value: isWalked)` — fires a bounce on mark; (5) `neighborhoodProgressLine` `@ViewBuilder` property (uses existing `store` + `walkRecords`) shows "N of M in [neighborhood]" below the walked date, suppressed when `total <= 1`. Background reverts to white on unmark with no celebration. `surfaceWalked` added to `AppColors` as a light/dark adaptive color token.
- **Neighborhood Rewards (Badges + Discovery Nuggets)** — `NuggetProvider` service loads `neighborhood_facts.json` (28 facts: 18 neighborhood-specific with accurate stairway counts, 10 global SF stairway trivia). `NeighborhoodCard` shows a `checkmark.seal.fill` walkedGreen badge top-right when the neighborhood is 100% complete. `NeighborhoodDetail` progressSection shows "All X stairways walked ✓" label + walkedGreen progress bar on completion; shows a per-neighborhood fact in tertiary text below the progress bar regardless of completion state. `ProgressTab` shows a daily-rotating global fact (day-of-year seed, stable per session) below the summary ring. `MapTab` polygon rendering distinguishes completed neighborhoods: green fill (`Color.walkedGreen`) at 35% opacity + 65% stroke + 1.5pt lineWidth, instead of the neighborhood's assigned color.
- **Hard Mode Simplification** — Decoupled Hard Mode from Supabase auth. `setHardMode()` now only writes to UserDefaults — no Supabase network call. `loadProfile()` no longer overwrites the local Hard Mode preference from Supabase on sign-in. Hard Mode toggle in Settings has `.disabled(!authManager.isAuthenticated)` removed — always interactive. `ProgressTab` now computes `verifiedCount` from existing `walkRecords` query and appends "· N verified" to the neighborhood stats line when the user has at least one proximity-verified walk.
- **Share Card Redesign** — Full brand overhaul of `ShareCardView`. With-photo layout: 16pt brandAmber frame around inset photo; white `StairShape` + "SF Stairways" logo overlay on photo (dark pill for legibility on any background); neighborhood progress pill ("N of M") bottom-right corner of photo. No-photo layout: amber frame around brandOrange solid content area; stairway name + neighborhood in white inside the orange area; larger "N of M in [Neighborhood]" progress block. Bottom text panel (cream `#FAFAF7`): stairway name + neighborhood (photo variant only), height pill, "Walked ✓" pill, tagline, `sfstairways.app` URL in brandOrange.
- **Share Card** — `ShareCardView.swift` (new) renders a 1080×1920 portrait card via `ImageRenderer` at 3× scale.
- **Landing Page + Privacy Policy** — New `index.html` landing page. `privacy.html` covering SwiftData local storage, iCloud CloudKit, optional Supabase auth. Oscar will swap hero photo with original photography and update TestFlight URL when live.

### 2026-03-31
- **Remove Steps Tracking** — Removed `WalkRecord.stepCount` and `StairwayOverride.verifiedStepCount` from SwiftData models. Removed all step/stair count UI from iOS, macOS, and Admin. Height (ft) is the only physical metric.

### 2026-03-30
- **Neighborhood Color Saturation** — Increased polygon overlay opacity and replaced the 12-color pastel palette with more saturated equivalents.
- **Remove HealthKit & Walk Recording** — Deleted `HealthKitService.swift` and `ActiveWalkManager.swift` entirely. "Mark Walked" is now the only walk-logging action. WalkRecord legacy fields (`elevationGain`, `walkStartTime`, `walkEndTime`) retained in schema for CloudKit schema compatibility.

### 2026-03-29
- **Progress Tab Reframe** — Compact ring + 2-column `NeighborhoodCard` grid in `ProgressTab`; collapsible "Undiscovered" section.
- **Neighborhood Map Overlays + Detail View** — `MapPolygon` overlays for 117 neighborhoods; centroid label annotations; `NeighborhoodDetail` view with 4 navigation entry points.
- **Neighborhood 311 Migration** — Replaced DataSF GeoJSON with SF 311 Neighborhoods (117 hoods); re-migrated 382 stairways.
- **Neighborhood Foundation** — `NeighborhoodStore`, GeoJSON-backed centroids and adjacency.

### Earlier sessions
- **iOS Admin App**, **Visual refresh**, **Map label cleanup**, **UX fixes**, **Attribution & acknowledgements**, **macOS tag management**, **Urban Hiker SF data import**, **macOS photo add + notes editing**, **macOS Admin Dashboard**, **Photo sync**, **Active walk mode** (now removed), **HealthKit integration** (now removed).

## Known Issues

- **CloudKit schema:** SwiftDataError code 1 on first launch after new model types added means CloudKit schema needs deploying from Xcode to Dashboard (container: `iCloud.com.o4dvasq.sfstairways`). Error now shows a human-readable message in Settings.
- **macOS CloudKit sync:** first launch on Mac requires a few minutes for CloudKit to sync iOS walk data down.
- **CloudKit sync:** may fall back to local if Xcode target lacks Background Modes → Remote Notifications capability (manual Xcode step).
- **CKErrorDomain error 2** (not authenticated) surfaces as red error icon on Stats tab — requires CloudKit investigation.
- **supabase-swift** package not confirmed added to Xcode target membership.
- **Sign in with Apple:** `signInError` display is temporary for debugging.
- **Supabase Apple provider** config not yet manually verified.
- **Admin app Xcode target**: file memberships and capabilities must be manually verified in Xcode after pulling — the target config is in `project.pbxproj` but CloudKit + Background Modes capabilities require Signing & Capabilities UI.

## Repository

- sf-stairways (Dropbox) is the official project repository
- Xcode project: `ios/SFStairways.xcodeproj` (in repo)
- iOS source: `ios/SFStairways/` (Swift/SwiftUI)
- macOS source: `ios/SFStairwaysMac/` (Swift/SwiftUI, macOS)
- iOS Admin source: `ios/SFStairwaysAdmin/` (Swift/SwiftUI, iOS utility)
- See `docs/IOS_REFERENCE.md` for build details
