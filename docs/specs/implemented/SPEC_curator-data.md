# SPEC: Curator Data | Project: sf-stairways | Date: 2026-03-27 | Status: Ready for CoWork review

---

## 1. Objective

Add a curator data layer that lets Oscar record verified stairway measurements (step count, height) and descriptions as he walks each stairway. These values override the scraped catalog defaults wherever stairway stats are displayed. This establishes a personal authoritative dataset built over time through on-the-ground observation.

---

## 2. Scope

**In scope:**
- New `StairwayOverride` SwiftData model with CloudKit sync
- Inline curator fields on `StairwayDetail` (visible only for walked stairways)
- Display logic: verified values override catalog values app-wide, shown with a verified badge
- Progress tab stat calculations use verified values when available

**Out of scope:**
- HealthKit integration (future enhancement — manual entry only for now)
- Bulk import/export of curator data
- Curator data for un-walked stairways
- Changes to the three-state model, pin design, or map behavior
- Changes to the bundled `all_stairways.json` catalog

---

## 3. Business Rules

1. **One override per stairway.** `StairwayOverride` is keyed by `stairwayID`. At most one record exists per stairway.
2. **Walked-only gating.** The curator data section is visible and editable only when the stairway has a WalkRecord with `walked == true`.
3. **Override persistence on unmark.** If a walk is unmarked (walked → saved or walked → unsaved), the `StairwayOverride` record is NOT deleted. The curator section hides, but verified values continue to be used for display and stats calculations.
4. **Override deletion.** A `StairwayOverride` is only deleted if the user explicitly clears all three fields. An override with all-nil fields is removed from the store.
5. **Fallback chain.** For any stat display: use `StairwayOverride` value if non-nil → else use `Stairway` catalog value → else show nothing / placeholder.
6. **Verified badge.** When a displayed value comes from a `StairwayOverride`, show a small checkmark icon (`checkmark.seal.fill` SF Symbol) next to the value. No badge when showing catalog values.
7. **Step count semantics.** `verifiedStepCount` is the actual number of stair steps (physical stairs counted), not pedometer steps from a workout. The field label should say "Stair count" not "Steps" to distinguish from the existing `WalkRecord.stepCount` (which is pedometer steps).
8. **Height semantics.** `verifiedHeightFt` is elevation gain in feet, typically read from a watch workout summary. Label: "Height (ft)".

---

## 4. Data Model / Schema Changes

### New Model: StairwayOverride

SwiftData `@Model`, syncs to CloudKit. Lives alongside `WalkRecord` and `WalkPhoto`.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| stairwayID | String | "" | References `Stairway.id`. One override per stairway. |
| verifiedStepCount | Int? | nil | Actual stair count (physical stairs, not pedometer) |
| verifiedHeightFt | Double? | nil | Elevation gain in feet |
| description | String? | nil | Curator's description/blurb about the stairway |
| createdAt | Date | Date() | Auto-set on creation |
| updatedAt | Date | Date() | Updated on any field change |

**CloudKit considerations:**
- All fields have defaults (required for CloudKit compatibility)
- No unique constraints (CloudKit limitation — enforce one-per-stairway in app logic)
- No relationships to WalkRecord (independent records, both keyed by stairwayID)
- Register in `ModelContainer` alongside existing models in `SFStairwaysApp.swift`

### Existing Models: No Changes

`WalkRecord`, `WalkPhoto`, `Stairway` — all unchanged.

---

## 5. UI / Interface

### StairwayDetail.swift — Curator Data Section

**Location:** Below the walk toggle card, above the notes field. Only rendered when `walked == true` on the WalkRecord.

**Layout:**

```
┌─────────────────────────────────────┐
│  [Mini-map — unchanged]             │
│  [Stats row — unchanged, but now    │
│   uses override values + badge]     │
│  [Walk toggle card — unchanged]     │
│  [Date picker — unchanged]          │
│                                     │
│  ── Stairway Info ──────────────    │  ← section header
│                                     │
│  Stair count          [    142  ]   │  ← number field, placeholder "Add stair count"
│  Height (ft)          [   85.5  ]   │  ← decimal field, placeholder "Add height"
│                                     │
│  Description                        │
│  ┌─────────────────────────────┐    │
│  │ A beautiful mosaic stairway │    │  ← TextEditor, min 60px height
│  │ connecting Sanchez to...    │    │  ← placeholder "Add description..."
│  └─────────────────────────────┘    │
│                                     │
│  [Notes field — unchanged]          │
│  [Photo grid — unchanged]           │
└─────────────────────────────────────┘
```

