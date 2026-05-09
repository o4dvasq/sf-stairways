SPEC: Restore Missing Implementations — ConfettiView + WalkRecord Dedup | Project: sf-stairways | Date: 2026-05-08 | Status: Ready for implementation

---

## 1. Objective

Restore two implementations that were referenced in `main` but never actually written. The iOS app currently does not compile because of these missing symbols, which blocks Archive and App Store distribution.

The two missing pieces are:
- A `ConfettiView` SwiftUI view, used as a celebration overlay in `StairwayBottomSheet`.
- A `SeedDataService.deduplicateWalkRecordsIfNeeded(modelContext:)` static method, called from `SFStairwaysApp` on app launch as a one-time data migration.

Both call sites already exist. This spec is about adding the definitions so the existing call sites compile and behave as originally intended.

## 2. Scope

Two new additions, both in the main iOS app target only:

- New SwiftUI view file: `ConfettiView.swift`. Must compile against the existing call site at `StairwayBottomSheet.swift:189` without modifying that call site.
- New static method on `SeedDataService`: `deduplicateWalkRecordsIfNeeded(modelContext: ModelContext)`. Must follow the same pattern as the existing migrations in that file.

Out of scope:
- Any changes to `StairwayBottomSheet.swift` or `SFStairwaysApp.swift` call sites.
- Any changes to the `WalkRecord` model schema.
- Mac target (`SFStairwaysMac`) — does not reference either symbol.
- Admin target (`SFStairwaysAdmin`) — does not reference either symbol.

## 3. Business Rules

### ConfettiView
- The view is rendered as a full-screen overlay on `StairwayBottomSheet` for approximately 2.4 seconds when a user marks a stairway as walked. The trigger and timing are already wired up by the host view (state vars `showConfetti`, transitions, animation values).
- The view must not block user interaction. The host already applies `.allowsHitTesting(false)`, so the view's own hit-testing behavior is not load-bearing, but the view should also be visually transient (no permanent state, no buttons).
- The view should use the app's existing color palette (see `Resources/AppColors.swift`) where reasonable. Forest green is the celebration color elsewhere in the app; complementary accents are acceptable.
- The view must not allocate persistent timers or background work outside its lifecycle. When SwiftUI removes the view, all animation work must stop. Memory use must not grow over repeated celebrations.

### WalkRecord deduplication
- The function performs a one-time cleanup: for each `stairwayID`, if multiple `WalkRecord` rows exist, keep the one with the earliest `createdAt` and delete the others.
- "Multiple rows" can arise from CloudKit sync because `WalkRecord` has no `@Attribute(.unique)` constraint. This migration cleans up the existing local data; preventing future duplicates is a separate concern.
- The function must be gated by a `UserDefaults` boolean key so it runs once per device install.
- The function must be idempotent — running it a second time (e.g., after manually clearing the gate) must produce the same end state without errors.
- Logs must use the existing `print("[SeedDataService] ...")` format.

## 4. Data Model / Schema Changes

None. `WalkRecord` is read-modify only. No new fields, no `@Attribute` annotations, no migration plan changes. CloudKit schema is untouched.

## 5. UI / Interface

### ConfettiView visual behavior

The view should render a brief celebratory particle animation. Reference behavior:

- Approximately 40 to 80 particles, emitted near the top of the view's bounds and falling toward the bottom under simulated gravity, with horizontal jitter.
- Each particle has a randomized color (palette: forest green, plus a small set of complementary celebratory hues — gold, coral, sky blue, lavender are reasonable defaults), randomized rotation, and randomized fall speed.
- Particles fade out as they reach the bottom of the screen.
- Total visible duration approximately 2.0 to 2.4 seconds, matching the host's hide timer at `StairwayBottomSheet.swift:744`.

### Reference implementation

A pure SwiftUI implementation using `TimelineView(.animation)` and per-particle randomized state is recommended for simplicity and maintainability. A `CAEmitterLayer` wrapped in `UIViewRepresentable` is acceptable if performance becomes a concern, but the SwiftUI approach is preferred for a single-shot 2.4-second animation.

Sketch (reference only — Claude Code should refine):

```swift
import SwiftUI

struct ConfettiView: View {
    private let particleCount = 60
    private let duration: Double = 2.4
    @State private var startTime = Date()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSince(startTime)
                    // For each particle, compute position from elapsed and per-particle seed,
                    // then context.fill(...) a small rotated rect with the particle's color.
                }
            }
            .ignoresSafeArea()
        }
    }
}
```

Implementation considerations Claude Code should resolve:
- Per-particle seeds should be generated once on view init (not on every frame).
- Color randomization should use a fixed palette, not arbitrary HSB values.
- Particle shape can be small rotated rectangles or rounded rects; circles are also acceptable.

