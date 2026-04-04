# Project State — sf-stairways

_Last updated: 2026-04-03 (domain-update complete)_

## Platforms

### iOS App (primary)
- Swift/SwiftUI/iOS 17+ with Map, List, Stats, and **Search** tabs
- SwiftData + CloudKit — container init with CloudKit configured; falls back to local-only with detailed error logging if CloudKit fails
- `SyncStatusManager` tracks live CloudKit event notifications; cloud icon in Stats tab shows sync state
- Supabase SDK integrated; `AuthManager` manages Sign in with Apple session
- Photo capture with thumbnails, location services, seed data import
- Tags: display, filter, add, and create on iOS; full CRUD (rename, delete) on macOS/Admin only; tag pills use a 12-color filled palette (`Color.tagPalette` in `AppColors`) with white text; each tag has a stable `colorIndex: Int` (random on creation, sequential for preset seeds)
- `StairwayStore` filters out deleted stairways via `applyDeletions(_:)` — map, list, search, progress all respect deletions
- **Visual design: light-first** — warm terracotta `brandOrange`, SF Pro Rounded for display text, `surfaceCardElevated` stat cards, orange progress ring
- **Neighborhoods: SF 311 Neighborhoods** — 117 granular neighborhoods (68 with stairways); powered by `NeighborhoodStore` (GeoJSON-backed, computes centroids + adjacency at startup)
- **No HealthKit, no active walk recording** — "Mark Walked" is the only walk-logging action. Tapping it fires a medium haptic and animates in a bold green banner at the top of the bottom sheet. Banner shows stairway name (white bold .title3), neighborhood · N of M walked (.subheadline, white), date walked (.caption, white), and a large white checkmark (size 44, bounce animation driven by `celebrationTrigger`). Banner slides in via `.move(edge: .top).combined(with: .opacity)`. Tapping the banner triggers the "Remove Walk" alert. Below the banner: share icon and camera menu in one icons row (no date-edit pencil). The Hard Mode "Mark Anyway" path delays 0.3s after alert dismiss before firing celebration. The whole-sheet `surfaceWalked` green tint has been replaced by the banner.
- **Photo carousel** — no "Photos" section heading; content (thumbnails + "Add a photo" button) renders directly. Same in `NeighborhoodDetail`.
- **Hard Mode** — UserDefaults-only preference (no Supabase sync); toggle always enabled in Settings regardless of auth state; proximity check (150m) enforced at mark time; "Mark Anyway" override logs `proximityVerified = false`; Progress tab shows verified count only when > 0
- **Share card** — walked stairways show a share button (`square.and.arrow.up`, brandOrange) in the bottom sheet header; tapping generates a 1080×1920 portrait card via `ImageRenderer` and opens the native iOS share sheet. Card is branded: brandAmber frame around inset photo, white `StairShape` + "SF Stairs" logo overlay (dark pill) **bottom-left**, neighborhood progress pill ("N of M") bottom-right — both pills are in the bottom portion of the photo, safe from Messages and Instagram Post center crops. No-photo variant uses brandOrange solid content area with stairway name + progress in white.
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
- **Domain** — `sfstairs.app` (GitHub Pages CNAME); og:url in `index.html` updated
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
- **Walked Card Polish** — Banner now shows date walked (`.caption`, white) below the neighborhood line. Neighborhood line updated to "Ashbury Heights · 2 of 10 walked" format. Pencil / edit-date button removed from icons row. `editingDate` state var and DatePicker block removed. "Photos" section heading removed from `PhotoCarousel.swift` (visible in `StairwayBottomSheet`) and from `NeighborhoodDetail.swift`.
- **Domain Update** — All `sfstairways.app` references updated to `sfstairs.app`: `ShareCardView.swift` (share card URL text), `StairwayBottomSheet.swift` (share sheet text), `index.html` (og:url), `CNAME` (GitHub Pages custom domain). External steps (DNS, App Store Connect) are Oscar's manual tasks.

- **Nearby Filter Recenters Map** — Tapping the "Nearby" filter pill now also moves the camera to the user's current location at span 0.025 (covers the 1500m filter radius). Implemented by extending the existing `.onChange(of: filter)` handler in `MapTab.swift` to call `flyToUserLocation(_:)` when `newValue == .nearby`. If location is unavailable the guard fails silently — no crash, no camera move. Switching to "All" or "Walked" does not move the camera.

- **Walked Card Redesign** — `StairwayBottomSheet` walked state now uses a bold full-width green banner instead of the previous inline card + sheet-tint approach. Banner: `Color.walkedGreen` background, white stairway name (.title3 bold), neighborhood · N of M progress (.subheadline), large white `checkmark.circle.fill` (size 44) right-aligned. Proximity-unverified walks show an amber `xmark.seal.fill` next to the checkmark. Tapping the banner prompts to remove the walk. Below the banner: icons row (share, camera menu, pencil for date edit, height stat). Section headings "My Notes" and "Tags" removed in both walked and unwalked states; `+ Add Note` and `+ Add Tag` actions remain. `surfaceWalked` whole-sheet tint removed. Banner animates in with `.move(edge: .top).combined(with: .opacity)` on mark, driven by `.animation(.easeInOut(duration: 0.4), value: isWalked)`. Removed `walkStatusCard` and `neighborhoodProgressLine` computed properties (inlined into banner).
- **Celebration Animation Bug Fix** — The "Mark Walked" celebration (haptic + green background + checkmark bounce) was not firing in practice. Two bugs: (1) `withAnimation` was wrapping only `modelContext.save()`, but SwiftData's `@Query` update fires on `record.walked = true`, before save — so no active animation context when `isWalked` flipped; (2) the Hard Mode "Mark Anyway" alert dismissal animation was swallowing the celebration. Fix: introduced `@State private var celebrationTrigger = 0`; `markWalked()` now saves first, then fires haptic + `withAnimation { celebrationTrigger += 1 }`; `symbolEffect(.bounce)` is driven by `celebrationTrigger` instead of `isWalked` (more reliable since the icon is newly inserted when `isWalked` first becomes true, making the before/after change invisible to the effect). "Mark Anyway" button now wraps `markWalked` in `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)`.
- **Tag Pill Colors** — `StairwayTag` model gains `colorIndex: Int = 0` (lightweight SwiftData migration; existing tags default to rose). `Color.tagPalette` (12 colors) added to `AppColors.swift`; warm yellow + lemon darkened ~15% for white text contrast. Tag pill rendering updated in all 4 surfaces: `StairwayBottomSheet` (filled, white text), `TagEditorSheet` (full color when assigned, 35% opacity when unassigned; random color assigned on creation), `TagFilterSheet` (filled, active state shown with white stroke overlay), `SearchPanel` tag grid (filled, count in translucent white). `SeedDataService` assigns sequential colors (0–11) to preset tags for visual variety out of the box. The "+ Add Tag" dashed outline button is unchanged.
- **SF Stairs Public Rebrand** — Changed all user-visible "SF Stairways" text to "SF Stairs" and "Climb every stairway" to "Climb every stair". Changed files: `ShareCardView.swift` (logo text + tagline), `StairwayBottomSheet.swift` (share sheet text), `index.html` (title, og/twitter tags, h1, tagline, footer), `privacy.html` (all 10+ instances via replace-all). Internal identifiers (`SFStairways` project name, bundle ID, CloudKit container, Swift types) unchanged.
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
