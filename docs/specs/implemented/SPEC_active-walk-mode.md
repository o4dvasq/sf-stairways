SPEC: Active Walk Mode | Project: sf-stairways | Date: 2026-03-28 | Status: Ready for implementation

## 1. Objective

Add an optional "active walk" flow: the user taps "Start Walk" before beginning, the app records a precise start timestamp, and when they tap "Done" the app pulls step count and elevation gain from HealthKit for that exact time window and pre-fills those fields on the walk record. This gives the app a precise time window for photo suggestions (replacing the full-day approximation from SPEC_photo-time-window-suggestions) and captures step/elevation data automatically.

## 2. Scope

- "Start Walk" button in `StairwayBottomSheet` for unwalked stairways
- Active walk state: running timer displayed in the bottom sheet
- "End Walk" button finalizes the session, triggers HealthKit query, auto-fills steps and elevation
- Walk is marked as walked automatically on end, with `dateWalked` set to session start date
- Precise time window (start/end) stored on `WalkRecord` for use by photo suggestions
- Existing after-the-fact "Mark Walked" workflow is fully preserved. This is additive.

## 3. Business Rules

- **Start Walk:** Available for stairways that are not currently walked (unsaved or saved state) and do not have another active session in progress. Shown alongside existing action buttons in the bottom sheet's collapsed content.
- **Single session:** Only one active walk session at a time (app-wide). Starting a walk on stairway A while stairway B has an active session shows a toast: "Finish your walk at [Name] first."
- **Timer:** Displays elapsed time (MM:SS) in the bottom sheet while session is active. Does not need to run in background; pausing when backgrounded is acceptable.
- **End Walk:** Finalizes session. Triggers HealthKit query for the session time window. Marks walk as walked. Sets `dateWalked` to session start time. Saves `walkStartTime` and `walkEndTime` on the `WalkRecord`.
- **HealthKit query:** Queries `HKQuantityType` step count and flights climbed for the session window. Results pre-fill `stepCount` on `WalkRecord` and a new `elevationGain` field.
- **HealthKit unavailable or denied:** Walk is still finalized normally. Steps and elevation remain nil. No error shown; silent fallback.
- **Cancel Walk:** User can cancel an active session without logging the walk. No `WalkRecord` changes. Requires confirmation: "Cancel this walk? Your progress won't be saved."
- **Hard Mode interaction:** If Hard Mode is enabled, the proximity check still applies to "Start Walk" (same gate as "Mark Walked"). `hardModeAtCompletion` is stamped true on end if Hard Mode is active.
- **Photo suggestions:** When a walk has `walkStartTime`/`walkEndTime` set, SPEC_photo-time-window-suggestions uses those precise timestamps instead of the full calendar day.

## 4. Data Model / Schema Changes

**WalkRecord — add three fields:**

```swift
var elevationGain: Double?    // Feet climbed, from HealthKit, nil if not captured
var walkStartTime: Date?      // Precise session start, used for photo suggestion window
var walkEndTime: Date?        // Precise session end, used for photo suggestion window
```

All optional with nil defaults. CloudKit compatible, no migration risk.

Note: `hardMode`, `proximityVerified`, and `hardModeAtCompletion` already exist on `WalkRecord`. No conflicts with this spec.

**Active session state (not persisted):**

New `@Observable` class `ActiveWalkManager`:

```swift
@Observable class ActiveWalkManager {
    var activeStairwayID: String? = nil
    var activeStairwayName: String? = nil    // for toast message
    var sessionStartTime: Date? = nil
    var elapsedSeconds: Int = 0
    // Timer.publish on main RunLoop, updates elapsedSeconds every second
}
```

Injected as environment object from `SFStairwaysApp.swift`. Not persisted to SwiftData. If the app is killed, the session is lost (accepted tradeoff for simplicity).

## 5. UI / Interface

### Bottom Sheet — Collapsed Content (Start Walk)

For unwalked stairways, add a "Start Walk" button to the `actionButtons` section. It sits alongside the existing Save/Mark Walked buttons:

**Unsaved state:**
```
[Start Walk]   [Save]   [Mark Walked]
```

**Saved state:**
```
[Start Walk]   [Unsave]   [Mark Walked]
```

"Start Walk" uses `forestGreen` fill (same as "Mark Walked") to indicate it's the primary walk action. If Hard Mode is enabled and the user is outside proximity range, both "Start Walk" and "Mark Walked" are disabled with the existing Hard Mode message.

### Bottom Sheet — Active Session Banner

When this stairway has an active session, replace the `walkStatusCard` and `actionButtons` areas with an active session banner:

```
┌─────────────────────────────────────────┐
│  Walking now                            │
│  04:32                                  │  elapsed timer, large monospaced font
│                                         │
│  [End Walk]              [Cancel]       │  End = walkedGreen, Cancel = secondary
└─────────────────────────────────────────┘
```

- The banner occupies the same vertical space as the walk status card + action buttons (keeps collapsed detent height stable).
- Timer updates every second via `Timer.publish(every: 1, on: .main, in: .common)`.
- "End Walk" triggers finalization flow.
- "Cancel" shows a confirmation alert, then discards the session if confirmed.

### Bottom Sheet — Post-Session