### WalkRecord dedup

No UI surface. The function runs silently on launch.

## 6. Integration Points

### Existing call sites (already in place — do not modify)

`StairwayBottomSheet.swift` lines 187 to 194:
```swift
.overlay {
    if showConfetti {
        ConfettiView()
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}
.animation(.easeInOut(duration: 0.4), value: showConfetti)
```

`SFStairwaysApp.swift` line 72, inside `ContentView`'s `.onAppear` block, between `runTagDedupMigrationIfNeeded` and `seedTagsIfNeeded`:
```swift
SeedDataService.deduplicateWalkRecordsIfNeeded(modelContext: modelContainer.mainContext)
```

### Existing migration pattern (mirror this)

`SeedDataService.runTagDedupMigrationIfNeeded` (lines 11 to 58 of `SeedDataService.swift`) is the closest precedent. It uses a `UserDefaults` gate, a `FetchDescriptor` to load all rows, in-memory grouping by key, deletion of duplicates, single `try? modelContext.save()`, and a final `print` summary. The new `deduplicateWalkRecordsIfNeeded` should follow this structure.

Suggested gate key: `"hasRunWalkRecordDedupMigration_v1"` (matches the `_v1` suffix convention used by the existing tag dedup gate).

## 7. Constraints

- The fix must not require touching `StairwayBottomSheet.swift` or `SFStairwaysApp.swift`. The two existing call sites are correct as written; only the missing definitions need to be added.
- The new `ConfettiView` file must be added to the `SFStairways` iOS target only. It should not be added to the `SFStairwaysMac` or `SFStairwaysAdmin` targets unless those targets later import the same view.
- The dedup migration must run before any UI that displays `WalkRecord` data, to avoid showing duplicates before they are cleaned up. Calling it from `SFStairwaysApp.body.WindowGroup.ContentView.onAppear` (the existing call site) is sufficient — that fires before the user can navigate to any walk-displaying view.
- After dedup deletes local duplicates, CloudKit may re-sync them down. Without a `@Attribute(.unique)` constraint on `WalkRecord`, those re-synced duplicates would re-introduce the bug. This SPEC does not address that — it is a known limitation, and a follow-up spec should add the unique constraint and corresponding schema migration. For now, the one-time dedup is sufficient because Oscar's local data is the primary case to clean up.
- The confetti animation must not cause noticeable jank during the celebration. If the SwiftUI Canvas approach causes dropped frames at 60 particles on a baseline iPhone (iPhone 13 or older), reduce the particle count or switch to `CAEmitterLayer`.

## 8. Acceptance Criteria

- [ ] `ios/SFStairways/Views/Components/ConfettiView.swift` (or equivalent path under the Views/ tree) exists, defines a `struct ConfettiView: View` with a no-argument initializer.
- [ ] `SeedDataService.deduplicateWalkRecordsIfNeeded(modelContext:)` exists with the same signature shape as the other migrations.
- [ ] The SFStairways iOS target compiles cleanly (no errors, no warnings introduced by these additions).
- [ ] `xcodebuild -scheme SFStairways -destination 'generic/platform=iOS' archive` succeeds end-to-end.
- [ ] `xcodebuild -scheme SFStairwaysAdmin -destination 'generic/platform=iOS' archive` also succeeds (the original Archive blocker, plus the iPad orientation fix already landed).
- [ ] On a real device, marking a stairway as walked produces a visible confetti animation for approximately 2.4 seconds, with no dropped frames perceptible.
- [ ] Confetti does not block taps on UI behind it.
- [ ] On a device with existing duplicate `WalkRecord` rows, first launch after install produces a console log line of the form `[SeedDataService] WalkRecord dedup: removed N duplicates`. Subsequent launches log nothing for this migration.
- [ ] After dedup, only one `WalkRecord` per `stairwayID` remains in the local store, and it is the one with the earliest `createdAt` from the original duplicates.
- [ ] No regressions to the existing tag dedup migration, tag seed, or unwalked cleanup migrations.
- [ ] Feedback loop prompt has been run.

## 9. Files Likely Touched

| File | Change |
|------|--------|
| `ios/SFStairways/Views/Components/ConfettiView.swift` | NEW — defines `struct ConfettiView: View` |
| `ios/SFStairways/Services/SeedDataService.swift` | Add static method `deduplicateWalkRecordsIfNeeded(modelContext:)` and a private `hasRunWalkRecordDedupKey` constant |
| `ios/SFStairways.xcodeproj/project.pbxproj` | Auto-updated by Xcode when the new ConfettiView.swift is added to the SFStairways target |

No changes to `StairwayBottomSheet.swift`, `SFStairwaysApp.swift`, `WalkRecord.swift`, or any Mac/Admin target files.
