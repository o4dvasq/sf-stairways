SPEC: Remove Saved Concept + Map UI Layout Tweaks | Project: sf-stairways | Date: 2026-03-28 | Status: Ready for implementation

## 1. Objective

Remove the "Saved" (bookmark) concept from the app entirely. It was ill-defined and unused. If users later want wish lists, we'll add that as a distinct feature. Also adjust the map top bar and bottom area button layout, and rename the Progress tab to "Stats" to avoid visual repetition with the ProgressCard on the map.

## 2. Scope

Three changes bundled together since they all touch MapTab and related views:

**A. Remove "Saved" everywhere**
- Data model: Remove the ability to create WalkRecords with `walked = false`. A WalkRecord should only exist for walked stairways.
- Map filter pills: Remove the "Saved" option from `StairwayFilter` enum (keep All, Walked, Nearby)
- List filter: Remove the "Saved" option from `ListFilter` enum (keep All, Walked)
- Bottom sheet state machine: Collapse from 3 states (unsaved/saved/walked) to 2 states (unwalked/walked). Remove the `saved` case from `StairwayState`.
- Bottom sheet action buttons: Remove "Save" and "Unsave" buttons. For an unwalked stairway, show "Start Walk" and "Mark Walked". For a walked stairway, show "Not Walked" (removes the record).
- Bottom sheet state indicator badge: Remove the "Saved" badge (bookmark icon + "Saved" label)
- Pin colors: Remove the `saved` pin state. Pins should be either unwalked (amber) or walked (green). Remove `pinSaved` / `pinSavedDark` from AppColors (or leave unused — implementer's call).
- `saveStairway()` function in StairwayBottomSheet: Delete entirely
- `removeRecord()` in the "Unsave" context: Only keep it for the walked→unwalked transition
- Map annotation: Remove `saved` case from pin state logic
- Any `savedIDs` or `savedStairwayIDs` computed properties: Delete

**B. Move search button to bottom-right**
- Remove the magnifyingglass button from the top bar trailing HStack
- Add a standalone floating circle button (same 32x32 size, same styling) at the bottom-right of the map, positioned to the right of the existing ProgressCard or in the bottom bar area
- Keep same behavior (triggers `showSearch = true`)

**C. Move settings to left side of top bar**
- Move the gearshape button from the trailing HStack to a leading position in the top bar
- The StairShape branding icon stays centered
- Trailing HStack keeps: location (Around Me), tag filter

**D. Rename Progress tab to "Stats"**
- The tab bar label "Progress" conflicts visually with the floating ProgressCard on the map (same word stacked vertically)
- Rename the tab to "Stats" — the tab icon stays the same, just the label text changes

## 3. Business Rules

- No existing walked WalkRecords are affected. Only "saved but not walked" records (walked=false) become orphaned. They can be cleaned up with a one-time migration that deletes all WalkRecords where `walked == false`.
- The two pin states going forward: unwalked (amber, 18pt) and walked (green, 22pt).

## 4. Data Model / Schema Changes

- No schema changes to WalkRecord itself. The `walked` field stays (it's always `true` for valid records going forward).
- Add a one-time cleanup migration: on app launch, delete any WalkRecord where `walked == false`. This can be in SeedDataService or a new lightweight migration helper.

## 5. UI / Interface

**Map top bar (left to right):**
- Leading: Settings (gearshape) button
- Center: StairShape branding icon
- Trailing: Around Me (location.fill), Tag Filter (line.3.horizontal.decrease.circle)

**Map filter pills:**
- All | Walked | Nearby (remove Saved)

**Map bottom area:**
- Bottom-left / center: ProgressCard (unchanged)
- Bottom-right: Search button (magnifyingglass) as a standalone 32x32 circle with the same white-on-translucent styling

**Bottom sheet for unwalked stairway:**
- Buttons: "Start Walk" (green), "Mark Walked" (green)
- No Save/Bookmark button, no "Saved" badge

**Bottom sheet for walked stairway:**
- Buttons: "Not Walked" (amber) — deletes the WalkRecord

**List tab filters:**
- All | Walked (remove Saved)

## 6. Integration Points

- CloudKit sync: No changes needed. Deleting saved-but-unwalked records will sync deletions normally.

## 7. Constraints

- Keep the search button visually consistent with the top bar button style (same font size, weight, colors, circle clip).
- The bottom-right search button should not overlap with the ProgressCard.

## 8. Acceptance Criteria

- No "Saved" filter pill appears on map or list
- No bookmark/save button appears on the bottom sheet
- Tapping a stairway that was previously "saved but not walked" shows it as unwalked (amber pin, no badge)
- All existing walked records are preserved
- On first launch after update, any saved-but-unwalked WalkRecords are cleaned up
- Search button appears bottom-right of map as a floating circle
- Settings gear appears on the left side of the top bar
- Tab bar shows "Stats" instead of "Progress"
- Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/MapTab.swift` — filter enum, top bar layout, add bottom-right search button
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — state enum, action buttons, remove saveStairway(), state badge
- `ios/SFStairways/Views/Map/StairwayAnnotation.swift` — pin state logic
- `ios/SFStairways/Views/Map/TeardropPin.swift` — remove saved pin state
- `ios/SFStairways/Views/List/ListTab.swift` — remove Saved from ListFilter enum, remove savedIDs
- `ios/SFStairways/Resources/AppColors.swift` — optionally remove pinSaved colors
- `ios/SFStairways/Services/SeedDataService.swift` — add one-time cleanup of walked=false records
- `ios/SFStairways/Views/Progress/ProgressTab.swift` — rename tab label from "Progress" to "Stats"
- `ios/SFStairways/SFStairwaysApp.swift` (or wherever TabView is defined) — update tab label
