SPEC: Progress Tab — Neighborhood Reframe | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

Depends on: SPEC_neighborhood-foundation.md (NeighborhoodStore — already implemented)
Depends on: SPEC_neighborhood-311-migration.md (311 GeoJSON; ~66 neighborhoods with stairways)
Depends on: SPEC_neighborhood-map-and-detail.md (NeighborhoodDetail view)
Depends on: SPEC_visual-refresh-phase-1.md (warm palette, typography — already implemented)

---

## 1. Objective

Redesign the Progress tab so neighborhoods are the primary progress unit. The global completion ring becomes a compact summary, and a neighborhood card grid becomes the hero content. This reframe makes progress feel tangible and local ("I've explored 5 neighborhoods") rather than abstract ("I've done 12% of all stairways").

## 2. Scope

**In scope:**
- Compact global summary (shrink the ring, consolidate stats)
- Neighborhood card grid as hero content
- Undiscovered neighborhoods section (collapsed by default)
- Navigation from cards to NeighborhoodDetail

**Out of scope:**
- Recent walks / activity history (could be a future feature)
- Gamification, badges, or achievements
- Social or multi-user progress

## 3. Business Rules

- "Your neighborhoods" = neighborhoods where at least one stairway has been walked
- "Undiscovered" = neighborhoods where zero stairways have been walked (but stairways exist)
- Neighborhoods with zero stairways in the catalog (e.g., Golden Gate Park) do not appear in either section
- Card sort order: completion percentage descending (most-complete neighborhoods first). Ties broken by most recently walked.
- Total height climbed continues to use catalog heights (stairway.heightFt or override), not HealthKit elevation. This is the app's "known stairway height" metric.
- Total steps: sum of HealthKit step counts from active walks. Shows "—" if no active walks have captured step data (same behavior as current).

## 4. Data Model / Schema Changes

None. All data is derived from existing `WalkRecord` (via SwiftData `@Query`), `StairwayStore`, and `NeighborhoodStore`.

## 5. UI / Interface

### New layout

```
┌──────────────────────────────────┐
│  Progress                    ☁   │  ← Title + sync status icon (unchanged)
│                                  │
│  ┌──────────┐  48 of 382        │  ← Compact ring (~80pt diameter)
│  │   ring   │  12% · 1,285 ft   │     brandOrange fill, same animation
│  └──────────┘  8 neighborhoods   │     Stats as compact text block
│                                  │
│  ─────────────────────────────── │  ← Subtle divider
│                                  │
│  Your neighborhoods              │  ← Section header
│                                  │
│  ┌──────────┐ ┌──────────┐      │  ← 2-column card grid
│  │ Corona   │ │ Castro/  │      │
│  │ Heights  │ │ Upper    │      │
│  │ 7 / 16   │ │ Market   │      │
│  │ ━━━━━░░░ │ │ 3 / 8    │      │
│  └──────────┘ │ ━━░░░░░░ │      │
│               └──────────┘      │
│  ┌──────────┐ ┌──────────┐      │
│  │ Noe      │ │ Mission  │      │
│  │ Valley   │ │          │      │
│  │ 2 / 5    │ │ 1 / 12   │      │
│  │ ━░░░░░░░ │ │ ░░░░░░░░ │      │
│  └──────────┘ └──────────┘      │
│                                  │
│  Undiscovered              ▼     │  ← Collapsible, collapsed by default
│  29 neighborhoods                │
│                                  │
│  Bayview Hunters Point,          │  ← Compact text flow (names only)
│  Bernal Heights, Chinatown, ...  │     Tappable → NeighborhoodDetail
│                                  │
└──────────────────────────────────┘
```

### Compact global summary

- Ring shrinks to ~80pt diameter, left-aligned
- Adjacent to the ring: a compact text block with:
  - Line 1: "{walked} of {total}" (e.g., "48 of 382")
  - Line 2: "{percent}% · {height} ft" (e.g., "12% · 1,285 ft")
  - Line 3: "{count} neighborhoods" (count of neighborhoods with at least one walk)
- Typography: line 1 uses title3 Rounded weight medium, lines 2-3 use subheadline Rounded secondary color
- Ring color: `brandOrange`, same spring animation as current

### Neighborhood card grid

