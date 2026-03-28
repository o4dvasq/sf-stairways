# Architecture Decisions — sf-stairways

## Map pin tap targets and zoom-responsive scaling
**Date:** 2026-03-28

**Tap targets via contentShape, not padding.** The tap gesture lives on `StairwayAnnotation` in `MapTab`. The cleanest way to expand the hit area without changing MapKit annotation layout is to wrap the visual circle in an outer frame of `max(44, pinSize)` and apply `.contentShape(Rectangle())` at that outer frame. Using `.padding()` + `.contentShape(Circle())` was rejected because a circular content shape at 44pt on a 12pt pin leaves the corners dead — a rectangular content shape fills the minimum 44×44pt area uniformly and matches Apple HIG intent.

**Scale factor via lerp, not discrete steps.** Pin size was mapped continuously from 1.0 (city view, `latitudeDelta >= 0.05`) to 2.0 (street level, `latitudeDelta <= 0.005`) using linear interpolation. Discrete size breakpoints (e.g., small/medium/large) would produce visible pops on pinch-zoom. The lerp is a one-line clamp + ratio — trivial to compute on every camera change.

**`.onMapCameraChange(frequency: .continuous)` over `.onEnd`.** Continuous firing gives smooth scale transitions during pinch. The scale computation is a clamp + multiply — no meaningful CPU cost at this granularity. `.onEnd` would cause pins to snap size only after the gesture finishes, which reads as a layout jump.

## Curator promote flow: triggerPromote binding over direct scroll
**Date:** 2026-03-28

The "Promote to Commentary" button in the notes section needed to pre-fill the `CuratorEditorView` with the current note text. Two options considered:

**Option A:** Pass a `promotedNotesText` state down and have the editor load it on appear. Problem: the editor already uses `.onAppear` to load existing Supabase commentary, and competing initializers create ordering ambiguity.

**Option B (chosen):** `@Binding var triggerPromote: Bool` on `CuratorEditorView`. The parent sets it to `true`; the editor's `.onChange` copies `notesText → draftText` and resets the flag to `false`. This is a minimal one-shot signal — no stored value to clean up, no state ambiguity, and compatible with the existing `onAppear` + `onChange(of: service.commentary)` loading logic.

The editor also moved below the notes section (was above). With `ScrollViewReader`, tapping "Promote" scrolls the view down to the editor anchor, making the pre-fill immediately visible.

## Expandable bottom sheet replaces two-view map flow
**Date:** 2026-03-28

The previous map flow used two views: `StairwayBottomSheet` (compact, at `.height(390)`) with a NavigationLink that pushed `StairwayDetail` into a NavigationStack. `StairwayDetail` had its own mini-map at the top — which was redundant since the stairway pin is already visible on the map behind the sheet.

The new design consolidates everything into a single `StairwayBottomSheet` with two sheet detents (`.height(390)` and `.large`). The map itself is the "detail map" — it's always visible behind the collapsed sheet. The expanded sheet (dragged to `.large`) reveals notes, photos, commentary, and curator tools.

**Why self-contained rather than callback-based.** The old bottom sheet received `walkRecord`, `override`, and four action callbacks from `MapTab`. This meant MapTab owned all write logic and the sheet was stateless. The new sheet adds `@Query` and `@Environment(\.modelContext)` directly, owns all write logic, and uses `@Environment(\.dismiss)` to self-dismiss on remove. This removes the callback coupling entirely and lets `ListTab` use the same sheet with zero extra wiring.

**Why the same sheet for ListTab.** `ListTab` previously had a `NavigationLink → StairwayDetail`. Replacing it with `Button → selectedStairway → .sheet(item:)` using `StairwayBottomSheet` means there is now exactly one detail surface in the app. Future changes to detail UI need to happen in one place only.

**`StairwayDetail.swift` deleted.** All content was absorbed into `StairwayBottomSheet`. The mini-map (the only unique element) was intentionally dropped — it was redundant with the map tab itself.

## Map pins: circles replace teardrops; three-state color system restored
**Date:** 2026-03-27

`TeardropShape` inside `StairwayPin` rendered poorly in MapKit's `Annotation` container at small sizes — the rounded top of the teardrop lost definition against the dark map, and the point was clipped. After two rounds of size/shadow tuning, the teardrop was abandoned entirely. `Circle()` is reliable, renders crisply at all sizes, and needs no custom `Shape` path.

