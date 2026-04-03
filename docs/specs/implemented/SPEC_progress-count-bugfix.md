# SPEC: Progress Count Bugfix + Neighborhoods Visited Stat
**Project:** sf-stairways | **Date:** 2026-04-02 | **Status:** Ready for Implementation

---

## 1. Objective

Fix the walked count in the Progress tab (currently shows 76, should show 44) and add a "neighborhoods visited" count to the floating ProgressCard on the map. Two small, independent fixes in one spec.

---

## 2. Scope

**In scope:**
- Fix ProgressTab walked count to exclude deleted stairways
- Add neighborhoods visited count to the map's floating ProgressCard
- Standardize user-facing app name to "SF Stairways" (with space) in all permission strings

**Out of scope:**
- Changes to map pin behavior or colors
- Changes to the walked/unwalked flow
- Changes to the ProgressCard visual design beyond adding the neighborhoods line

---

## 3. Business Rules

### Bug: Progress Tab Walked Count

1. **Root cause.** `ProgressTab` computes `walkedCount` from raw `WalkRecord` query results filtered by `walked == true`. It does not exclude stairways that have been deleted via `StairwayDeletion`. The map's `ProgressCard` correctly filters against `store.stairways` (which applies deletions), so it shows 44. The Progress tab skips that filter, so it shows 76. The difference (32) is walk records for deleted stairways.

2. **Fix.** `ProgressTab.walkedCount` must filter `walkedRecords` to only include records whose `stairwayID` exists in `store.stairways`. Same pattern MapTab uses: build a `Set<String>` of valid stairway IDs from `store.stairways`, then intersect with walked record IDs.

3. **Audit other stats.** Any other computed values in `ProgressTab` that derive from `walkedRecords` (total height, neighborhood card groupings, verified count) must also exclude deleted stairways. Apply the same filter at the source so all downstream computations are correct.

### Feature: Neighborhoods Visited in Map ProgressCard

4. **What it shows.** The floating `ProgressCard` on the map currently shows walked count and total count. Add a line showing how many neighborhoods the user has visited (at least one walked stairway in the neighborhood). Format: "X neighborhoods" or "X hoods" (implementation discretion, keep it compact since the card is only 120pt wide).

5. **How to compute.** From the set of walked stairway IDs (already computed for the card), look up each stairway's neighborhood via `store.stairways`, collect unique neighborhood names, count them. This is a derived computation from data already available in `MapTab`.

### Naming Standardization

6. **"SF Stairways" with a space in all user-facing strings.** The location permission string currently says "FStairways" (typo plus no space). The camera permission string says "SFStairways" (no space). All four permission strings in the Xcode build settings should use "SF Stairways" with a space. Code identifiers (bundle ID, class names, folder names) remain `SFStairways` without a space.

---

## 4. Data Model / Schema Changes

None.

---

## 5. UI / Interface

### ProgressTab

No visual changes. The walked count number corrects from 76 to the actual count (matching what the map shows). All dependent stats (height, neighborhood cards, verified count) also correct if they were affected.

### Map ProgressCard

**Current:**
```
┌──────────┐
│  8 / 382 │
│  walked   │
└──────────┘
```

**New:**
```
┌──────────┐
│  8 / 382 │
│  walked   │
│  4 hoods  │  <- or "4 neighborhoods" if it fits
└──────────┘
```

The neighborhoods line should use a smaller or secondary font size. The card is 120pt wide, so space is tight. "X neighborhoods" may need to be abbreviated. Implementation should pick whatever reads well at that width.

### Permission Strings (Xcode Build Settings)

**Current values and fixes:**

| Key | Current | Fixed |
|---|---|---|
| NSLocationWhenInUseUsageDescription | "FStairways uses your location to find nearby stairways." | "SF Stairways uses your location to find nearby stairways." |
| NSCameraUsageDescription | "SFStairways uses your camera to photograph stairways you've walked." | "SF Stairways uses your camera to photograph stairways you've walked." |
| NSPhotoLibraryUsageDescription | (check if it says "SF Stairways" already) | Ensure "SF Stairways" with space |
| NSPhotoLibraryAddUsageDescription | (check if it says "SF Stairways" already) | Ensure "SF Stairways" with space |

These are in `project.pbxproj` under `INFOPLIST_KEY_NS*` entries. Both Debug and Release build configurations need the fix (the values appear twice).

---

## 6. Integration Points

- **ProgressTab.swift** — filter `walkedRecords` against `store.stairways` valid IDs
- **MapTab.swift** — add neighborhoods visited count to the floating ProgressCard (data is already available from `walkedStairwayIDs` + `store.stairways`)
- **SFStairways.xcodeproj/project.pbxproj** — fix permission string values (4 keys, 2 build configurations each = up to 8 occurrences)

---

## 7. Constraints

- The `ProgressCard` is 120pt wide. The neighborhoods count line must fit within that width.
- The permission string fixes are in `project.pbxproj`, which is an Xcode-managed file. Edit carefully. The strings appear under both Debug and Release build settings for the SFStairways target (not Admin, not Mac).
- Verify the fix doesn't break the neighborhood card grid or the "Undiscovered" section in ProgressTab. Both should continue to work correctly with the filtered data.

---

## 8. Acceptance Criteria

- [ ] Progress tab walked count matches the map ProgressCard count
- [ ] Progress tab walked count excludes stairways with StairwayDeletion records
- [ ] Total height stat in Progress tab is consistent (excludes deleted stairways)
- [ ] Neighborhood cards in Progress tab do not include deleted stairways
- [ ] Map ProgressCard shows a neighborhoods visited count
- [ ] Neighborhoods visited count only counts neighborhoods with at least one walked stairway
- [ ] Location permission dialog says "SF Stairways" (not "FStairways")
- [ ] Camera permission dialog says "SF Stairways" (not "SFStairways")
- [ ] All four permission strings use "SF Stairways" with a space
- [ ] Feedback loop prompt has been run

---

## 9. Files Likely Touched

- `ios/SFStairways/Views/Progress/ProgressTab.swift` — filter walkedRecords against valid stairway IDs from store
- `ios/SFStairways/Views/Map/MapTab.swift` — add neighborhoods visited count to ProgressCard
- `ios/SFStairways.xcodeproj/project.pbxproj` — fix NSLocationWhenInUseUsageDescription ("FStairways" to "SF Stairways"), fix NSCameraUsageDescription ("SFStairways" to "SF Stairways"), verify other two strings
