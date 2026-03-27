# Architecture Decisions — sf-stairways

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

## Pin Visibility Fix: custom StairShape, 2x sizes, full opacity unsaved
**Date:** 2026-03-26

**Custom `StairShape` over SF Symbol `"stairs"`.** The SF Symbol `"stairs"` renders as 5 descending steps — the wrong count and the wrong direction. A custom SwiftUI `Shape` (added to `TeardropPin.swift`) draws exactly 3 ascending steps (left-to-right, climbing up), matching the app icon silhouette. The shape is a solid-fill path: no stroke, no scaling ambiguity, crisp at any pin size.

**Pin sizes doubled.** The original 24–34pt range was too small on a dark map where there is no white background to provide contrast. New range: 38pt (unsaved), 44pt (saved/walked), 52pt (selected). Icon ratio bumped from 38% to 42% of pin width. At these sizes the stair icon is legible even at city-wide zoom.

**Full opacity on unsaved pins.** `Color.brandAmber.opacity(0.5)` on unsaved pins was nearly invisible on the dark map — transparency that reads as "de-emphasized" on white reads as "ghost" on dark. States are now differentiated by hue only (amber / light green / green), not transparency. Transparency is reserved for the `isDimmed` and `isClosed` states via the `opacity` modifier on the outer container.

**Shadow updated for dark backgrounds.** Single dark shadow (`radius: 2, opacity: 0.2`) was invisible on a dark map. Replaced with a two-layer shadow: white glow (radius 3, opacity 0.3) for lift, plus black drop (radius 2, opacity 0.3, y: 2) for depth.
