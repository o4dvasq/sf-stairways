# Architecture Decisions — sf-stairways

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
