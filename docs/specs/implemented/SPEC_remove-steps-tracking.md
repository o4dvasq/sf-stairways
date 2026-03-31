SPEC: Remove Steps Tracking | Project: sf-stairways | Date: 2026-03-30 | Status: Ready for implementation

## 1. Objective

Remove all step-count tracking and display from the app across iOS, macOS, and Admin targets. Steps (whether from Apple Watch/HealthKit or manually entered) have proven unreliable and redundant. Height (feet climbed) is the meaningful metric. If a stairway has no height data, Oscar will count risers manually and calculate height outside the app — the app does not need to store or display stair counts.

## 2. Scope

All three targets: iOS app, macOS app, Admin app. Models, views, services, seed data parsing, and documentation.

## 3. Business Rules

- Height (feet) remains the primary and only physical metric for stairways.
- The `step_count` field in seed JSON files (`target_list.json`, `all_stairways.json`) is left as-is in the data files (no need to strip from static JSON), but the app should stop reading or displaying it.
- No step-related data should appear anywhere in the UI after this change.
- Existing `WalkRecord.stepCount` values in CloudKit/SwiftData are abandoned (not migrated or deleted — just ignored).
- Existing `StairwayOverride.verifiedStepCount` values are abandoned similarly.

## 4. Data Model / Schema Changes

### WalkRecord.swift
- Remove `stepCount: Int?` property. Since SwiftData/CloudKit handles schema evolution gracefully (old records with the field just have it ignored), this is safe to delete. If SwiftData complains about missing properties on existing records, keep the property but mark it fully deprecated with a comment and stop referencing it anywhere. Implementer's judgment on which approach is cleaner.
- Remove `stepCount` from the `init()` parameter list.

### StairwayOverride.swift
- Remove `verifiedStepCount: Int?` property.
- Update `hasAnyValue` computed property to remove the `verifiedStepCount != nil` check.
- Same SwiftData migration consideration as above.

### StairwayStore.swift
- Remove `resolvedStepCount()` method entirely.

### SeedDataService.swift
- Remove `stepCount` from the `SeedStairway` struct and its `CodingKeys`.
- Remove any `stepCount` pass-through in the seeding logic (line ~78 where `stepCount: seed.stepCount` is passed to WalkRecord init).

## 5. UI / Interface

### iOS Views

**MapTab.swift:**
- Remove `totalSteps` computation (line ~325: the `compactMap(\.stepCount).reduce(0, +)` aggregation).
- Remove `totalSteps` parameter from `ProgressCard`.
- Remove the steps display line in `ProgressCard` (line ~400: `"\(totalSteps.formatted()) steps"`).

**StairwayRow.swift:**
- Remove the entire step-count display block (lines ~33-37: the `verifiedStepCount` display and the `walkRecord?.stepCount` fallback).

**StairwayBottomSheet.swift:**
- Remove `curatorStepCountText` state variable.
- Remove `stepCount` from the `CuratorField` enum.
- Remove the "Stair count" curator editor section (label, TextField, focus binding, onChange).
- Remove step count parsing and assignment in the save logic (`let stepCount = Int(curatorStepCountText)`, `override.verifiedStepCount = stepCount`).
- Update the nil-check validation to only check height and description.
- Remove step count from the stats display row (`verifiedStepCount` display).

### macOS Views

**StairwayBrowser.swift:**
- Remove `hkStepCount` computed property (line ~30).
- Remove "Steps" column from the sortable Table if present.

**StairwayDetailPanel.swift:**
- Remove step count display row (line ~116: `walkRecord?.stepCount` display).
- Remove "step count" from the curator override editor section if present.

### Admin Views

**AdminDetailView.swift:**
- Remove `stepCountText` state variable.
- Remove the step count TextField (line ~128).
- Remove step count loading from override (line ~207).
- Remove step count parsing and saving in the save action (line ~213).

## 6. Integration Points

- CloudKit sync: no action needed. Removing properties from SwiftData models means new records simply won't have the fields. Old records with `stepCount` or `verifiedStepCount` in CloudKit are harmless — SwiftData ignores unknown/removed fields.
- No Supabase impact (steps were never synced to Supabase).

## 7. Constraints

- SwiftData schema evolution: if removing a stored property causes a migration error on devices with existing data, keep the property in the model but delete all references to it in views/services and add a `// DEPRECATED — retained for schema compatibility only, never read or written` comment. Test on a device with existing walk data.
- Do NOT modify the static JSON data files (`data/target_list.json`, `data/all_stairways.json`, `ios/SFStairways/Resources/*.json`). The `step_count` field can remain in the JSON; the app just stops reading it.

## 8. Acceptance Criteria

- No "steps" or "stair count" text appears anywhere in the iOS, macOS, or Admin UI.
- No step-related properties are actively read or written in any model, view, or service.
- The app builds and runs without errors on all three targets.
- Existing walk data (walked status, dates, photos, height, notes) is unaffected.
- The curator editor shows only Height and Description fields (no stair count).
- The ProgressCard / stats areas show only height climbed (no steps aggregation).
- Feedback loop prompt has been run.

## 9. Files Likely Touched

**Models:**
- `ios/SFStairways/Models/WalkRecord.swift`
- `ios/SFStairways/Models/StairwayOverride.swift`
- `ios/SFStairways/Models/StairwayStore.swift`

**Services:**
- `ios/SFStairways/Services/SeedDataService.swift`

**iOS Views:**
- `ios/SFStairways/Views/Map/MapTab.swift`
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift`
- `ios/SFStairways/Views/List/StairwayRow.swift`

**macOS Views:**
- `ios/SFStairwaysMac/Views/StairwayBrowser.swift`
- `ios/SFStairwaysMac/Views/StairwayDetailPanel.swift`

**Admin Views:**
- `ios/SFStairwaysAdmin/Views/AdminDetailView.swift`

**Docs (post-implementation):**
- `docs/ARCHITECTURE.md` — remove step count references from schema docs, seed data examples, view descriptions
- `docs/PROJECT_STATE.md` — update to reflect removal
- `docs/IOS_REFERENCE.md` — remove step references from UI descriptions
- `docs/DECISIONS.md` — add decision entry explaining the removal rationale
