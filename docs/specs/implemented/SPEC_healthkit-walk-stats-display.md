# SPEC: HealthKit Walk Stats Display

**Project:** sf-stairways
**Date:** 2026-03-28
**Status:** Ready for implementation
**Objective:** Improve HealthKit data visibility and diagnostics so Oscar can verify that walk stats (steps, elevation) are being correctly captured from active walks.

---

## 1. Objective

Oscar has completed active walks but does not see HealthKit-derived steps or elevation gain on his `WalkRecord` entries. The current implementation silently omits stats if HealthKit authorization fails, the query returns nil, or the user logged the walk via "Mark Walked" (manual) instead of "Start Walk" → "End Walk" (active session). This spec makes the capture method and HealthKit status visible, diagnostic, and retroactively accessible for manually logged walks.

**Success:** Oscar can immediately see:
- Whether each walked stairway was logged via active walk or manual mark
- Whether HealthKit is authorized and connected
- Why HealthKit stats are missing (authorization denied, manual walk method, or no matching data)
- Option to retroactively pull HealthKit stats for manually marked walks

---

## 2. Scope

**In scope:**
- Add walk method indicator to walked status card (active walk vs. manual mark)
- Add HealthKit authorization status badge to Settings / Walking section
- Provide diagnostic messaging when HealthKit stats are unavailable
- Implement retroactive HealthKit query for manually marked walks
- Surface elevation gain more prominently in stats row when available
- Log/display which walks were active vs. manual for debugging

**Out of scope:**
- Changing HealthKit query logic or time windows
- Modifying `HealthKitService.fetchWalkStats(from:to:)` signature
- CloudKit sync or multi-user HealthKit sharing
- Manual step entry or override

---

## 3. Business Rules

1. **Walk Method Tracking**
   - Active walks (started via "Start Walk" button) = `walkRecord.walkStartTime` and `walkRecord.walkEndTime` are set
   - Manual walks (via "Mark Walked" button) = `walkStartTime` and `walkEndTime` are nil
   - Only active walks automatically query HealthKit at completion

2. **HealthKit Authorization**
   - First time user taps "Start Walk": HealthKit authorization prompt fires (via `HealthKitService.requestAuthorization()`)
   - If user denies, subsequent active walks will not capture stats
   - Authorization state is persistent; querying is safe to retry

3. **Retroactive Stats Pull (Manual Walks)**
   - For walks marked manually (no `walkStartTime`), offer a button to query HealthKit for that calendar day
   - Query window: midnight to 11:59:59 PM of `walkRecord.dateWalked`
   - If stats found: update `stepCount` and `elevationGain` on record
   - Do not overwrite existing HealthKit data (if already captured from active walk)

4. **Diagnostic Messaging**
   - If `walkStartTime` is nil and stats are nil: display "Logged manually — tap to add HealthKit stats"
   - If active walk (`walkStartTime` present) and stats are nil: display "HealthKit data not found for this time window"
   - If active walk and stats present: show stats without commentary
   - If manual walk and stats are present (user manually pulled): show stats

5. **Settings Visibility**
   - Walking section in Settings displays HealthKit connection status
   - Show "HealthKit: Authorized" (green) or "HealthKit: Not Authorized" (gray/amber)
   - If not authorized, show button to open Settings and request permission

---

## 4. Data Model / Schema Changes

**No schema changes required.** `WalkRecord` already has:
- `stepCount: Int?`
- `elevationGain: Double?`
- `walkStartTime: Date?` (set at active walk start)
- `walkEndTime: Date?` (set at active walk end)
- `dateWalked: Date?` (available for all walks, manual or active)

**Transient state (not persisted):**
- HealthKit authorization status (queried from `HKHealthStore` as needed)
- Whether a retroactive pull is in progress (for UI loading state)

---

## 5. UI / Interface

### 5.1 Walk Status Card — Walk Method Indicator
**Location:** `StairwayBottomSheet.walkStatusCard`

When `walkRecord.walked == true`, show walk method label below the "Walked" checkmark:
```
✓ Walked                          [pencil icon]
  March 28, 2026
  Active Walk (with HealthKit)  [when walkStartTime is set and stats captured]
```

OR

```
✓ Walked                          [pencil icon]
  March 28, 2026
  Logged manually
  Tap to add HealthKit stats     [when walkStartTime is nil and stats are nil]
```

