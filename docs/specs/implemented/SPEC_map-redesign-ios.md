# SPEC: Map Redesign — iOS Native with Saved List + Around Me
**Project:** sf-stairways | **Date:** 2026-03-25 | **Status:** Ready for Implementation

---

## 1. Objective

Redesign the sf-stairways iOS map experience into a polished, exploration-focused app. This spec introduces branded custom pins, an "Around Me" neighborhood-aware filter, a search panel, and a three-state stairway model (All / Saved / Walked) that replaces the current target list concept. The web app (`index.html`) is deprecated; the iOS app is now the sole platform.

---

## 2. Scope

**In scope:**
- Three-state stairway model: All → Saved → Walked
- Custom branded teardrop map pins with stairway icon
- "Around Me" neighborhood highlighting using DataSF GeoJSON
- Search panel (slide-up from bottom bar) with tab-based filtering
- Visual refresh: new pin design, color tokens, map style
- Retirement of `target_list.json` seeding in favor of the Saved/Walked model
- Decisions log entry for web app deprecation

**Out of scope:**
- Stairway detail page redesign (separate spec)
- Supabase / multi-user backend (separate spec, already exists)
- Gamification, badges, streaks (future spec — the three-state model enables this later)
- App Store submission
- Walking directions / navigation

---

## 3. Business Rules

### Three-State Model

Every stairway in the 382-item catalog exists in one of three states from the user's perspective:

- **Unsaved (default):** No WalkRecord exists. Stairway appears on the map and in search but is visually de-emphasized (smaller pin, muted color).
- **Saved:** A WalkRecord exists with `walked = false`. The user has bookmarked this stairway as one they want to visit. Pin is full-color orange. Appears in the "Saved" filter.
- **Walked:** A WalkRecord exists with `walked = true`. The user has visited this stairway. Pin is green (existing `walkedGreen`). Appears in the "Walked" filter.

State transitions:
- Unsaved → Saved: user taps "Save" (bookmark) on a stairway (creates a WalkRecord with `walked = false`)
- Saved → Walked: user taps "Mark as Walked" (sets `walked = true`, records date)
- Walked → Saved: user taps "Unmark Walk" (sets `walked = false`, clears date)
- Saved → Unsaved: user taps "Remove" (deletes the WalkRecord)
- Unsaved → Walked: user taps "Mark as Walked" directly (creates WalkRecord with `walked = true` and date)
- Walked → Unsaved: user taps "Remove" (deletes the WalkRecord — walk history is lost, which is fine as a deliberate action)

### Data model change

The existing `WalkRecord` model already supports this. A stairway is "Saved" when a WalkRecord exists with `walked = false`. No schema changes needed. The only change is in how the UI interprets and presents these states.

The `SeedDataService` needs to be updated: existing seed records with `walked = false` (the 5 un-walked stairways from `target_list.json`) now represent "Saved" stairways, which is the correct interpretation. No data migration needed.

### Custom Pins

- **Shape:** Teardrop / drop pin (not the current circle). SVG-based, rendered as SwiftUI view inside `Annotation`.
- **Unsaved:** Small teardrop (24×30pt), muted slate fill (`unwalkedSlate` at 50% opacity), no icon inside.
- **Saved:** Medium teardrop (28×35pt), orange fill (`brandOrange`), white stairway icon (3-4 step silhouette) centered in the bulb.
- **Walked:** Medium teardrop (28×35pt), green fill (`walkedGreen`), white checkmark icon centered in the bulb.
- **Selected:** Active pin scales up to 34×42pt, adds a shadow, darker fill variant.
- **Closed:** Any state, but with 40% opacity and a subtle strikethrough or "X" overlay.

### Around Me

- Floating pill button above the bottom search bar, right-aligned. Label: "Around Me" with SF Symbol `location.fill`.
- On tap:
  1. Request location permission (if not already granted).
  2. Determine user's current SF neighborhood via point-in-polygon against DataSF neighborhood GeoJSON (bundled locally).
  3. Determine adjacent neighborhoods (pre-computed adjacency lookup, bundled as JSON).
  4. Set map filter: pins in current + adjacent neighborhoods render at full opacity. All other pins dim to 20% opacity.
  5. Display a floating chip label on the map: "You're in [Neighborhood Name]".
  6. Fly the map camera to center on the user's location at zoom level ~0.02 lat/lng span.