Three-state colors were restored (they had been collapsed to solid orange in a prior session): gray `Color(white: 0.55)` for unsaved, `brandOrange` for saved, `walkedGreen` for walked. Selected state uses a darker variant and expands to 24pt. The rationale for collapsing to solid orange (state visible in detail, not map) was valid, but the circles are small enough (12–16pt) that color is the primary legibility signal at map scale — state differentiation is worth the three-color palette at this size.

`TeardropShape` and `StairShape` are kept in `TeardropPin.swift` for future use.

## Curator section gated on curator role, not just walked state
**Date:** 2026-03-27

The "Stairway Info" editor in `StairwayDetail` (stair count, height, description TextFields) was gated only on `isWalked`. This caused every walked stairway to show editable fields with "Add stair count" / "Add height" / "Add description..." prompts to all users — it looked like the app was asking users to manually enter catalog data.

The fix is a single condition change: `if isWalked` → `if isWalked && authManager.isCurator && curatorModeActive`. The `statsRow` already correctly shows public catalog data (`Stairway.heightFt`) and override data with a verified badge for all users — that path is unchanged.

## Auth error surfacing: signInError for Sign in with Apple debugging
**Date:** 2026-03-27

Sign in with Apple was failing silently — the catch block in `handleAppleAuthorization` only printed to the console, giving no visible feedback on device. Added `signInError: String?` as a published property on `AuthManager`. The catch block sets it to `error.localizedDescription`; `SettingsView` renders it in red below the sign-in button.

This is a temporary debug instrument. Once Sign in with Apple is confirmed working (Supabase provider config verified, sign-in completes successfully), remove the `signInError` display from `SettingsView` and clear the property after successful sign-in.

## Sign in with Apple: use SwiftUI button credential directly, no second ASAuthorizationController
**Date:** 2026-03-27

`SignInWithAppleButton` (SwiftUI) delivers the `ASAuthorization` credential in its `onCompletion` handler. The original implementation discarded this credential (`_ in`) and called `authManager.signInWithApple()`, which created a second `ASAuthorizationController` — the second request silently failed or was ignored, leaving the user perpetually signed out.

The fix is to handle the credential where it's delivered: extract the identity token from the `ASAuthorizationAppleIDCredential` in `onCompletion` and pass it directly to `AuthManager.handleAppleAuthorization(_:)`. No second controller is needed. The existing `ASAuthorizationControllerDelegate` implementation is kept for the fallback path but is no longer the primary flow.

## Map pins: remove white shadow, add dark stroke, increase minimum sizes
**Date:** 2026-03-27

White shadow (`.shadow(color: .white.opacity(0.3), radius: 3, y: 0)`) was added in a prior session to give pins visual "lift" on a dark map. In practice it created a hollow/washed-out appearance — the white halo overwhelmed the orange fill at small pin sizes. Removed.

A thin dark stroke (`.stroke(Color.black.opacity(0.4), lineWidth: 1)`) was added instead — this defines the pin edge against the dark map without washing out the fill color.

Pin sizes increased: unsaved 36×45pt, saved/walked 40×50pt, selected 48×60pt (from 30×38 / 36×45 / 42×53). At the previous sizes the teardrop shape was too small to read as a teardrop at typical map zoom levels.

## Web app deprecated in favor of iOS-only
**Date:** 2026-03-25

The web app (`index.html`) was a prototype that proved out the concept: interactive map of SF stairways with walk logging. Now that the iOS app has feature parity and native advantages (camera, GPS, CloudKit sync, offline), maintaining two codebases for one user provides no value. The iOS app is the sole platform going forward. `index.html` remains in the repo for reference but receives no further development.

## Three-state stairway model (Unsaved / Saved / Walked) replaces target list
**Date:** 2026-03-25

The original "target list" was a static JSON file with 13 pre-selected stairways. This was a bootstrapping mechanism, not a real feature. The three-state model makes saving dynamic: users discover stairways on the map and bookmark them for later. The existing `WalkRecord` model already supports this — a record with `walked = false` is the "Saved" state. No schema change needed. This also lays the groundwork for future gamification (progress tracking, completion percentages, streaks) without requiring another data model change.

## MapKit over Mapbox for iOS
**Date:** 2026-03-25