After "End Walk", the walk is marked as walked. The existing `walkStatusCard` now shows the walked state with date. If HealthKit returned data:
- `stepCount` appears in `statsRow` (already displayed when present)
- `elevationGain` appears as a new stat in `statsRow`: "[X] ft gained"

The elevation stat uses the same `.caption` / `.secondary` style as existing stats. If `elevationGain` is nil, it's simply not shown.

### Existing "Mark Walked" Flow

Completely unchanged. "Mark Walked" still works exactly as before for after-the-fact logging. Active Walk Mode is additive.

## 6. Integration Points

**New file: `Services/HealthKitService.swift`**

```swift
import HealthKit

struct HealthKitService {
    static func fetchWalkStats(from start: Date, to end: Date) async -> (steps: Int?, elevationFeet: Double?)
}
```

- Check `HKHealthStore.isHealthDataAvailable()` first (false on simulator).
- Request authorization for `.stepCount` and `.flightsClimbed` (read only).
- Use `HKStatisticsQuery` with `.cumulativeSum` for the session interval.
- Convert flights climbed to feet: 1 flight = 10 feet.
- If authorization denied or data unavailable, return `(nil, nil)`.
- Required: `NSHealthShareUsageDescription` in Info.plist: `"SF Stairways reads step count and elevation from your walks."`

**New file: `Services/ActiveWalkManager.swift`**

`@Observable` class managing session state and timer. Methods:
- `startWalk(stairwayID:name:)` — sets active IDs, records start time, starts timer
- `endWalk()` — records end time, stops timer, returns `(startTime, endTime)`
- `cancelWalk()` — clears all state, stops timer
- `isActive(for stairwayID:) -> Bool` — checks if this stairway has the active session
- `var hasActiveSession: Bool` — true if any session is running

**`SFStairwaysApp.swift`:**

Add `let activeWalkManager = ActiveWalkManager()` and inject via `.environment(activeWalkManager)`.

**`StairwayBottomSheet.swift`:**

- Add `@Environment(ActiveWalkManager.self) private var activeWalkManager`
- Modify `actionButtons`: add "Start Walk" button for unwalked states
- Add active session banner view, shown when `activeWalkManager.isActive(for: stairway.id)`
- "End Walk" action: call `activeWalkManager.endWalk()`, get time window, fire HealthKit query, update `WalkRecord` with steps/elevation/startTime/endTime, mark walked, save context
- "Cancel Walk" action: show confirmation alert, then `activeWalkManager.cancelWalk()`
- Add elevation gain display in `statsRow`

**Relationship to other specs:**

- **SPEC_photo-time-window-suggestions:** The suggestion service checks `walkStartTime`/`walkEndTime` first, falls back to full-day window if nil. No code changes needed in photo suggestions to support this; the fields just need to exist.
- **SPEC_photo-persistence-fix:** Independent. No conflicts.
- **SPEC_photo-camera-roll-fix:** Independent. No conflicts.

## 7. Constraints

- `HealthKit` framework only. No new third-party dependencies.
- HealthKit is not available on simulator. Guard with `HKHealthStore.isHealthDataAvailable()`.
- Timer does not need background execution. Pausing when backgrounded is acceptable.
- Active session state is in-memory only. Not persisted across app kills. This is an accepted tradeoff.
- `NSHealthShareUsageDescription` must be added to Xcode Info tab (read-only HealthKit access).
- No `NSHealthUpdateUsageDescription` needed. The app reads HealthKit, does not write to it.
- All new `WalkRecord` fields have nil defaults for CloudKit compatibility.
- The bottom sheet's collapsed detent height (`.height(390)`) must remain stable whether showing the normal action buttons or the active session banner. Test both states.

## 8. Acceptance Criteria

- [ ] "Start Walk" button appears in the bottom sheet for unwalked stairways (unsaved and saved states)
- [ ] Tapping "Start Walk" begins a session: timer appears in the bottom sheet, updates every second
- [ ] Only one active session allowed at a time. Toast shown if user tries to start a second.
- [ ] "End Walk" finalizes walk: marked as walked, `dateWalked` set to session start date, `walkStartTime`/`walkEndTime` saved
- [ ] If HealthKit authorized and data exists for session window, `stepCount` and `elevationGain` pre-filled on `WalkRecord`
- [ ] If HealthKit denied or unavailable, walk finalizes normally with nil steps/elevation. No error shown.
- [ ] "Cancel Walk" with confirmation discards session, no changes to `WalkRecord`
- [ ] Hard Mode proximity check gates "Start Walk" the same way it gates "Mark Walked"
- [ ] Existing "Mark Walked" after-the-fact flow is completely unchanged
- [ ] Elevation gain displays in stats row when available
- [ ] No crash on simulator (HealthKit unavailable guard in place)
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Models/WalkRecord.swift` — add `elevationGain`, `walkStartTime`, `walkEndTime`
- `ios/SFStairways/Services/HealthKitService.swift` — new file, step + elevation query for time window
- `ios/SFStairways/Services/ActiveWalkManager.swift` — new file, session state + timer
- `ios/SFStairways/SFStairwaysApp.swift` — inject `ActiveWalkManager` as environment object
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — add "Start Walk" button, active session banner, "End Walk"/"Cancel Walk" actions, elevation stat display
- Xcode Info tab — add `NSHealthShareUsageDescription`