Implementation:
- Add small badge/chip below the date showing walk method
- If manual + no stats: make it interactive (tap to retry HealthKit pull)
- Use existing colors: `.secondary` for text, consider `.brandAmber` for "add stats" CTA

### 5.2 Stats Row — Diagnostic Messaging
**Location:** `StairwayBottomSheet.statsRow`

Current behavior: silently omits stats if nil.
New behavior:

```swift
// After verified stair count, height, and photos stats:
if let elevation = walkRecord?.elevationGain {
    Text("\(Int(elevation)) ft gained")
        .font(.caption)
        .foregroundStyle(.secondary)
} else if isWalked && walkRecord?.walkStartTime != nil {
    // Active walk with no HealthKit data
    Text("HealthKit data not found")
        .font(.caption)
        .foregroundStyle(.tertiary)
        .italic()
}
```

### 5.3 HealthKit Authorization Badge in Settings
**Location:** `SettingsView.walkingSection` (new sub-section)

Add a new row in the Walking section:
```
Walking
  ─────────────────────────────
  Hard Mode: [toggle]
  HealthKit: Authorized ✓       [if HKHealthStore.authorizationStatus is .sharingAuthorized]
```

OR (if not authorized):
```
HealthKit: Not Authorized        [tap to open Settings]
```

Implementation:
- Check `HKHealthStore().authorizationStatus(for: HKQuantityType(.stepCount))`
- Display status with indicator icon (green checkmark or gray/amber warning)
- If denied, provide a "Request Permission" button that triggers `HealthKitService.requestAuthorization()`

### 5.4 Retroactive HealthKit Pull Sheet
**Location:** `StairwayBottomSheet`, new modal triggered from walk status card

When user taps "Logged manually — Tap to add HealthKit stats", show a confirmation sheet:

```
Add HealthKit Stats for March 28?

Will search for steps and elevation data
recorded on your iPhone on this date.

[Cancel]  [Add Stats]
```

After tapping "Add Stats":
- Show loading indicator
- Query HealthKit for the full day (midnight to 11:59:59 PM)
- If found: update record and dismiss
- If not found: "No data found for this date" message
- Dismiss on completion

---

## 6. Integration Points

### 6.1 `HealthKitService.swift`
**New:** Add helper function to check authorization status without requesting:

```swift
static func isAuthorized() async -> Bool {
    guard HKHealthStore.isHealthDataAvailable() else { return false }
    let store = HKHealthStore()
    let stepType = HKQuantityType(.stepCount)
    // Check if read permission is already granted
    // (Note: HKHealthStore.authorizationStatus requires specifying the sample type)
    return await checkAuthorizationStatus(store: store, type: stepType)
}

private static func checkAuthorizationStatus(store: HKHealthStore, type: HKQuantityType) async -> Bool {
    // Use HKHealthStore.authorizationStatus(for:) if available (iOS 17+)
    // Falls back to attempting a query and catching authorization errors
    // Return true if permitted, false if denied or unavailable
}
```

### 6.2 `WalkRecord.swift`
**New computed property:**

```swift
var walkMethod: String {
    if walkStartTime != nil {
        return stepCount != nil || elevationGain != nil ? "Active Walk" : "Active Walk (no HealthKit data)"
    } else {
        return "Logged manually"
    }
}

var canRetroactivelyPullStats: Bool {
    // Return true if walk is marked, walked via manual method, and has no stats yet
    walked && walkStartTime == nil && stepCount == nil && elevationGain == nil
}
```

### 6.3 `StairwayBottomSheet.swift`
**Modifications:**

- Update `statsRow` to display diagnostic text when appropriate
- Update `walkStatusCard` to show walk method badge
- Add state variable: `@State private var isRetroactivePullInProgress = false`
- Add new method:
  ```swift
  private func retroactivelyPullHealthKitStats() {
      guard let record = walkRecord, let dateWalked = record.dateWalked else { return }
      isRetroactivePullInProgress = true
      Task {
          let start = Calendar.current.startOfDay(for: dateWalked)
          let end = Calendar.current.date(byAdding: .second, value: -1, to: Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: dateWalked)!))!
          let stats = await HealthKitService.fetchWalkStats(from: start, to: end)
          await MainActor.run {
              if let steps = stats.steps { record.stepCount = steps }
              if let elevation = stats.elevationFeet { record.elevationGain = elevation }
              record.updatedAt = Date()
              try? modelContext.save()
              isRetroactivePullInProgress = false
          }
      }
  }
  ```