The original web-focused spec proposed Mapbox GL JS. For iOS, MapKit is the right choice: it's free with no usage limits, already integrated, handles pin annotations natively, and integrates with Core Location. Mapbox iOS SDK would add a CocoaPod/SPM dependency, a token management requirement, and usage-based billing, all for capabilities MapKit already provides.

## Pre-computed neighborhood adjacency over runtime polygon intersection
**Date:** 2026-03-25

The "Around Me" feature needs to know which SF neighborhoods border the user's current neighborhood. Computing polygon intersections at runtime (the Turf.js approach from the web spec) is unnecessary overhead on a mobile device. Instead, a Python build script pre-computes the adjacency map once and bundles it as static JSON. The app does a simple dictionary lookup at runtime. Simpler, faster, no geometry library needed in Swift.

## Centroid-based neighborhood detection over GeoJSON point-in-polygon
**Date:** 2026-03-25

The spec originally called for DataSF neighborhood polygons and point-in-polygon lookup to determine the user's current neighborhood. The DataSF "Analysis Neighborhoods" dataset (37 neighborhoods) does not match the stairway data's 53 neighborhood names (sourced from sfstairways.com scraper). Rather than maintain a mapping between two neighborhood schemas, we use nearest-centroid detection: the centroid of each neighborhood is computed from its stairways' coordinates, and the user's neighborhood is the one with the nearest centroid. This is more accurate for this specific dataset, requires no external polygon data, and the Python build script generates `neighborhood_centroids.json` from `all_stairways.json` directly.

## Single-file HTML app (no build step)
**Date:** 2026-03-22 [retroactive]

The entire app lives in `index.html` — HTML, CSS, and JS in one file. No bundler, no npm, no dependencies to install. This keeps local dev trivially simple (`python3 -m http.server 8080`) and GitHub Pages deployment instant (just push). The app is small enough that a single file is easy to navigate, and there's no team coordination overhead to justify a build pipeline.

## Leaflet.js over Google Maps
**Date:** 2026-03-22 [retroactive]

Leaflet is free with no API key required, which eliminates key management and billing risk for a personal project. OpenStreetMap tiles are sufficient for stairway navigation. Google Maps would add complexity (billing account, key restrictions) without any meaningful benefit at this scale.

## GitHub Contents API for persistence (no backend)
**Date:** 2026-03-22 [retroactive]

Walk data is written directly from the browser to `data/target_list.json` using the GitHub REST API. The user stores a Personal Access Token in `localStorage`. This gives us durable, version-controlled persistence with zero infrastructure. No server, no database, no hosting costs. The tradeoff is that the GitHub PAT needs repo write scope and is per-device, but for a single-user personal app this is fine.

## Cloudinary for photo storage (free tier, unsigned uploads)
**Date:** 2026-03-22 [retroactive]

Photos are uploaded directly from the browser to Cloudinary using an unsigned upload preset — no API secret needed in the app. Cloudinary's free tier (25 GB storage, 25 GB bandwidth/month) is more than sufficient for a personal stairway photo collection. The Cloudinary URL is written back to `target_list.json` via the existing GitHub API flow.

## Multi-user backend: Supabase
**Date:** 2026-03-23

Supabase (PostgreSQL + Auth + Storage) chosen over CloudKit public database and Firebase for the multi-user App Store version. CloudKit public DB was rejected because it requires users to be signed into iCloud (drops off potential users), has no real access control layer, and has no path for server-side logic. Firebase was rejected due to Google ecosystem lock-in and unpredictable per-read pricing. Supabase provides Row Level Security for per-user data isolation, Sign in with Apple support, S3-compatible photo storage, and a free tier that covers 0–100 users at zero cost. PostgreSQL means no vendor lock-in. See `docs/ARCHITECTURE_MULTI_USER.md` for full rationale and schema.

## Multi-user auth: Sign in with Apple via Supabase
**Date:** 2026-03-23

Sign in with Apple is the primary auth method, required by App Store guideline 4.8 whenever a third-party login is offered. Supabase handles the Apple identity token validation server-side — the iOS app sends the token from ASAuthorizationAppleIDButton and Supabase returns a session JWT. Email/password login is available as a fallback. The app works in local-only mode before sign-in; sign-in is optional, not a hard gate on first launch.

## Multi-user photo storage: Supabase Storage → Cloudflare R2
**Date:** 2026-03-23

