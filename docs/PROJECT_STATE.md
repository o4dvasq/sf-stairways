# Project State — sf-stairways

_Last updated: 2026-03-22_

## What's Built

- **Interactive map** (Leaflet.js) showing all 382 SF stairways as gray dots, personal target list as colored markers
- **Walk logging** — tap a red marker → "Mark as Walked" → inline form saves directly to GitHub via Contents API
- **Target list management** — add any gray stairway to your target list from the map
- **Photo uploads** — attach photos to walked stairways via Cloudinary (unsigned upload preset)
- **Data scraper** (`scripts/scrape_stairways.py`) — one-time collector that pulled all ~382 stairways from sfstairways.com with Nominatim fallback
- **Deployed on GitHub Pages** — live at https://o4dvasq.github.io/sf-stairways/
- **Settings modal** — store GitHub PAT and Cloudinary credentials in localStorage

## Current Data

| Metric | Value |
|---|---|
| Target stairways | 13 |
| Walked | 8 |
| With photos | 0 |
| All SF stairways (all_stairways.json) | 382 |

### Walked Stairways

1. 16th Avenue Tiled Steps
2. Hidden Garden Steps
3. Lincoln Park Steps
4. Vulcan Stairway
5. Saturn Street Steps
6. Pemberton Place Steps
7. Filbert Steps
8. Greenwich Street (Sansome to Montgomery)

## Known Issues

_(none currently tracked)_

## Next Up

- Add photos to walked stairways (Cloudinary setup)
- Log more walks
