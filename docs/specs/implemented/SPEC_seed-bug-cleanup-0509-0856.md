SPEC: Seed-Bug WalkRecord Cleanup + target_list.json Removal | Project: sf-stairways | Date: 2026-05-09 | Status: Ready for implementation

---

## 1. Objective

Eliminate the residual effect of the long-deleted `seedIfNeeded()` function. Before commit `7748752` (April 11, 2026), every app launch loaded `target_list.json` from the bundle and wrote 8 `WalkRecord` rows with `walked: true` into SwiftData. Those rows were synced to the user's iCloud private database via CloudKit. The seed code is gone, but the records still live in iCloud for any Apple ID that ever ran a pre-fix build — including TestFlight invites, brief installs that were quickly deleted, and reinstalls. CloudKit, by design, persists private database data across app uninstalls. Those ghost records reappear as green pins on first launch of any new install.

Two things need to happen. First, `target_list.json` and the deprecated "Targets" data files need to be deleted from the iOS bundle and the repo's `/data/` directory — they are dead weight referencing functionality that is not coming back. Second, a one-shot targeted cleanup migration needs to delete the residual records from CloudKit so any user whose iCloud has them gets a clean slate on next launch.

## 2. Scope

Three pieces of work, all small:

- File deletions: `ios/SFStairways/Resources/target_list.json` and `data/target_list.json` from the repo. Confirm the iOS Xcode target membership is updated so the file is no longer copied into the app bundle.
- New `SeedDataService.cleanupSeedBugRecordsIfNeeded(modelContext:)` static method on the iOS target.
- Wire the new migration into `SFStairwaysApp.swift`'s existing `.onAppear` chain in `ContentView`.

Optional but recommended: mirror the cleanup inline in `SFStairwaysMacApp.swift` (matching the existing pattern where Mac inlines its tag-dedup migration because `SeedDataService.swift` is not in the Mac target). The Mac and iOS apps both write to the same CloudKit private database, so the migration only needs to run on one platform per Apple ID — but mirroring it on both is defensive and adds no real complexity.

Out of scope:
- Any changes to `WalkRecord` schema.
- Any changes to the legitimate user flow for marking walks (`markWalked` in `StairwayBottomSheet`).
- A general "Reset all walks" Settings option (a separate spec if you want one later).
- Architectural migration of `WalkRecord` away from CloudKit private database to Supabase (a much larger separate spec — `cleanupSeedBugRecordsIfNeeded` is a targeted patch, not an architectural rewrite).
- Admin and Mac targets are out of scope for the file deletion; only the iOS app's bundle reference matters because only iOS shipped the buggy seedIfNeeded.

## 3. Business Rules

The fingerprint of a seed-bug `WalkRecord` is precise:

- `stairwayID` is one of these eight: `16th-avenue-tiled-steps`, `hidden-garden-steps`, `lincoln-park-steps`, `vulcan-stairway`, `saturn-street-west-of-ord-street`, `pemberton-place-clayton-street-to-villa-terrace`, `filbert-street-sansome-street-to-montgomery-street`, `greenwich-street-sansome-street-to-montgomery-street`
- `walked` == true
- `dateWalked` is exactly 2026-03-09 or 2026-03-10 (Oscar's actual walk dates from the seed JSON)

The combination of all three conditions is a near-zero false-positive signature. A real user collision would require walking one of those eight famous stairs on those exact two dates (now over two months in the past), and already having a `WalkRecord` for it in iCloud. For any new user installing this version or later, no real walk would have those exact dates — the dates are baked-in artifacts of the seed JSON.

The migration must:
- Run at most once per install (gated by a UserDefaults boolean key).
- Be idempotent — manual flag clearing must produce the same end state without errors.
- Delete via SwiftData (`modelContext.delete(record)`) so the deletion propagates to CloudKit and to all other devices on the same Apple ID.
- Log the count of records deleted using the existing `[SeedDataService]` log prefix.

The deletions, once propagated to CloudKit, are permanent. CloudKit will not re-create the records because no code path exists to re-create them. This is a true one-shot fix.

## 4. Data Model / Schema Changes

None. This is read-and-delete only against existing `WalkRecord` rows.

## 5. UI / Interface

No UI changes. The migration runs silently on launch. The user simply sees their map without the eight ghost green pins on next launch after the update.

## 6. Integration Points

### Existing migration pattern to mirror

`SeedDataService.runTagDedupMigrationIfNeeded` (in `SeedDataService.swift`) and the newly-added `SeedDataService.deduplicateWalkRecordsIfNeeded` are the two closest precedents. Use the same structure:
- Private static `let` for the UserDefaults key.
- `guard !UserDefaults.standard.bool(forKey: ...) else { return }` at the top.
- `FetchDescriptor` with a `#Predicate` filter.
- `modelContext.delete(record)` per match.
- Single `try? modelContext.save()` at the end, only if anything was deleted.
- Final `print("[SeedDataService] ...")` summary line.
- Set the UserDefaults flag at the end.

Suggested key: `"hasCleanedSeedBugRecords_v1"`.

### Existing call chain to wire into

In `SFStairwaysApp.swift`, `ContentView`'s `.onAppear` already calls a sequence of migrations (lines 67–76 of the current file). Add the new migration call to the chain. Order matters slightly: this migration should run BEFORE any UI surface displays walks. The existing chain runs all migrations on `.onAppear` of `ContentView`, which fires before the map renders, so adding it anywhere in that chain is fine. Suggested order:

```swift
SeedDataService.runTagDedupMigrationIfNeeded(modelContext: modelContainer.mainContext)
SeedDataService.deduplicateWalkRecordsIfNeeded(modelContext: modelContainer.mainContext)
SeedDataService.cleanupSeedBugRecordsIfNeeded(modelContext: modelContainer.mainContext)
SeedDataService.seedTagsIfNeeded(modelContext: modelContainer.mainContext)
SeedDataService.cleanUnwalkedRecordsIfNeeded(modelContext: modelContainer.mainContext)
```

Putting it after `deduplicateWalkRecordsIfNeeded` ensures dedup runs first (so we cleanup against a deduped set), but the order is not load-bearing — both migrations are idempotent.

### Mac target mirroring

If choosing to mirror inline in `SFStairwaysMacApp.swift`, follow the existing inline pattern at lines 64–96 of that file. Use the same UserDefaults key (`"hasCleanedSeedBugRecords_v1"`) — UserDefaults is per-app, so the iOS and Mac apps will each gate their own pass independently. That is fine; the migration is idempotent.

## 7. Constraints

- **CloudKit propagation is asynchronous.** After `modelContext.save()`, deletions sync to CloudKit in the background and then fan out to other devices. The local UI updates immediately. There is no guarantee about how fast remote devices see the deletion, but for the affected user, the local store reflects the cleanup before the map renders.
- **The migration must run before the map renders.** `ContentView.onAppear` fires before the `MapTab` body evaluates. Confirmed by reading the existing code — the four other migrations already run there with no observed UI flicker. The new migration is the same pattern.
- **The migration runs even if the user has never had the seed bug.** If their iCloud is clean, the FetchDescriptor returns zero rows, no deletions happen, and the UserDefaults flag is set anyway. Subsequent launches no-op.
- **The eight stairwayIDs must match exactly.** They are stable strings from the original `target_list.json`. Reproduced in the spec for fidelity. The implementation should declare them as a static constant set, not inline them in the predicate.
- **Date matching must be exact.** Use `Calendar.current` or a `DateFormatter` with `yyyy-MM-dd` against the start-of-day for 2026-03-09 and 2026-03-10. The original seed parsed `"2026-03-09"` and `"2026-03-10"` strings into `Date` via a `DateFormatter` with format `yyyy-MM-dd`. Use the same approach to ensure the dates match. Do NOT use a date-range comparison — exact match keeps the false-positive risk near zero.
- **`target_list.json` deletion from the bundle:** removing the file from the filesystem alone is not sufficient — Xcode tracks bundle resources via the `.pbxproj`. Either delete via Xcode UI (drag to trash, choose "Move to Trash"), or remove the file reference from `project.pbxproj` and verify the file no longer appears in the SFStairways target's "Copy Bundle Resources" build phase. The `/data/target_list.json` is just a repo-level data file and can be deleted with `rm` and committed.

## 8. Acceptance Criteria

- [ ] `ios/SFStairways/Resources/target_list.json` no longer exists in the repo working tree.
- [ ] `data/target_list.json` no longer exists in the repo working tree.
- [ ] Building the SFStairways iOS target produces an `.app` bundle that does not contain `target_list.json`. Verify with `unzip -l SFStairways.ipa | grep target_list` — should return nothing.
- [ ] `SeedDataService.cleanupSeedBugRecordsIfNeeded(modelContext:)` exists with the same signature shape as the other migrations.
- [ ] On a device whose iCloud has the eight seed records, first launch after the update logs `[SeedDataService] Seed bug cleanup: removed 8 records` (or fewer if some were already user-deleted).
- [ ] Subsequent launches log nothing for this migration.
- [ ] On a clean device (no seed records in iCloud), first launch logs `[SeedDataService] Seed bug cleanup: no matching records` (or simply nothing if the implementation chooses to log only on non-zero deletions — either is acceptable; the no-op should not log noisy output).
- [ ] After the cleanup runs on Oscar's device with the iOS app open, the eight records are gone from the local store, and within a reasonable time (CloudKit's normal sync window) they are also gone from any other device on his Apple ID — including the Mac app if installed.
- [ ] No regressions to the existing tag dedup, walk record dedup, tag seed, or unwalked cleanup migrations.
- [ ] No regressions to the user's ability to mark a stairway as walked. Specifically: walking Lincoln Park Steps today on a fresh install creates a `WalkRecord` with today's date, the migration does not delete it because the date does not match the seed dates.
- [ ] If mirrored to the Mac app, same acceptance criteria apply on macOS.
- [ ] Feedback loop prompt has been run.

## 9. Files Likely Touched

| File | Change |
|------|--------|
| `ios/SFStairways/Resources/target_list.json` | DELETE |
| `data/target_list.json` | DELETE |
| `ios/SFStairways/Services/SeedDataService.swift` | Add static method `cleanupSeedBugRecordsIfNeeded(modelContext:)`, plus a private `hasCleanedSeedBugRecordsKey` constant and a static `seedBugStairwayIDs: Set<String>` constant |
| `ios/SFStairways/SFStairwaysApp.swift` | Add one line in the `.onAppear` chain: `SeedDataService.cleanupSeedBugRecordsIfNeeded(modelContext: modelContainer.mainContext)` |
| `ios/SFStairways.xcodeproj/project.pbxproj` | Auto-updated when the bundle resource reference is removed via Xcode UI |
| `ios/SFStairwaysMac/SFStairwaysMacApp.swift` | OPTIONAL — mirror the migration inline, matching the existing tag-dedup inline pattern |
| `docs/PROJECT_STATE.md` | OPTIONAL — add a one-line entry under Recent Completions noting the seed-bug cleanup migration shipped |
| `docs/DECISIONS.md` | OPTIONAL — append a short entry explaining why a targeted CloudKit cleanup was chosen over a wholesale wipe or an architectural Supabase migration |

No changes to `StairwayBottomSheet.swift`, `WalkRecord.swift`, `SeedDataService.swift`'s other migrations, or any view-layer code.
