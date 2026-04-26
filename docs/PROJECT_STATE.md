# Project State — sf-stairways

_Last updated: 2026-04-26 (first-launch sign-in prompt)_

## Platforms

### iOS App (primary)
- Swift/SwiftUI/iOS 17+ with Map, List, Stats, and **Search** tabs
- SwiftData + CloudKit — container init with CloudKit configured; falls back to local-only with detailed error logging if CloudKit fails
- `SyncStatusManager` tracks live CloudKit event notifications; cloud icon in Stats tab shows sync state
- Supabase SDK integrated; `AuthManager` manages Sign in with Apple session
- Photo capture with thumbnails, location services
- Tags: **read-only pills for all users** (Add Tag removed from main app); full tag CRUD (add, rename, delete) is Admin/macOS-only; tag pills use a 12-color filled palette (`Color.tagPalette` in `AppColors`) with white text; each tag has a stable `colorIndex: Int`; `StairwayTag.id` has `@Attribute(.unique)` — CloudKit sync upserts instead of duplicating; `TagAssignment` has `compoundKey` field; one-time `runTagDedupMigrationIfNeeded` migration purges duplicates on first launch
- `StairwayStore` filters out deleted stairways via `applyDeletions(_:)` — map, list, search, progress all respect deletions
- **Visual design: light-first** — warm terracotta `brandOrange`, SF Pro Rounded for display text, `surfaceCardElevated` stat cards, orange progress ring
- **Neighborhoods: SF 311 Neighborhoods** — 117 granular neighborhoods (68 with stairways); powered by `NeighborhoodStore` (GeoJSON-backed, computes centroids + adjacency at startup)
- **No HealthKit, no active walk recording** — "Mark Walked" is the only walk-logging action. Tapping it fires a medium haptic and animates in a bold green banner. Banner shows stairway name (white bold .title3), neighborhood · N of M walked (.subheadline), date walked (.caption), large white checkmark (size 44, bounce animation). Tapping banner prompts to remove walk. Below banner: share icon and camera menu. The Hard Mode "Mark Anyway" path delays 0.3s before firing celebration.
- **Community climb counts** — `CommunityService` (`@Observable`) fetches per-stairway climber counts from Supabase `stairway_climb_counts` view on app launch; counts shown in `statsRow` as "N climbers" badge (only when > 0); sole-climber case shows "You're the first!" in brandOrange; `NeighborhoodDetail` shows aggregate "N total climbers across M stairways" below the progress bar; marking/removing walks fires `reportWalk`/`reportUnwalk` for authenticated users (fire-and-forget); unauthenticated users see no community data and do not write to Supabase
- **Photo carousel** — no "Photos" section heading; content renders directly.
- **Hard Mode** — UserDefaults-only preference; proximity check (150m) enforced at mark time; "Mark Anyway" override logs `proximityVerified = false`; Progress tab shows verified count only when > 0
- **Share card** — walked stairways show share button; tapping generates 1080×1920 portrait card via `ImageRenderer` at 3× scale; logo bottom-left, progress pill bottom-right
- **Neighborhood badges** — `NeighborhoodCard` shows `checkmark.seal.fill` badge when 100% complete. Completed neighborhoods on map get green polygon fill.
- **Discovery nuggets** — `NuggetProvider` loads `neighborhood_facts.json` (18 neighborhood-specific + 10 global facts). `NeighborhoodDetail` shows per-neighborhood fact below progress bar. `ProgressTab` shows daily-rotating global fact.
- **First-launch sign-in prompt** — `SignInPromptView` shown once per install (after brand splash), before the main app, for unauthenticated users. Shows three benefits (photo sync, achievements, community), privacy commitment, `SignInWithAppleButton`, and "Maybe later". Persisted via `@AppStorage("hasSeenSignInPrompt")`. Identity-merge for photos taken before signing in is a **known open follow-on** (separate spec needed).
- Successfully archived in Xcode on 2026-03-23
- See `docs/IOS_REFERENCE.md` for full build details