**Field behavior:**
- Stair count: integer keyboard, saves on focus loss
- Height: decimal keyboard, saves on focus loss
- Description: multi-line TextEditor, saves on focus loss
- All fields create a `StairwayOverride` on first edit if none exists
- If user clears all three fields, the `StairwayOverride` is deleted

**Section header:** "Stairway Info" in `headline` weight, with a small `checkmark.seal.fill` icon in `forestGreen` if any verified value exists.

### Stats Row (StairwayDetail.swift)

The existing stats row already shows steps and height. Updated display logic:

- If `StairwayOverride.verifiedStepCount` exists: show that value + `checkmark.seal.fill` badge (small, inline, `forestGreen`)
- Else if `Stairway.heightFt` is available and a step count can be derived: show catalog value (no badge)
- Same pattern for height

**Label change:** When showing verified stair count, label reads "stairs" (not "steps") to distinguish from pedometer steps.

### StairwayRow.swift (List Tab)

The row already shows step/height stats. Same override fallback logic:
- Check `StairwayOverride` first, display with a small `checkmark.seal.fill` if verified
- Fall back to catalog values

### ProgressTab.swift

Stat calculations updated:
- "Height climbed" sum: use `StairwayOverride.verifiedHeightFt` when available, else `Stairway.heightFt`
- Step-related stats: same fallback pattern
- No visual change to the Progress tab layout — just the underlying numbers become more accurate

### Bottom Sheet (StairwayBottomSheet.swift)

If the bottom sheet shows step/height stats, apply the same fallback. The description does NOT appear in the bottom sheet (only on Detail view).

---

## 6. Integration Points

### StairwayStore

Add a helper method to `StairwayStore` (or a new lightweight helper) that resolves display values:

```
func resolvedStepCount(for stairway: Stairway, override: StairwayOverride?) -> Int?
func resolvedHeightFt(for stairway: Stairway, override: StairwayOverride?) -> Double?
```

These encapsulate the fallback chain so every call site doesn't reimplement it.

### @Query for StairwayOverride

Views that need override data will `@Query` for `StairwayOverride` records. Since there's no relationship to WalkRecord, lookup is by `stairwayID` match.

**Performance note:** With 382 stairways and at most 382 overrides, a full `@Query` fetched once is fine. No pagination or lazy loading needed.

---

## 7. Constraints

- No new third-party dependencies
- No server-side requirements
- No HealthKit (manual entry only — HealthKit is a future enhancement)
- No changes to the three-state model or pin design
- No changes to the bundled JSON catalog
- All SwiftData fields must have defaults (CloudKit requirement)
- No unique constraints on StairwayOverride (enforce in app logic)

---

## 8. Acceptance Criteria

- [ ] `StairwayOverride` model exists and syncs to CloudKit
- [ ] Curator section appears on StairwayDetail only for walked stairways
- [ ] Stair count field accepts integers, saves to StairwayOverride
- [ ] Height field accepts decimals, saves to StairwayOverride
- [ ] Description field accepts multi-line text, saves to StairwayOverride
- [ ] Verified values display with `checkmark.seal.fill` badge on Detail stats row
- [ ] Verified values display with badge on List tab rows (StairwayRow)
- [ ] Progress tab calculations use verified values when available
- [ ] Unmarking a walk hides curator section but preserves StairwayOverride data
- [ ] Re-marking a walk shows curator section with previously saved data
- [ ] Clearing all three fields deletes the StairwayOverride record
- [ ] App does not crash on launch after schema migration (test clean install + existing data)
- [ ] Feedback loop prompt has been run

---

## 9. Files Likely Touched

| File | Change |
|------|--------|
| `Models/StairwayOverride.swift` | **NEW** — SwiftData @Model |
| `SFStairwaysApp.swift` | Add `StairwayOverride` to ModelContainer schema |
| `Views/Detail/StairwayDetail.swift` | Add curator section, update stats row display logic |
| `Views/List/StairwayRow.swift` | Update stats display to use override fallback |
| `Views/Progress/ProgressTab.swift` | Update stat calculations with override fallback |
| `Views/Map/StairwayBottomSheet.swift` | Update stats display if applicable |
| `Models/StairwayStore.swift` | Add resolved value helper methods |
