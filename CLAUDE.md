# sf-stairways

Interactive map for tracking personal SF stairway walks. Live at https://o4dvasq.github.io/sf-stairways/

## Tech Stack

- Vanilla JS + HTML/CSS — no build step, no framework
- Leaflet.js — map rendering
- GitHub Contents API — persisting target_list.json from the browser
- Cloudinary — photo uploads (free tier, unsigned presets)
- GitHub Pages — hosting

## Repo

https://github.com/o4dvasq/sf-stairways

## Entry Point

`index.html` — entire app in a single file (HTML + CSS + JS)

## Local Dev

```
python3 -m http.server 8080
```

Then open http://localhost:8080. GitHub API writes work locally with the same token.

## File Map

```
sf-stairways/
├── index.html                  ← entire app
├── data/
│   ├── target_list.json        ← personal walk log (13 stairways)
│   └── all_stairways.json      ← all 382 SF stairways from scraper
├── scripts/
│   └── scrape_stairways.py     ← one-time data collector
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DECISIONS.md
│   ├── PROJECT_STATE.md
│   └── specs/
│       ├── implemented/        ← completed specs
│       └── future/             ← backlog
└── README.md
```

## Logging a Walk

- **In-app:** tap a red marker → "Mark as Walked" → enter date/steps → Save
- **Via Claude Code:** tell Claude which stairways you walked; it edits `data/target_list.json` and commits

## Workflow

- Specs live in `docs/specs/` (pending) and `docs/specs/implemented/` (done)
- After implementing a spec: move spec file to `docs/specs/implemented/`, commit, push