### iOS Admin App (`SFStairwaysAdmin`)
- **`ios/SFStairwaysAdmin/`** — separate iOS target in `SFStairways.xcodeproj`, bundle ID `com.o4dvasq.SFStairways.admin`
- Shares the same CloudKit container (`iCloud.com.o4dvasq.sfstairways`) — all override, tag, and deletion changes sync automatically
- **No photo management, no HealthKit, no Supabase** — utility-only curator tool
- **Tab-based navigation** — `AdminContentView` root: Map tab (`AdminMapTab`) + List tab (`AdminBrowser`)
- `AdminMapTab` — full-screen MapKit map; all stairways as colored circle pins with 4-state priority: red (has issues: missing height or coordinates) > blue (has override) > `walkedGreen` (walked) > `brandAmber` (default); filter menu (All/Has Issues/Has Overrides/Unwalked/Walked); labels at span < 0.02; tap pin → `AdminDetailView` sheet; `MapUserLocationButton`; Tag Manager in toolbar
- `AdminBrowser` — searchable list; filter chips (All/Walked/Unwalked/Has Override/Has Issues); sort by Name/Neighborhood/Date Walked; toolbar: Tag Manager + Removed Stairways
- `AdminDetailView` — detail view (push or sheet): catalog data (read-only), editable overrides, tag chips with add/remove, "Remove Stairway" destructive action
- `AdminTagManager` — modal: preset tags read-only with counts, custom tags inline rename and delete, create new tag
- `RemovedStairwaysView` — modal: list of `StairwayDeletion` records; swipe to restore
- **App icon** — wrench-badge variant (amber gradient + stair silhouette + dark badge upper-right with white wrench); light/dark/tinted variants

### macOS Admin Dashboard
- **`ios/SFStairwaysMac/`** — macOS target in `SFStairways.xcodeproj`, bundle ID `com.o4dvasq.SFStairways.mac`
- Shares the same CloudKit container as iOS — all walk data, overrides, tags, deletions sync automatically
- Three-column `NavigationSplitView`: sidebar (neighborhoods + tags filter) → sortable stairway table → detail panel
- **Deletion filtering**, **Sidebar Tags section**, **Table sorting** (Name, Height, Photos, Date Walked)
- Detail panel: catalog vs. walk data, editable curator overrides, notes editing, tag add/remove, photo grid
- Bulk Operations: bulk tag assign/remove, bulk mark walked, CSV export
- Data Hygiene sheet: flags missing height, missing coordinates, promotion candidates, proximity unverified
- No Supabase, no HealthKit on macOS

### Web (GitHub Pages)
- **Landing page** — `index.html` at repo root; static HTML, no JS dependencies
- **Domain** — `sfstairs.app` (GitHub Pages CNAME)
- **Privacy policy** — `privacy.html`; required for Apple external TestFlight distribution
- **Deprecated web app** — moved to `legacy/index.html`

## Current Data

| Metric | Value |
|---|---|
| Walked stairways | 8 |
| With photos | 0 |
| All SF stairways (catalog) | **382** |
| SF 311 Neighborhoods | **117** total, **68** with stairways |

## Recent Completions

### 2026-04-26
- **First-launch sign-in prompt** — New `SignInPromptView` shown once per install (after brand splash, before main TabView) for unauthenticated users. Three benefit rows (photo sync / achievements / community), privacy commitment text, `SignInWithAppleButton` (primary), "Maybe later" (secondary). `@AppStorage("hasSeenSignInPrompt")` persists flag. Sign-in success auto-dismisses via `onChange(of: authManager.isAuthenticated)`. Edge case handled: `onChange(of: authManager.isLoading)` shows prompt if auth check completes after splash dismisses. Cancelling Apple sheet returns user to prompt without setting flag. `SFStairwaysApp.swift` now carries `showSignInPrompt` and `hasSeenSignInPrompt` state.