- Add tap handler to walk method badge to trigger retroactive pull

### 6.4 `SettingsView.swift`
**Modifications:**

- Add `@State private var healthKitAuthStatus: Bool?` and loading state
- Add new section `walkingSection` (if not already present) containing:
  - Hard Mode toggle (existing)
  - HealthKit status row (new)
  - Request Permission button (if not authorized)
- Call `HealthKitService.isAuthorized()` in `.onAppear`

---

## 7. Constraints

1. **HealthKit Query Window**
   - Retroactive pulls query midnight-to-midnight of `dateWalked` only
   - HealthKit samples recorded outside that window will not be captured
   - This is acceptable because Oscar manually set `dateWalked`; if he walked multiple stairways on the same day and marked them on different dates, each query is independent

2. **Authorization Caching**
   - HealthKit authorization status is persistent; if user denies, app cannot re-request
   - User must manually grant via Settings > Privacy > Health
   - App can show "Open Settings" button but should not spam requests

3. **No Overwrite**
   - If record already has `stepCount` or `elevationGain`, retroactive pull does not overwrite
   - Preserves any manual entry or curator-verified values (if curator fields are used)

4. **No Workout Data Fallback**
   - Current logic uses step count and flights climbed, not `HKWorkout` objects
   - If user has a recorded workout session on HealthKit but no step data, elevation will be estimated as `flights * 10`
   - If neither exists, stats remain nil

---

## 8. Acceptance Criteria

- [ ] Walk method badge displays on walked stairway cards: "Active Walk" vs. "Logged manually"
- [ ] HealthKit status visible in Settings under Walking section (Authorized/Not Authorized)
- [ ] When HealthKit is denied, Settings shows "Request Permission" button that triggers auth flow
- [ ] Manual walks display "Tap to add HealthKit stats" when stats are missing
- [ ] Tapping the badge on manual walks opens a confirmation sheet
- [ ] Retroactive pull queries full day (midnight to 11:59:59 PM) and updates record if stats found
- [ ] No UI changes when pulling retroactive stats (no prompt blocking, silent update if successful)
- [ ] Active walks that completed without stats show "HealthKit data not found" in stats row (diagnostic)
- [ ] Elevation gain prominently displayed in stats row when available (existing behavior confirmed)
- [ ] No existing walk records are modified by this change; existing HealthKit data persists
- [ ] Can manually test with "Mark Walked" on a day with known HealthKit data, then tap badge to confirm retroactive pull works

---

## 9. Files Likely Touched

1. **`ios/SFStairways/Services/HealthKitService.swift`**
   - Add `isAuthorized()` method
   - Add `checkAuthorizationStatus()` helper

2. **`ios/SFStairways/Models/WalkRecord.swift`**
   - Add `walkMethod` computed property
   - Add `canRetroactivelyPullStats` computed property

3. **`ios/SFStairways/Views/Map/StairwayBottomSheet.swift`**
   - Update `statsRow` to show diagnostic messaging
   - Update `walkStatusCard` to show walk method badge
   - Add `@State` for retroactive pull loading
   - Add `retroactivelyPullHealthKitStats()` method
   - Add tap handler and retroactive pull sheet/alert

4. **`ios/SFStairways/Views/Settings/SettingsView.swift`**
   - Add `walkingSection` containing Hard Mode + HealthKit status
   - Add HealthKit status row with icon and description
   - Add "Request Permission" button if not authorized
   - Add `.task` or `.onAppear` to check authorization status

5. **`ios/SFStairways/Config/Info.plist`**
   - Verify `NSHealthShareUsageDescription` is present with user-friendly copy
   - Example: "SFStairways uses your step count and flights climbed to show elevation gain on walks."

---

## Implementation Notes

- **Incremental approach:** Start with walk method badge and Settings status, then add retroactive pull
- **Testing:** Walk a stairway using "Start Walk" to establish active walk baseline; then manually mark another walk and verify retroactive pull works
- **Logging:** Consider adding debug logging to `HealthKitService` queries to help diagnose future issues (log query window, returned stats, errors)
- **Edge case:** If user deletes HealthKit data mid-walk, query may return nil even for an active walk; current diagnostic message handles this gracefully

---
