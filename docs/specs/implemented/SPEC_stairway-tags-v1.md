# SPEC: Stairway Tags
**Project:** sf-stairways | **Date:** 2026-03-28 | **Status:** Ready for implementation

---

## 1. Objective

Add a personal tagging system so the curator can annotate any stairway with descriptive labels (e.g. "views", "coffee nearby", "good workout") independent of walk state. Tags surface on the detail view, in search results, and as an additive filter on the map.

---

## 2. Scope

- New standalone data model for tags and tag assignments
- Tag management UI on the Detail view (add, remove)
- Tag pills displayed on the Detail view and in Search results
- "Filter" button on the Map tab that opens a tag picker sheet
- Tag filter is additive with the existing state filter (AND logic)
- Tags carry over into the List tab search/filter surface
- Preset tag suggestions bundled in JSON; custom tags also allowed

**Out of scope:** Tag renaming, tag merging, bulk tagging, sharing tags with other users.

---

## 3. Business Rules

**Tag vocabulary**
- A bundled `tags_preset.json` file defines the initial suggested tag list (e.g. "views", "easy", "short", "long", "good workout", "coffee nearby", "easy parking", "hidden gem", "kid-friendly").
- The user can create custom tags by typing a new name in the tag editor. Custom tags are persisted in SwiftData alongside the preset ones.
- Tags are case-insensitive for matching but stored as entered.
- Maximum tag name length: 30 characters.

**Tag assignments**
- Any stairway can be tagged, regardless of whether a WalkRecord exists.
- A stairway can have multiple tags; a tag can be applied to multiple stairways (many-to-many).
- Removing all tags from a stairway does not affect its walk state.

**Map filter behavior**
- The existing state filter (All / Saved / Walked / Nearby) and the tag filter are independent controls. Both must match for a pin to be visible (AND logic).
- Exception: if the combined filter produces zero results, the app drops the state filter constraint and shows all stairways matching the tag filter only. A brief toast notifies the user: "No [state] stairways with this tag — showing all tagged."
- Only one tag can be active as a map filter at a time (single-select in the filter sheet).
- When a tag filter is active, the Filter button on the map shows a filled/active visual state (analogous to how the state chips behave when active).

**Search integration**
- The existing Search panel (Name / Street / Neighborhood tabs) gains a **Tags** tab.
- The Tags tab shows all tags the user has created/assigned, each as a tappable pill. Tapping a tag shows a list of stairways with that tag, same row format as other search tabs.

---

## 4. Data Model / Schema Changes

Two new SwiftData models (additive migration — no changes to existing models):

**StairwayTag**
- `id: String` — unique slug derived from the tag name (e.g. "coffee-nearby")
- `name: String` — display name as entered by the user
- `isPreset: Bool` — true if sourced from the bundled preset list
- `createdAt: Date`

**TagAssignment**
- `stairwayID: String` — references Stairway.id (not a SwiftData relationship; same pattern as WalkRecord)
- `tagID: String` — references StairwayTag.id
- `assignedAt: Date`

Both models sync to CloudKit via the existing container. All fields require default values per CloudKit SwiftData constraints.

A new bundled resource `tags_preset.json` lists the initial preset tags. The app seeds these into SwiftData on first launch (same pattern as `SeedDataService`).

---

## 5. UI / Interface

### Detail View — Tag Section

A new "Tags" section appears below the notes field in `StairwayBottomSheet`.

- Displays currently applied tags as `forestGreen`-outlined pills with `forestGreen` text.
- An "+ Add Tag" pill button opens the tag editor sheet.

**Tag editor sheet** (presented as a bottom sheet, `.medium` detent):
- Search field at top for filtering suggestions.
- Preset tags shown as a scrollable pill grid. Tapping a preset toggles it on/off.
- If the user types a name not in the list, a "Create '[name]'" option appears below the suggestions.
- Already-applied tags show a checkmark indicator.
- Changes apply immediately (no confirm button needed); sheet dismisses on drag or background tap.

### Map Tab — Filter Button

A "Filter" button (funnel SF Symbol) appears in the top-right area of the map, near the existing filter chip row.