- Toggle off (tap again): restore all pins to normal state, remove chip, restore previous camera position.
- If location denied: show a brief toast — "Enable location in Settings to use Around Me".
- If user is outside SF (no neighborhood polygon match): show toast — "Around Me works within San Francisco".

### Neighborhood Data

- Source: DataSF "SF Find Neighborhoods" GeoJSON (`https://data.sfgov.org/resource/p5b7-5n3h.geojson`).
- Bundle as `neighborhoods.geojson` in the app's Resources folder. Do not fetch at runtime.
- **Adjacency map:** Pre-compute at build time using a script (`scripts/build_neighborhood_adjacency.py`). Output: `neighborhood_adjacency.json` — a dictionary where each key is a neighborhood name and the value is an array of neighboring neighborhood names. Bundle this JSON in the app.
- **Stairway-to-neighborhood assignment:** The `Stairway` model already has a `neighborhood` field populated from `all_stairways.json`. This is sufficient. No point-in-polygon lookup needed at runtime.

### Search

- Fixed search bar at the bottom of the map view, above the safe area. Styled as a rounded pill with placeholder text "Search stairways..." and a magnifying glass icon.
- Tap opens a full-screen modal (`.fullScreenCover`) that slides up.
- Modal has:
  - Search text field (auto-focused, keyboard appears immediately)
  - Three filter tabs as horizontal pills: **Name** | **Street** | **Neighborhood**
  - Results list below, live-filtering as user types
  - Each result row: stairway name, neighborhood, distance from current location (if location available; omit if not)
  - Tap a result: dismiss modal, fly map to that stairway, select its pin (open bottom sheet)
- **Name** tab: searches stairway names (existing `StairwayStore.search` logic)
- **Street** tab: searches stairway names since street info is embedded in most names (e.g., "Vulcan Street Steps"). If the data gains a dedicated `street` field later, this can switch to that.
- **Neighborhood** tab: searches neighborhood names. Tapping a neighborhood result flies the map to fit all stairways in that neighborhood.
- Search is simple substring matching (case-insensitive). No fuzzy search library needed for 382 items.

### Filter Chips (revised)

The existing filter chips on the map (All / Walked / To Do / Nearby) are replaced:

**All | Saved | Walked | Nearby**

- **All:** Shows all 382 stairways (default).
- **Saved:** Shows only stairways with a WalkRecord where `walked = false`.
- **Walked:** Shows only stairways with a WalkRecord where `walked = true`.
- **Nearby:** Shows stairways within 1500m of current location (existing behavior).

"To Do" is renamed to "Saved" to match the new vocabulary. The "Nearby" filter remains as-is.

Note: "Around Me" (neighborhood-based dimming) is separate from the "Nearby" chip (radius-based filtering). They can be active simultaneously: user could tap "Around Me" to dim distant pins, then also select the "Saved" chip to only show saved stairways in the highlighted neighborhoods.

---

## 4. Data Model / Schema Changes

### No SwiftData schema changes required.

The existing `WalkRecord` model supports the three-state concept as-is:
- No WalkRecord = Unsaved
- WalkRecord with `walked = false` = Saved
- WalkRecord with `walked = true` = Walked

### New bundled data files

| File | Purpose | Source |
|------|---------|--------|
| `neighborhoods.geojson` | SF neighborhood polygons for point-in-polygon lookup | DataSF, bundled at build time |
| `neighborhood_adjacency.json` | Pre-computed neighborhood → neighbors mapping | Generated by `scripts/build_neighborhood_adjacency.py` |

### Build script

