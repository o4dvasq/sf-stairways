SPEC: HealthKit Data Accuracy Fix | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

## 1. Objective

HealthKit step counts for manually logged walks are wildly inaccurate. They show the entire day's step count (e.g., 10,846 steps for a single stairway) rather than steps for that specific walk. Remove the retroactive HealthKit pull feature for manually logged walks, and clear the bad data already stored.

## 2. Background

The `retroactivelyPullHealthKitStats()` function queries HealthKit for the full day (midnight to midnight) when a walk has no start/end timestamps. This produces misleading data: a stairway that takes 200 steps shows 10,000+ because it includes every step taken that day.

Active walks (started with "Start Walk") have actual start/end timestamps and produce accurate HealthKit data. The problem is only with manually logged walks.

## 3. Scope

**A. Remove retroactive HealthKit pull UI**
- Remove the "Logged manually · Tap to add HealthKit stats" button from the walkStatusCard in StairwayBottomSheet
- Remove the `showRetroactivePullAlert` state and associated confirmation alert
- Remove the `retroactivelyPullHealthKitStats()` function
- Remove the `canRetroactivelyPullStats` computed property from WalkRecord (or keep it but don't use it in UI)

**B. Clean up bad HealthKit data on existing manually logged walks**
- Add a one-time migration: for all WalkRecords where `walkStartTime == nil` (manually logged, no active session), clear `stepCount` and `elevationGain` back to nil.
- These fields were populated by the full-day query and are not meaningful per-stairway data.
- This can be added to SeedDataService alongside the existing cleanup migrations, gated by a UserDefaults key (e.g., `com.sfstairways.hasCleanedRetroactiveStats`).

**C. Keep HealthKit for active walks**
- The `endWalkSession()` flow that fetches HealthKit stats using the actual session start/end time is accurate and should remain unchanged.
- Active walks with real timestamps produce meaningful step count and elevation data.

## 4. Business Rules

- HealthKit data is only captured during active walk sessions (Start Walk → End Walk) where real timestamps exist.
- Manually logged walks (Mark as Walked) will have no HealthKit stats. This is correct because there's no reliable time window to query.
- Existing bad data (full-day step counts on manually logged walks) is cleared by the migration.

## 5. Data Model / Schema Changes

No schema changes. The `stepCount` and `elevationGain` fields on WalkRecord stay. They're just set to nil for manually logged walks via the migration, and never populated for manually logged walks going forward.

## 6. UI / Interface

**Bottom sheet walkStatusCard for a manually logged walk:**
- Shows: "Walked" + date. No HealthKit prompt, no "Tap to add HealthKit stats" button.

**Bottom sheet walkStatusCard for an active walk:**
- Unchanged. Shows steps, elevation if available.

**Bottom sheet statsRow:**
- Step count and elevation gained only display when the data came from an active walk session (i.e., the values are actually per-stairway, not per-day).

**macOS admin dashboard:**
- Step Count and Elevation Gained columns will show "—" for manually logged walks after the migration clears the bad data. This is correct.

## 7. Constraints

- Do not remove HealthKit integration entirely. Active walk sessions still benefit from accurate per-session data.
- The migration must be idempotent (safe to run multiple times).

## 8. Acceptance Criteria

- No "Tap to add HealthKit stats" button appears on any walked stairway
- Manually logged walks show no step count or elevation gained
- Active walks with timestamps still show their HealthKit data
- Existing bad data (full-day counts on manually logged walks) is cleared after first launch
- macOS dashboard shows "—" for step count/elevation on manually logged walks
- Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — remove retroactive pull UI, alert, function
- `ios/SFStairways/Models/WalkRecord.swift` — remove or deprecate `canRetroactivelyPullStats`
- `ios/SFStairways/Services/SeedDataService.swift` — add one-time cleanup migration for bad HealthKit data