Photos are stored in Supabase Storage (S3-compatible, included in free tier) for the initial launch. Migration trigger to Cloudflare R2 is set at ~1K users or when monthly storage costs exceed $10. R2 has zero egress fees, which is the critical advantage for a photo-heavy app at scale. The storage path structure (`photos/{user_id}/{walk_record_id}/{photo_id}.jpg`) is the same in both backends — migration is a bucket URL swap, not a schema change.

## CloudKit sync guard: record count check over UserDefaults-only
**Date:** 2026-03-23

`SeedDataService.seedIfNeeded` previously used only a `UserDefaults` flag to prevent re-seeding. The flag is device-local, so on a fresh install or reinstall the app would re-seed even if CloudKit was about to deliver existing records from another device. Changed to check `fetchCount(FetchDescriptor<WalkRecord>())` first — if any records exist (from any source), seeding is skipped. UserDefaults flag is kept as a secondary guard for the case where records were intentionally deleted. The count check handles CloudKit delivery timing; the UserDefaults flag handles deliberate deletion.

## SyncStatusManager: NSPersistentCloudKitContainer notifications with SwiftData
**Date:** 2026-03-23

SwiftData with CloudKit still posts `NSPersistentCloudKitContainer.eventChangedNotification` via its underlying CoreData stack. `SyncStatusManager` listens to these notifications and exposes state (`unknown`, `syncing`, `synced(Date)`, `unavailable`, `error`) as `@Observable`. The manager is created in `SFStairwaysApp.init()` and injected via `.environment()` so any view can read it without prop drilling. The sync indicator lives in the Progress tab toolbar — natural home for system status in a single-user app.

## Data scraping approach (sfstairways.com + Nominatim fallback)
**Date:** 2026-03-22 [retroactive]

`scripts/scrape_stairways.py` is a one-time script that builds `data/all_stairways.json`. It first attempts to extract lat/lng from each stairway's page on sfstairways.com (Google Maps embeds, JS variables, JSON-LD). If that fails, it falls back to Nominatim geocoding. Records with no coordinates get `lat: null, lng: null` and are silently skipped by the app. The result is committed to the repo — no live scraping at runtime.

## Map Visual Refresh v2: amber palette, unified stair icon, top bar, dark map
**Date:** 2026-03-26

Four related visual decisions bundled in one session:

**Amber replaces orange for pins.** The original saved-pin color (#E8602C orange) was too warm/harsh against the map. Warm amber (#D4882B) reads more like a "destination" marker and meshes better with the yellow-to-brown app icon gradient. `brandOrange`/`brandOrangeDark` removed from AppColors; `brandAmber`/`brandAmberDark` replace them everywhere.

**Light green (#81C784) for saved, green (#4CAF50) for walked.** Differentiating saved vs. walked visually was the goal of the three-state model, but the original palette (orange saved, green walked) reads as a traffic-light signal (bad vs. good) rather than a progress continuum. Light green saved → full green walked communicates "on the way there" more naturally.

**Unified stair icon on all three pin states.** The original design showed no icon for unsaved, a stair icon for saved, and a checkmark for walked. The checkmark was borrowed from task-manager conventions that don't apply here — this is a discovery app, not a to-do list. The stair icon is the brand mark; showing it on every pin reinforces identity and makes all states visually consistent. The 50% opacity on unsaved pins already signals "not engaged" without needing to remove the icon entirely.

**White top bar replaces bottom search bar.** Bottom-anchored search bars are native on iOS but they compete with the home indicator and feel like a navigation bar in the wrong place. Moving search + Around Me to a top bar frees the bottom of the screen for the detail sheet, which slides up from below. The white top bar also provides natural contrast against the dark map — the design reads as layers (dark base → white controls → map content).

**Dark map via `.preferredColorScheme(.dark)` scoped to the Map view.** Applied directly to the `Map` SwiftUI view so only the map renders in dark mode — the rest of the UI (sheets, search panel, list tab) is unaffected. MapKit's standard dark basemap (charcoal/slate streets on near-black) is accepted as-is per the spec constraint that no custom tile overlay be introduced.

## Nav bar redesign: brandOrange unified color, progress card header
**Date:** 2026-03-26

`brandOrange` (#E8602C) is now the single orange token for all non-splash UI. The top nav bar moved from white to `brandOrange` — white-on-orange is a cleaner brand statement than the previous amber title on white, and removes the drop shadow that was needed to lift a white bar off a dark map. Button circles changed from `.systemGray5` to `Color.white.opacity(0.2)` (subtle on orange, consistent with active-state contrast).

The floating progress card gained a `brandOrange` header bar ("Progress" in white). The card previously had no label, relying on icon-free stats to identify themselves. A labeled header at 4pt vertical padding adds just enough context without bloating the card.

`accentAmber` (#E8A838) is reserved for splash screen only; it will be reintroduced for unverified badges in the Hard Mode spec.

## Hard Mode: per-stairway proximity-gated walk verification
**Date:** 2026-03-26

Hard Mode is an opt-in per-stairway feature that gates the Mark Walked action on the user being within 150m of the stairway. This was designed as purely client-side (no server verification, no CLRegion geofencing) to keep it lightweight and offline-capable.

**Why per-stairway rather than global.** A global Hard Mode toggle would be disruptive — enabling it would suddenly disable Mark Walked for all stairways and could create a poor experience if the user is away from home. Per-stairway allows selective enforcement on stairways the user specifically wants to verify in-person.

**Why proximity is checked at render time, not via geofence events.** CLRegion geofencing adds background entitlements, battery impact, and region limit (20 regions). For a 150m check on a stairway the user is actively viewing, render-time evaluation against `LocationManager.currentLocation` (updated every 50m) is sufficient and introduces no background activity.

**`proximityVerified: Bool?` instead of `Bool`.** The three-value semantics — nil (Hard Mode never enabled), false (pre-existing unverified walk), true (verified in-person) — carry historical meaning that a plain Bool would collapse. `nil` means "Hard Mode was never involved"; `false` means "Hard Mode was retroactively applied to an existing walk." Callers distinguish these with `showUnverifiedBadge` (requires `hardMode && walked && proximityVerified == false`), not by inspecting the raw value directly.

**Unverified badge uses `accentAmber` (#E8A838), distinct from `brandAmber` (#D4882B).** The badge needs to read on top of a green walked pin. Using the same amber as unsaved pins would create confusion ("is this an unsaved pin?"). `accentAmber` was already defined for the splash screen and is visually distinct at 12pt.

## UI Improvements v2: slimmer nav bar, icon-free pins, detail mini-map, Save action
**Date:** 2026-03-27

**Nav bar icon instead of text.** "SF Stairways" text was removed and replaced with a centered white `StairShape` icon (26×26pt) in the orange top bar. The text added no information the user doesn't already know from the app icon. The stair silhouette reinforces brand identity and keeps the bar uncluttered. Bar height reduced (10→6pt vertical padding) to give more map real estate.

**Icon removed from pins.** The `StairShape` icon inside the pin bulb was removed. At the reduced pin sizes the icon was visually noisy without providing meaningful state information — state is already communicated by pin color (amber / light green / green). Solid teardrop shapes are simpler and cleaner at small sizes.

**ProgressCard width corrected.** The orange "Progress" title bar was expanding to full screen width because the outer `VStack` had no width constraint and the header `HStack` contained a `Spacer`. Fixed by moving `frame(width: 120)` to the outer `VStack` so both the header and content rows are constrained to 120pt.

**StairwayDetail: mini-map replaces photo carousel.** The photo carousel at the top of the detail screen was a placeholder (showed "No photos yet" for most stairways). A non-interactive `Map` showing the stairway's location is more immediately useful — the user can orient themselves before navigating. Map is `allowsHitTesting(false)` to prevent accidental gestures in a scroll context. Falls back to a grey placeholder for the small number of stairways without coordinates.

**Save button added to StairwayDetail toolbar.** The only way to save a stairway was via the map bottom sheet. The detail screen (reached via the list) had no save action. A "Save" button now appears in the toolbar when `walkRecord == nil`, creating a `WalkRecord(walked: false)` on tap. Disappears once the record exists.

## StairwayOverride: independent model, not a WalkRecord extension
**Date:** 2026-03-27

The curator data (verified step count, height, description) is stored in a separate `StairwayOverride` model keyed by `stairwayID`, not as fields on `WalkRecord`. Two reasons:

**Different ownership semantics.** `WalkRecord` is personal walk data — when did I walk it, what did I note. `StairwayOverride` is authoritative stairway facts that exist independently of any particular walk. If Oscar re-walks a stairway and creates a new `WalkRecord`, the verified stairway facts shouldn't be attached to either walk specifically.

**Override persistence on unmark.** The spec requires that verified data survives if a walk is unmarked. If the override were embedded in `WalkRecord`, the delete-record path would need special logic to preserve it. As an independent model, unmarking a walk simply hides the curator section — the override record is untouched.

The constraint is enforced in app logic (find-or-create by `stairwayID`) rather than a database unique constraint, since CloudKit doesn't support unique constraints on SwiftData models.

## Solid orange pins: drop three-state color differentiation
**Date:** 2026-03-27

All map pins now use `brandOrange` (#E8602C) regardless of state (unsaved / saved / walked). The three-state color system (amber / light green / green) was dropped.

**Why.** The three colors added visual complexity without clearly communicating actionable information at a glance. Users don't need to know at map scale whether a stairway is "saved" vs "walked" — they navigate to individual stairways and the detail/bottom-sheet tells them the state. The uniform orange palette is simpler, consistent with the app's brand color, and eliminates the need to remember color meanings.

State information is still fully preserved in the data model and surfaces in the detail view, bottom sheet, and list tab. Selected pins use `brandOrangeDark` (#BF4A1F). Closed stairways retain `unwalkedSlate` for functional distinction.

The stair icon was also removed from the MapTab nav bar in this same session — the orange bar is now plain, consistent with the icon-free pin design.

## Supabase iOS integration: AuthManager as @Observable NSObject
**Date:** 2026-03-27

`AuthManager` is an `@Observable final class` that also subclasses `NSObject`. The `NSObject` inheritance is required to conform to `ASAuthorizationControllerDelegate` and `ASAuthorizationControllerPresentationContextProviding` — both are ObjC protocols that require `NSObject`. `@Observable` and `NSObject` are compatible; the observation machinery is implemented via property-wrapper expansion, not class hierarchy.

**Session restore on init rather than via `.task` modifier.** Session restoration is triggered from `AuthManager.init()` via a detached `Task`. This avoids the view-lifecycle coupling of `.task {}` — `AuthManager` is created in `SFStairwaysApp.init()` alongside `SyncStatusManager`, so the Keychain check begins immediately, before any view appears. `isLoading = true` during the async check prevents the UI from flashing a "not signed in" state before the session is confirmed.

**Auth state changes subscribed via `authStateChanges` async stream.** Supabase SDK exposes `supabase.auth.authStateChanges` as an `AsyncStream` of `(AuthChangeEvent, Session?)` pairs. This handles token refresh, sign-out from another device, and session expiry automatically without polling. The stream subscription runs in a retained `Task` stored on `AuthManager` and is cancelled in `deinit`.

**`SettingsView` is a sheet, not a tab.** Auth settings are placed behind a gear icon in the ProgressTab toolbar rather than as a fourth tab. A tab implies a primary feature; settings are secondary. The iCloud sync status was previously only in a sheet triggered by the cloud icon — the gear icon brings the two system-level concerns (iCloud + Supabase auth) together in one place and cleans up the toolbar.

## Pin Visibility Fix: custom StairShape, 2x sizes, full opacity unsaved
**Date:** 2026-03-26

**Custom `StairShape` over SF Symbol `"stairs"`.** The SF Symbol `"stairs"` renders as 5 descending steps — the wrong count and the wrong direction. A custom SwiftUI `Shape` (added to `TeardropPin.swift`) draws exactly 3 ascending steps (left-to-right, climbing up), matching the app icon silhouette. The shape is a solid-fill path: no stroke, no scaling ambiguity, crisp at any pin size.

**Pin sizes doubled.** The original 24–34pt range was too small on a dark map where there is no white background to provide contrast. New range: 38pt (unsaved), 44pt (saved/walked), 52pt (selected). Icon ratio bumped from 38% to 42% of pin width. At these sizes the stair icon is legible even at city-wide zoom.

**Full opacity on unsaved pins.** `Color.brandAmber.opacity(0.5)` on unsaved pins was nearly invisible on the dark map — transparency that reads as "de-emphasized" on white reads as "ghost" on dark. States are now differentiated by hue only (amber / light green / green), not transparency. Transparency is reserved for the `isDimmed` and `isClosed` states via the `opacity` modifier on the outer container.

**Shadow updated for dark backgrounds.** Single dark shadow (`radius: 2, opacity: 0.2`) was invisible on a dark map. Replaced with a two-layer shadow: white glow (radius 3, opacity 0.3) for lift, plus black drop (radius 2, opacity 0.3, y: 2) for depth.