- 2-column `LazyVGrid` with flexible columns, 10pt spacing
- Each card contains:
  - Neighborhood name: `.subheadline`, Rounded, primary color. Truncate with `...` if needed (long names like "Oceanview/Merced/Ingleside")
  - Progress fraction: `.caption`, Rounded, `forestGreen` color, e.g. "7 / 16"
  - Mini progress bar: thin (4pt height), `brandOrange` fill, rounded caps
- Card styling: `surfaceCard` background, 10pt corner radius, 12pt internal padding
- Tapping a card navigates to `NeighborhoodDetail`
- Sort: completion percentage descending. If tied, most-recently-walked first (based on latest `dateWalked` among walked stairways in that neighborhood).

### Undiscovered section

- Section header: "Undiscovered" with a count subtitle ("{N} neighborhoods") and a disclosure chevron
- Collapsed by default (persisted via `@AppStorage` so it remembers between sessions)
- When expanded: shows neighborhood names as a flowing text layout or simple vertical list
- Each name is tappable → `NeighborhoodDetail` (useful for planning: "what's in this neighborhood?")
- Visual treatment: lighter than the active grid. Names in `.subheadline`, `textSecondary` color. No card treatment.
- Only includes neighborhoods that have stairways in the catalog but zero walked. Neighborhoods with no stairways at all (e.g., Treasure Island) are excluded entirely.

### What's removed from current ProgressTab

- The 2x2 `StatCard` grid (Total height climbed / Total steps / Neighborhoods / Walk days). Height and neighborhoods are in the compact summary. Steps and walk days are dropped from this view (steps is unreliable per the HealthKit issue; walk days isn't earning its space).
- The old neighborhood breakdown (DisclosureGroup list with progress bars and expandable stairway sublists). Replaced entirely by the card grid + NeighborhoodDetail.
- The `StatCard` view struct can be deleted if nothing else uses it.

## 6. Integration Points

### ProgressTab.swift — full rewrite of the view body
- Keep the existing SwiftData `@Query` bindings (`walkRecords`, `overrides`, `deletions`)
- Add `@Environment(NeighborhoodStore.self)` to access neighborhood data
- Computed properties for the card grid data (neighborhood name, walked count, total count, completion fraction, last walk date)
- Keep the sync status toolbar button and sheet

### NeighborhoodDetail
- Already built in Phase 2. Cards navigate to it via `NavigationLink(value:)` or programmatic navigation.

### NeighborhoodStore
- Provides the list of all neighborhoods and which stairways belong to each
- The Progress tab needs: for each neighborhood, count of stairways and count of walked stairways

### StairwayStore
- Continues to provide the full stairway catalog for height lookups and stairway-to-neighborhood mapping

## 7. Constraints

- The Progress tab is inside a `NavigationStack`. Navigation to `NeighborhoodDetail` should push onto this stack.
- `LazyVGrid` with 2 columns is standard SwiftUI. Card heights may vary slightly if neighborhood names wrap; use fixed-height cards or let the grid handle it naturally.
- Compact summary text block should remain single-line per stat to avoid layout jitter.
- The `@AppStorage` key for the undiscovered section collapse state should be namespaced (e.g., "progress.undiscovered.collapsed") to avoid conflicts.

## 8. Acceptance Criteria

- [ ] Global ring is ~80pt, positioned at top with compact stats text block alongside
- [ ] Stats text block shows: walked count / total, percentage + height, neighborhood count
- [ ] "Your neighborhoods" section shows 2-column card grid for neighborhoods with at least one walk
- [ ] Cards show: neighborhood name, walked/total count, mini progress bar
- [ ] Cards sorted by completion percentage descending
- [ ] Tapping a card navigates to NeighborhoodDetail
- [ ] "Undiscovered" section is collapsed by default and remembers expand/collapse state
- [ ] Undiscovered section shows tappable neighborhood names
- [ ] Tapping an undiscovered neighborhood name navigates to NeighborhoodDetail
- [ ] Old 2x2 stat grid and DisclosureGroup neighborhood breakdown are removed
- [ ] Sync status toolbar button still works
- [ ] App builds and runs without errors
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Views/Progress/ProgressTab.swift` — full rewrite of view body and computed properties
- `ios/SFStairways/Views/Progress/NeighborhoodCard.swift` — new: card component for the grid
- `ios/SFStairways/Views/Progress/StatCard.swift` — delete if unused elsewhere (check first)
