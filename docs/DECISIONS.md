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

## Data scraping approach (sfstairways.com + Nominatim fallback)
**Date:** 2026-03-22 [retroactive]

`scripts/scrape_stairways.py` is a one-time script that builds `data/all_stairways.json`. It first attempts to extract lat/lng from each stairway's page on sfstairways.com (Google Maps embeds, JS variables, JSON-LD). If that fails, it falls back to Nominatim geocoding. Records with no coordinates get `lat: null, lng: null` and are silently skipped by the app. The result is committed to the repo — no live scraping at runtime.
