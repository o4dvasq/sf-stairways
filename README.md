# SF Stairways

A static, browser-based map of all ~369 public stairways in San Francisco with a personal target list and walk progress tracking. Runs entirely on GitHub Pages — no backend, no build step.

## Live URL

`https://o4dvasq.github.io/sf-stairways/`

## First-time setup

1. Fork or clone this repo
2. In GitHub: Settings → Pages → Deploy from branch: `main`, folder: `/` (root)
3. Edit `index.html` — set `CONFIG.githubOwner` to your GitHub username
4. Open the live URL, click **⚙ Settings**, paste your GitHub Personal Access Token
   - Token is stored in your browser only — set it once per device

## Log a walk in the field

Tap a **red marker** → "Mark as Walked" → confirm date and steps → Save

The app writes directly to `data/target_list.json` via the GitHub API.

## Bulk update via Claude Code

Tell Claude which stairs you walked and the date; Claude edits `target_list.json` directly and commits.

## Add a stairway to your target list

Tap any **gray dot** (requires "Show All SF" mode) → "+ Add to Target List"

## Local development

```bash
python3 -m http.server 8080
# then open http://localhost:8080
```

GitHub API writes work locally too — same PAT token.

## Regenerate city data

```bash
pip install requests beautifulsoup4
python scripts/scrape_stairways.py
```

This populates `data/all_stairways.json` with all ~369 SF stairways. Run once and commit the result. The scraper fetches coordinates from sfstairways.com detail pages, falls back to Nominatim geocoding, and skips closed/demolished stairways.

## GitHub Token

The app needs a Personal Access Token with **repo** scope (or `contents: write` for fine-grained tokens):

→ [Create token](https://github.com/settings/tokens/new?description=sf-stairways&scopes=repo)

The token is stored in `localStorage` under key `gh_token`. It is never sent anywhere except directly to the GitHub API.

## File structure

```
sf-stairways/
├── index.html                  ← entire app (HTML + CSS + JS)
├── data/
│   ├── target_list.json        ← your target stairways + walk log
│   └── all_stairways.json      ← all SF stairways (from scraper)
├── scripts/
│   └── scrape_stairways.py     ← one-time data collection
└── README.md
```