`scripts/build_neighborhood_adjacency.py`:
1. Load `neighborhoods.geojson`
2. For each pair of neighborhood polygons, check if they share a boundary (shapely `touches()` or `intersects()` with a small buffer)
3. Output `neighborhood_adjacency.json`:
```json
{
  "Noe Valley": ["Castro/Upper Market", "Glen Park", "Diamond Heights", "Mission"],
  "Castro/Upper Market": ["Noe Valley", "Haight Ashbury", "Twin Peaks", ...],
  ...
}
```
4. Copy output to `ios/SFStairways/Resources/`

---

## 5. UI / Interface

### Map View Layout

```
┌─────────────────────────────┐
│  [status bar / Dynamic Island] │
│                                │
│         APPLE MAPS             │
│      (MapKit, full fill)       │
│                                │
│   🟢  🟠  ⚪                  │
│      🟠     ⚪                │
│              ⚪  ⚪            │
│                                │
│  ┌──────────────────────┐     │
│  │ All │ Saved │Walked│Near│  │  ← filter chips (top, existing position)
│  └──────────────────────┘     │
│                                │
│            [You're in Noe Valley]  ← neighborhood chip (when Around Me active)
│                                │
│                   [◎ Around Me] │  ← floating pill, above search bar
│  ┌──────────────────────────┐ │
│  │  🔍 Search stairways...   │ │  ← bottom search bar
│  └──────────────────────────┘ │
│  [home indicator safe area]    │
└────────────────────────────────┘
```

### Pin Design (SwiftUI View)

Teardrop shape rendered as a SwiftUI `Shape` or `Path`:
- Upper portion: circle (the bulb)
- Lower portion: triangle tapering to a point
- Icon centered in the bulb (stair silhouette for Saved, checkmark for Walked, none for Unsaved)
- Rendered at native resolution (no bitmap scaling issues on Retina)

### Search Modal

```
┌─────────────────────────────┐
│  ✕   🔍 [search input      ] │
│  ┌──────┬──────┬───────────┐ │
│  │ Name │Street│Neighborhood│ │  ← tab pills
│  └──────┴──────┴───────────┘ │
│                                │
│  Vulcan Street Steps           │
│  Corona Heights · 0.4 km       │
│  ─────────────────────────── │
│  Pemberton Place Steps         │
│  Twin Peaks · 0.7 km          │
│  ─────────────────────────── │
│  ...                           │
└─────────────────────────────┘
```

### Color Tokens (additions to AppColors.swift)

```swift
static let brandOrange = Color(red: 232/255, green: 96/255, blue: 44/255)      // #E8602C — Saved pins
static let brandOrangeDark = Color(red: 192/255, green: 74/255, blue: 26/255)  // #C04A1A — Selected saved pin
static let pinDimmed = Color(red: 120/255, green: 144/255, blue: 156/255).opacity(0.2)  // Around Me dimming
```

Existing colors retained: `forestGreen`, `walkedGreen`, `unwalkedSlate`, `closedRed`, `accentAmber`.

### Bottom Sheet (existing, minor update)

The existing `StairwayBottomSheet` gains:
- A "Save" / "Unsave" button (bookmark icon toggle) for the Saved state
- The existing "Mark as Walked" toggle remains
- Visual indication of current state (Unsaved / Saved / Walked)

---

## 6. Integration Points

- **MapKit** — Already in use. No change to map provider. Apple Maps stays.
- **Core Location** — Already in use via `LocationManager`. Used for Nearby filter and Around Me.
- **DataSF Neighborhoods GeoJSON** — Bundled in Resources. Loaded at app launch for Around Me point-in-polygon lookup.
- **Pre-computed adjacency JSON** — Bundled in Resources. Loaded when Around Me is activated.
- **SwiftData + CloudKit** — Existing persistence layer. Saved/Walked state syncs to CloudKit automatically since WalkRecord is already a SwiftData `@Model`.

No new external dependencies. No new frameworks. No Mapbox, no Turf.js. Everything is native Apple APIs + bundled JSON.

---

## 7. Constraints