- Tapping opens a sheet (`.medium` detent) titled "Filter by Tag".
- Sheet shows all tags that have at least one assignment, as a single-select pill grid.
- Tapping a tag activates it; tapping again deactivates (toggle).
- Active tag filter: button shows filled funnel icon + `brandOrange` tint. Inactive: outline funnel, default tint.
- When active tag + state filter combo yields zero results, state filter is dropped silently and a toast appears (see Business Rules).

### Search Panel — Tags Tab

A fourth tab "Tags" is added to the existing Name / Street / Neighborhood tab bar in `SearchPanel`.

- Shows all user-created tags as large tappable pills.
- Tapping a tag shows a list of matching stairways in the same row format used by other tabs (name, neighborhood, distance).
- Tapping a result dismisses the panel and flies the map to that stairway, same as other tabs.

### List Tab

No UI changes to `ListTab` itself. Tag pills are visible when navigating to Detail from the list. Tag-based filtering is map-only in this version.

---

## 6. Integration Points

- `SeedDataService` — extended to also seed `tags_preset.json` on first launch.
- `@Query` property wrapper or lightweight service — tag queries use SwiftData `@Query` directly or a new lightweight service (not StairwayStore, which only handles the bundled JSON catalog).
- `MapTab` — new Filter button + active tag state passed into pin visibility logic alongside existing state filter.
- `SearchPanel` — new Tags tab added to existing tab structure.
- `StairwayBottomSheet` — new Tags section with sheet presentation.
- `SFStairwaysApp.swift` — add `StairwayTag.self` and `TagAssignment.self` to the SwiftData schema array: `let schema = Schema([WalkRecord.self, WalkPhoto.self, StairwayOverride.self, StairwayTag.self, TagAssignment.self])`
- CloudKit container — no changes needed; new models sync automatically.

---

## 7. Constraints

- No third-party dependencies. Tag UI uses SwiftUI native components (pill buttons via `.capsule()` shape, sheet presentation).
- SwiftData CloudKit constraints apply: all new model fields must have default values, no unique constraints, optional relationships.
- Preset tags are read-only from the user's perspective (cannot rename or delete presets, but can un-assign them from stairways).
- Custom tags can be deleted only if they have zero assignments (no orphan cleanup needed at launch).
- Map filter: single active tag at a time to keep the AND-logic simple and the UI unambiguous.

---

## 8. Acceptance Criteria

- [ ] Any stairway can be tagged from its Detail view regardless of walk state.
- [ ] Preset tag suggestions appear in the tag editor; custom tags can be created inline.
- [ ] Tags display as pills on the Detail view.
- [ ] Removing all tags from a stairway has no effect on its WalkRecord.
- [ ] The Map Filter button opens a sheet; selecting a tag filters pins additively with the active state filter.
- [ ] When AND-logic yields zero results, state filter is dropped and toast is shown.
- [ ] Filter button shows active visual state when a tag filter is applied.
- [ ] Search panel Tags tab lists all assigned tags and navigates to matching stairways.
- [ ] Tags sync across devices via CloudKit.
- [ ] No crashes on first launch (seed service handles preset tag initialization).
- [ ] Feedback loop prompt has been run.

---

## 9. Files Likely Touched

**New files:**
- `Models/StairwayTag.swift`
- `Models/TagAssignment.swift`
- `Resources/tags_preset.json`
- `Views/Components/TagEditorSheet.swift`
- `Views/Map/TagFilterSheet.swift`

**Modified files:**
- `Services/SeedDataService.swift` — seed preset tags on first launch (use `com.sfstairways.hasSeededTags` UserDefaults key)
- `Services/SeedDataService.swift` or new lightweight service — tag query helpers
- `Views/Map/StairwayBottomSheet.swift` — new Tags section
- `Views/Map/MapTab.swift` — Filter button, active tag state, pin visibility logic
- `Views/Map/SearchPanel.swift` — new Tags tab
- `SFStairwaysApp.swift` — register `StairwayTag.self` and `TagAssignment.self` in schema
