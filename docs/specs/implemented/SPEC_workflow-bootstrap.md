SPEC: Workflow System Bootstrap | Project: sf-stairways | Date: 2026-03-22 | Status: Ready for implementation

---

## 1. Objective

Bootstrap the Claude Workflow System for sf-stairways so it supports `/code start`, `/feedback-loop`, and the full Desktop → spec → Claude Code → feedback loop workflow. The app is fully built and deployed — this is purely adding the workflow infrastructure files.

## 2. Scope

Create the four required workflow files and reorganize existing specs into the standard directory structure. No application code changes.

## 3. Business Rules

- CLAUDE.md must be ≤80 lines
- All workflow docs go in `docs/`
- Implemented specs go in `docs/specs/implemented/`
- Pending/future specs go in `docs/specs/`
- The `from-crm-cleanup/` directory is a migration artifact and must be eliminated

## 4. Data Model / Schema Changes

None — this is docs-only.

## 5. UI / Interface

None.

## 6. Integration Points

None.

## 7. Constraints

- Do not modify `index.html`, `data/`, or `scripts/` — app code is untouched
- CLAUDE.md ≤80 lines, lean constraints only
- Retroactive entries in DECISIONS.md should be dated `2026-03-22` and marked `[retroactive]`

## 8. Acceptance Criteria

- [ ] `CLAUDE.md` exists at project root, ≤80 lines, with: project purpose, tech stack (Vanilla JS, Leaflet.js, GitHub Pages, Cloudinary), repo URL (`https://github.com/o4dvasq/sf-stairways`), entry point (`index.html` single-file app), local dev command (`python3 -m http.server 8080`), file map
- [ ] `docs/PROJECT_STATE.md` exists with: what's built (map app, walk logging, photo uploads, data scraper, GitHub Pages live at `https://o4dvasq.github.io/sf-stairways/`), current data (13 target stairways, 8 walked, 2 with photos, 382 total in all_stairways.json), known issues section (can be empty), next up section
- [ ] `docs/DECISIONS.md` exists with retroactive entries covering: single-file HTML (no build step), Leaflet.js over Google Maps (free, no API key), GitHub API for persistence (no backend), Cloudinary for photos (free tier, unsigned uploads), data scraping approach (sfstairways.com + Nominatim fallback)
- [ ] `docs/ARCHITECTURE.md` exists documenting: single-file app structure, CONFIG block, three Leaflet marker layers with pane z-ordering, GitHub API read/write flow for target_list.json, Cloudinary upload flow, data file schemas
- [ ] `docs/specs/implemented/` directory exists
- [ ] `sf_stairways_map_spec_v3.md` moved from `docs/specs/from-crm-cleanup/` to `docs/specs/implemented/`
- [ ] `sf_stairways_photo_spec.md` moved from `docs/specs/from-crm-cleanup/` to `docs/specs/implemented/`
- [ ] `docs/specs/from-crm-cleanup/` directory deleted
- [ ] `/feedback-loop` has been run successfully
- [ ] Changes committed and pushed

## 9. Files Likely Touched

```
CLAUDE.md                                          (CREATE)
docs/PROJECT_STATE.md                              (CREATE)
docs/DECISIONS.md                                  (CREATE)
docs/ARCHITECTURE.md                               (CREATE)
docs/specs/implemented/                            (CREATE dir)
docs/specs/implemented/sf_stairways_map_spec_v3.md (MOVE from from-crm-cleanup/)
docs/specs/implemented/sf_stairways_photo_spec.md  (MOVE from from-crm-cleanup/)
docs/specs/from-crm-cleanup/                       (DELETE dir)
```