- **MapKit only.** No Mapbox. MapKit is free, already integrated, and sufficient. Mapbox would add a token management dependency and a usage-based billing risk for no material benefit on iOS.
- **No build tooling changes.** No Vite, no npm, no CI/CD pipeline changes. The iOS app builds in Xcode as-is.
- **No new Swift packages.** Point-in-polygon can be done with Core Location + the bundled GeoJSON using a simple ray-casting algorithm (or a lightweight Swift implementation). No need for a Turf equivalent.
- **Neighborhood adjacency is pre-computed.** Do not compute polygon intersections at runtime. The Python script generates a static JSON lookup.
- **Stairway data stays as bundled JSON.** The 382-stairway catalog remains read-only bundled data. Write path is SwiftData (WalkRecord) only.
- **Web app is deprecated.** `index.html` stays in the repo for historical reference but receives no further development. A future commit can add a redirect or sunset notice.

---

## 8. Acceptance Criteria

- [ ] Unsaved stairways render as small muted teardrop pins (no icon)
- [ ] Saved stairways render as orange teardrop pins with stairway icon
- [ ] Walked stairways render as green teardrop pins with checkmark icon
- [ ] Tapping an unsaved pin opens bottom sheet with "Save" and "Mark as Walked" options
- [ ] Tapping a saved pin opens bottom sheet with "Unsave", "Mark as Walked" options
- [ ] Tapping a walked pin opens bottom sheet with "Unmark Walk" and "Remove" options
- [ ] Filter chips updated to All / Saved / Walked / Nearby
- [ ] "Saved" filter shows only stairways with WalkRecord where walked = false
- [ ] "Around Me" pill button visible above bottom search bar
- [ ] Around Me activates: dims pins outside current + adjacent neighborhoods
- [ ] Neighborhood label chip appears ("You're in [Name]")
- [ ] Around Me toggles off cleanly, restoring all pin states
- [ ] Location denial shows toast message
- [ ] Outside-SF location shows appropriate toast
- [ ] Bottom search bar is visible on the map at all times
- [ ] Tapping search bar opens full-screen search modal
- [ ] Search modal has Name / Street / Neighborhood tabs
- [ ] Live search filters results as user types
- [ ] Tapping a search result dismisses modal and flies map to that stairway
- [ ] Tapping a neighborhood result flies map to fit that neighborhood's stairways
- [ ] Existing walked stairway data (8 walked records) is preserved — no data loss
- [ ] Existing seed data (5 un-walked records) correctly appears as "Saved"
- [ ] CloudKit sync continues to work for WalkRecord (Saved and Walked states sync)
- [ ] `neighborhoods.geojson` and `neighborhood_adjacency.json` are bundled in the app
- [ ] `scripts/build_neighborhood_adjacency.py` generates correct adjacency map
- [ ] Feedback loop prompt has been run

---

## 9. Files Likely Touched

### iOS source (modify)
```
ios/SFStairways/Views/Map/MapTab.swift              — Add search bar, Around Me button, revised filters, pin dimming
ios/SFStairways/Views/Map/StairwayAnnotation.swift   — Replace circle pins with teardrop design, three-state styling
ios/SFStairways/Views/Map/StairwayBottomSheet.swift  — Add Save/Unsave button, three-state UI
ios/SFStairways/Views/List/ListTab.swift             — Rename "To Do" filter to "Saved", update filter logic
ios/SFStairways/Resources/AppColors.swift            — Add brandOrange, brandOrangeDark, pinDimmed
ios/SFStairways/Models/StairwayStore.swift           — Add neighborhood lookup, search by street/neighborhood tabs
```

### iOS source (new files)
```
ios/SFStairways/Views/Map/SearchPanel.swift          — Full-screen search modal with tabs
ios/SFStairways/Views/Map/AroundMeManager.swift      — Neighborhood detection, adjacency lookup, dimming state
ios/SFStairways/Views/Map/TeardropPin.swift           — Reusable teardrop Shape/Path for pin rendering
ios/SFStairways/Views/Components/ToastView.swift     — Lightweight toast for error messages
```

### iOS resources (new)
```
ios/SFStairways/Resources/neighborhoods.geojson       — DataSF SF neighborhood polygons
ios/SFStairways/Resources/neighborhood_adjacency.json — Pre-computed adjacency map
```