### 2026-04-11
- **Community photo sharing + anonymous auth** — Photos taken by any user are now uploaded to Supabase and visible to all users. Root cause of prior failure: `addPhoto()` was gated on `authManager.userId`, which was nil for users who never signed in with Apple — uploads silently skipped. Fix: `AuthManager.signInAnonymously()` signs the user into Supabase anonymously (real UUID, no email/name) before upload. Anonymous auth is fire-and-forget; if it fails, photo stays local. One-time privacy consent dialog ("Share with SF Stairs Community? / No information identifying you will be shared.") shown on first photo, persisted via `@AppStorage("photoSharingConsented")`. Subsequent photos for a consented user skip the dialog. **Requires anonymous auth enabled in Supabase dashboard** (Authentication → Sign In / Providers → Anonymous sign-ins).
- **Multi-user walk visibility bug fix** — New test users were seeing Oscar's walked stairways pre-loaded on first launch. Root cause: `SeedDataService.seedIfNeeded()` loaded `target_list.json` (Oscar's personal walk history, bundled in the app binary) and inserted it as `WalkRecord` entries into any empty CloudKit private database. Fix: removed `seedIfNeeded()` call from `SFStairwaysApp.swift` and deleted the method + `SeedStairway` struct from `SeedDataService.swift`.

### 2026-04-04
- **Curator/User Feature Separation** — Tags read-only for all users in main app; `CommunityService` climb counts; `climberCountBadge` in stats row.
- **Admin App Map & Editing Upgrade** — `AdminContentView` (TabView) root; 4-state color pins; filter menu; admin app icon updated.

### 2026-04-03
- **Celebration v3** — instant banner + confetti + heavy haptic
- **Tag Deduplication**, **Walked Card Polish**, **Domain Update** (sfstairs.app), **Nearby Filter Recenters Map**, **Walked Card Redesign**, **Tag Pill Colors**, **SF Stairs Rebrand**, **Splash Image Update**

### 2026-04-02
- **Progress Count Bugfix**, **Mark Walked Celebration**, **Neighborhood Rewards**, **Hard Mode Simplification**, **Share Card Redesign**

### Earlier sessions
- **iOS Admin App**, **Visual refresh**, **Map label cleanup**, **UX fixes**, **Attribution & acknowledgements**, **macOS tag management**, **Urban Hiker SF data import**, **macOS Admin Dashboard**, **Photo sync**, **Neighborhood 311 Migration**, **Neighborhood Map Overlays**, **Progress Tab Reframe**

## Known Issues

- **CloudKit schema:** SwiftDataError code 1 on first launch after new model types added — deploy schema from Xcode to CloudKit Dashboard.
- **macOS CloudKit sync:** first launch on Mac requires a few minutes for CloudKit to sync iOS walk data down.
- **CKErrorDomain error 2** (not authenticated) surfaces as red error icon on Stats tab.
- **supabase-swift** package not confirmed added to Xcode target membership.
- **Sign in with Apple:** `signInError` display is temporary for debugging.
- **Supabase schema (community):** `stairway_walk_events` table + `stairway_climb_counts` view + RLS policies must be created manually in Supabase SQL editor.
- **Anonymous auth must be enabled in Supabase dashboard** (Authentication → Sign In / Providers → Anonymous sign-ins) for community photo uploads to work for non-Apple-signed-in users.
- **Anonymous-user photo identity merge** — photos uploaded before a user signs in with Apple are owned by their anonymous Supabase UUID. If they later sign in with Apple, those photos remain under the old identity. Migrating ownership requires Supabase-side identity linking — open follow-on spec (`SPEC_anonymous_to_apple_identity_upgrade`).
- **Admin app Xcode target**: file memberships and capabilities must be manually verified in Xcode after pulling.

## Repository

- sf-stairways (Dropbox) is the official project repository
- Xcode project: `ios/SFStairways.xcodeproj` (in repo)
- iOS source: `ios/SFStairways/` (Swift/SwiftUI)
- macOS source: `ios/SFStairwaysMac/` (Swift/SwiftUI, macOS)
- iOS Admin source: `ios/SFStairwaysAdmin/` (Swift/SwiftUI, iOS utility)
- See `docs/IOS_REFERENCE.md` for build details
