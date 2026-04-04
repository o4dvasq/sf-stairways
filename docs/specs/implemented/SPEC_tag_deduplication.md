SPEC: Tag Deduplication & Uniqueness Constraints | Project: sf-stairways | Date: 2026-04-03 | Status: Ready for implementation

---

## 1. Objective

Eliminate duplicate tags in all tag-related UI surfaces and prevent future duplicates at the data layer. CloudKit sync currently creates duplicate `StairwayTag` records because SwiftData has no uniqueness constraint on the `id` field. The same root cause applies to `TagAssignment`, where duplicate assignment records can accumulate.

## 2. Scope

Three layers of work:

- **Model layer:** Add `@Attribute(.unique)` to `StairwayTag.id` and a compound unique constraint to `TagAssignment` so SwiftData upserts instead of inserting duplicates during CloudKit sync.
- **View layer:** Fix the remaining unprotected view (`BulkOperationsSheet` assign-tag Picker) that displays raw, undeduped tag arrays. Two other gaps in `StairwayDetailPanel` were patched as a quick fix on 2026-04-03 and should be reviewed for consistency with whatever pattern is adopted.
- **One-time migration:** Purge existing duplicate `StairwayTag` and `TagAssignment` records from the local store on first launch after the update.

Out of scope: changes to tag creation logic, tag UI/UX redesign, or any CloudKit container schema changes beyond what SwiftData generates automatically from `@Attribute(.unique)`.

## 3. Business Rules

- Each `StairwayTag` must be uniquely identified by its `id` (the slug string, e.g. `"coffee-nearby"`). If CloudKit delivers a record whose `id` matches an existing local record, SwiftData should upsert (update the existing record) rather than insert a duplicate.
- Each `TagAssignment` must be unique per `(stairwayID, tagID)` pair. Duplicate assignments for the same stairway+tag combination should be collapsed into one.
- The migration that purges duplicates must preserve the earliest-created record (by `createdAt` for tags, by `assignedAt` for assignments) and delete all others.
- Preset tags seeded from `tags_preset.json` should never create duplicates if CloudKit has already synced the same tags from another device. The current guard (`existingCount > 0` skip) is necessary but not sufficient once `@Attribute(.unique)` is in place; review whether seed logic should switch to upsert-or-skip per tag instead of bulk-skip.

## 4. Data Model / Schema Changes

### StairwayTag.swift

```swift
@Model
class StairwayTag {
    @Attribute(.unique) var id: String = ""
    var name: String = ""
    var isPreset: Bool = false
    var createdAt: Date = Date()
    var colorIndex: Int = 0
    // ...
}
```

Adding `@Attribute(.unique)` to `id` tells SwiftData to enforce uniqueness. When a CloudKit record arrives with a matching `id`, SwiftData will update the existing row instead of inserting a new one.

### TagAssignment.swift

SwiftData does not support compound `@Attribute(.unique)` across multiple properties. Two options:

**Option A (recommended):** Add a computed `compoundKey` property with `@Attribute(.unique)`:

```swift
@Model
class TagAssignment {
    @Attribute(.unique) var compoundKey: String = ""
    var stairwayID: String = ""
    var tagID: String = ""
    var assignedAt: Date = Date()

    init(stairwayID: String, tagID: String) {
        self.stairwayID = stairwayID
        self.tagID = tagID
        self.compoundKey = "\(stairwayID)::\(tagID)"
        self.assignedAt = Date()
    }
}
```

Every call site that creates a `TagAssignment` already passes both `stairwayID` and `tagID`, so the `init` handles `compoundKey` automatically. Existing records will need the migration (Section 4 below) to backfill `compoundKey` values.

**Option B (simpler, view-only):** Keep `TagAssignment` as-is and rely on view-layer dedup. Less robust but zero migration risk for the assignment table.

Recommendation: implement Option A. The migration is straightforward and eliminates the class of bugs permanently.

### Migration

On first launch after the update, run a one-time cleanup before the main SwiftData container is fully initialized:

1. **Dedup StairwayTag:** Group all `StairwayTag` records by `id`. For each group with count > 1, keep the record with the earliest `createdAt`, delete the rest.
2. **Dedup TagAssignment:** Group all `TagAssignment` records by `(stairwayID, tagID)`. For each group with count > 1, keep the record with the earliest `assignedAt`, delete the rest.
3. **Backfill compoundKey:** For every `TagAssignment` where `compoundKey` is empty, set it to `"\(stairwayID)::\(tagID)"`.
4. Gate with `UserDefaults` key `hasRunTagDedupMigration_v1`.

This migration must run BEFORE `@Attribute(.unique)` is enforced, because SwiftData will refuse to open a store that violates a new unique constraint. The recommended approach is to run the cleanup using a temporary `ModelContainer` with the OLD schema (no unique constraints), then re-open with the new schema.

Alternatively, use a `VersionedSchema` + `SchemaMigrationPlan` if the project already uses one. Check `SFStairwaysApp.swift` for existing migration infrastructure.

## 5. UI / Interface

No new UI. The fix is invisible to the user; they simply stop seeing duplicate tags.

### View-layer changes

Only one view still has a dedup gap:

**BulkOperationsSheet.swift — `assignTagSection` (line 120):**
The Picker iterates `ForEach(tags)` directly. This must be changed to iterate a deduped list:

```swift
// Current (buggy):
ForEach(tags) { tag in
    Text(tag.name).tag(tag.id as String?)
}

// Fixed:
let dedupedTags: [StairwayTag] = {
    var seen = Set<String>()
    return tags
        .filter { seen.insert($0.id).inserted }
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
}()

ForEach(dedupedTags) { tag in
    Text(tag.name).tag(tag.id as String?)
}
```

**StairwayDetailPanel.swift — `tagsSection` (line 292) and `tagChecklist` (line 335):**
These were patched on 2026-04-03 with inline `seen` sets. Review for consistency with the dedup pattern used elsewhere. The patches are correct but could be cleaned up if the `@Attribute(.unique)` migration eliminates duplicates at the source — the `seen` guards can remain as a defensive layer regardless.

## 6. Integration Points

- **CloudKit sync:** The `@Attribute(.unique)` constraint changes how SwiftData handles incoming CloudKit records. On upsert, the newer record's field values overwrite the older ones. This is the desired behavior (CloudKit is the source of truth for synced fields).
- **SeedDataService.seedTagsIfNeeded():** Currently does a bulk skip if any tags exist. After adding `@Attribute(.unique)`, seeding a tag with an `id` that already exists will upsert instead of fail. Consider simplifying the seed logic to always attempt insertion (letting the unique constraint handle conflicts) or keeping the existing guard as a performance optimization.
- **All tag creation sites:** `AdminTagManager.createTag()`, `AdminDetailView.TagPickerSheet.createAndAssign()`, `TagEditorSheet.createAndAssign()`, `TagManagerSheet.createTag()`, `StairwayDetailPanel.createAndAssignInlineTag()`, `BulkOperationsSheet.createAndBulkAssign()`. All currently generate an `id` via `makeTagID(from:)` slug. With `@Attribute(.unique)`, inserting a tag with an existing slug will upsert. Verify this is acceptable or add a pre-check guard (most sites already have one).

## 7. Constraints

- **SwiftData schema migration:** Adding `@Attribute(.unique)` to an existing model is a lightweight migration in SwiftData, but the store must not contain duplicates when the new schema is applied. The one-time cleanup must run first.
- **CloudKit sync timing:** After the migration deletes local duplicates, CloudKit may attempt to re-sync the deleted duplicates back. With `@Attribute(.unique)` in place, these should upsert harmlessly. However, test this on a real device with an existing CloudKit dataset to confirm there is no sync loop.
- **Backward compatibility:** Older versions of the app (without `@Attribute(.unique)`) running on another device will continue to create duplicates locally. Those duplicates will sync to CloudKit but will be handled by upsert on devices running the new version. This is acceptable for a single-user app.
- **`compoundKey` backfill:** If Option A is chosen for `TagAssignment`, every existing `TagAssignment` record will have `compoundKey == ""` until the migration runs. The migration must set these before the new schema opens.

## 8. Acceptance Criteria

- [ ] `StairwayTag.id` has `@Attribute(.unique)` and SwiftData enforces it (inserting a duplicate `id` upserts instead of creating a second record).
- [ ] `TagAssignment` has a uniqueness mechanism (either `compoundKey` with `@Attribute(.unique)` or documented decision to use view-only dedup).
- [ ] One-time migration purges all existing duplicate `StairwayTag` records, keeping the earliest by `createdAt`.
- [ ] One-time migration purges all existing duplicate `TagAssignment` records, keeping the earliest by `assignedAt`.
- [ ] `BulkOperationsSheet` assign-tag Picker no longer shows duplicate tag names.
- [ ] `StairwayDetailPanel` tag checklist and assigned tags display no longer show duplicates (already patched; verify).
- [ ] App launches successfully on a device that has existing duplicate tags in the local SwiftData store.
- [ ] CloudKit sync does not re-introduce duplicates after migration (test on device with existing CloudKit data).
- [ ] Seed logic still works correctly on a fresh install with no prior CloudKit data.
- [ ] Feedback loop prompt has been run.

## 9. Files Likely Touched

| File | Change |
|------|--------|
| `ios/SFStairways/Models/StairwayTag.swift` | Add `@Attribute(.unique)` to `id` |
| `ios/SFStairways/Models/TagAssignment.swift` | Add `compoundKey` with `@Attribute(.unique)`, update `init` |
| `ios/SFStairways/Services/SeedDataService.swift` | Review/simplify `seedTagsIfNeeded()` for upsert behavior |
| `ios/SFStairways/SFStairwaysApp.swift` | Add one-time dedup migration call before container init |
| `ios/SFStairwaysMac/SFStairwaysMacApp.swift` | Same migration call for Mac target |
| `ios/SFStairwaysMac/Views/StairwayDetailPanel.swift` | Review existing dedup patches for consistency |
| `ios/SFStairwaysMac/Views/BulkOperationsSheet.swift` | Dedup the `ForEach(tags)` in `assignTagSection` Picker |
| `ios/SFStairwaysAdmin/Views/AdminDetailView.swift` | No change needed (already deduped) — verify only |