### Scripts (new)
```
scripts/build_neighborhood_adjacency.py               — Generates neighborhood_adjacency.json from GeoJSON
```

### Docs (modify)
```
docs/DECISIONS.md                                     — Add web app deprecation + three-state model decisions
docs/PROJECT_STATE.md                                 — Update to reflect iOS-only, remove web app workstream
```

---

## Appendix: Decisions to Log

The following entries should be added to `docs/DECISIONS.md` when this spec is implemented:

### Web app deprecated in favor of iOS-only
**Date:** 2026-03-25

The web app (`index.html`) was a prototype that proved out the concept: interactive map of SF stairways with walk logging. Now that the iOS app has feature parity and native advantages (camera, GPS, CloudKit sync, offline), maintaining two codebases for one user provides no value. The iOS app is the sole platform going forward. `index.html` remains in the repo for reference but receives no further development.

### Three-state stairway model (Unsaved / Saved / Walked) replaces target list
**Date:** 2026-03-25

The original "target list" was a static JSON file with 13 pre-selected stairways. This was a bootstrapping mechanism, not a real feature. The three-state model makes saving dynamic: users discover stairways on the map and bookmark them for later. The existing `WalkRecord` model already supports this — a record with `walked = false` is the "Saved" state. No schema change needed. This also lays the groundwork for future gamification (progress tracking, completion percentages, streaks) without requiring another data model change.

### MapKit over Mapbox for iOS
**Date:** 2026-03-25

The original web-focused spec proposed Mapbox GL JS. For iOS, MapKit is the right choice: it's free with no usage limits, already integrated, handles pin annotations natively, and integrates with Core Location. Mapbox iOS SDK would add a CocoaPod/SPM dependency, a token management requirement, and usage-based billing, all for capabilities MapKit already provides.

### Pre-computed neighborhood adjacency over runtime polygon intersection
**Date:** 2026-03-25

The "Around Me" feature needs to know which SF neighborhoods border the user's current neighborhood. Computing polygon intersections at runtime (the Turf.js approach from the web spec) is unnecessary overhead on a mobile device. Instead, a Python build script pre-computes the adjacency map once and bundles it as static JSON. The app does a simple dictionary lookup at runtime. Simpler, faster, no geometry library needed in Swift.

---

## Appendix: Future Architectural Improvements

These are out of scope for this spec but will be needed as the app evolves. Each entry notes what functionality would trigger the upgrade.

| Improvement | Trigger | Notes |
|------------|---------|-------|
| **Vite or build pipeline for web** | If web app is ever revived for public landing page | Currently no web build step. Only needed if the web presence grows beyond a static page. |
| **Supabase backend** | Multi-user / App Store launch | Spec already exists (`SPEC_multi-user-backend-architecture.md`). Required for user accounts, cloud persistence beyond iCloud, and shared data. |
| **Swift package for geometry** | Complex spatial queries beyond point-in-polygon | Current approach (ray-casting + pre-computed adjacency) handles Around Me. If we add features like "stairways along a walking route" or "optimal loop" we'd need a real geometry library. |
| **Server-side stairway catalog updates** | New stairways added to SF, community corrections | Currently the 382-stairway catalog is bundled JSON. A remote catalog (Supabase table or hosted JSON with versioning) would allow updates without app releases. |
| **CI/CD for iOS** | When release frequency or team size justifies it | Currently Oscar builds and runs from Xcode manually. Fastlane or Xcode Cloud would be triggered by TestFlight/App Store submission cadence. |
| **Photo CDN** | Photo count exceeds what CloudKit/SwiftData handles efficiently | Currently photos are stored as CKAssets via SwiftData external storage. At scale, a CDN (Cloudflare R2 via Supabase Storage) would be better. See existing decision in DECISIONS.md. |
| **Dedicated street field in data** | When search-by-street needs to be precise | Currently street info is embedded in stairway names. A dedicated `street` field in `all_stairways.json` would improve the Street search tab accuracy. Could be added via a scraper update. |
