SPEC: HealthKit Stats & iCloud Sync Diagnosis | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

---

## 1. Objective

Fix two independent issues discovered during use:

**A. Steps stat always shows dash.** Active walks completed via Start/End Walk are not capturing HealthKit step count or elevation data despite iOS Health permissions being granted. The "Total steps" stat card permanently displays "—".

**B. iCloud Sync shows "unavailable."** The CloudKit-backed ModelContainer is failing to initialize at app launch, causing the app to fall back to local-only storage. The Settings view shows a red "Sync unavailable" indicator.

## 2. Scope

- HealthKit query reliability and error surfacing in the active walk flow
- CloudKit ModelContainer initialization diagnosis and user-facing error detail
- No changes to data models or schema
- No new features; this is a diagnosis-and-fix spec

## 3. Business Rules

- Active walks (Start Walk / End Walk) should capture HealthKit steps and elevation when Health permissions are granted
- If HealthKit data cannot be captured, the user should see a clear indication of why (not just a silent dash)
- iCloud sync failures should surface actionable information (not just "unavailable")
- Manual walks (Mark Walked) should continue to show no HealthKit data (this is correct behavior)

## 4. Data Model / Schema Changes

None. All fields already exist on WalkRecord (stepCount, elevationGain, walkStartTime, walkEndTime).

## 5. UI / Interface

### Stats card ("Total steps")
- When all walked records have nil stepCount, show "— (no data)" or similar instead of bare "—"
- Consider: tapping the dash could show a brief explanation ("Steps are captured from active walks via Apple Health")

### Active walk completion
- After ending a walk, if HealthKit returned nil for both steps and elevation, show a toast or inline message: "Could not read Health data for this walk"
- The WalkRecord.walkMethod already returns "Active Walk (no HealthKit data)" for this case; make sure this is visible somewhere the user can see it (detail view, walk history)

### iCloud sync status
- The "Sync unavailable" detail text already shows the NSError localizedDescription. Verify this is displaying a useful message (not a raw domain/code string)
- Consider adding a "Troubleshoot" note listing common fixes: sign into iCloud, enable iCloud Drive, check CloudKit Dashboard

## 6. Integration Points

### HealthKit (`HealthKitService.swift`)
- `fetchWalkStats(from:to:)` currently swallows all errors: if `requestAuthorization` fails, it returns (nil, nil). If `querySum` returns nil, there's no distinction between "no data in window" and "query failed."
- Add logging or an error return so the caller knows WHY nil was returned
- Investigate: is there a timing issue where HealthKit hasn't flushed step data by the time the query runs immediately after ending the walk? If so, consider a short delay or a retry

### Walk finalization (`StairwayBottomSheet.swift`)
- `endWalkSession()` calls `fetchWalkStats` and passes results to `finalizeActiveWalk`. If both are nil, no feedback is given.
- Add a toast or state flag when HealthKit returns empty

### CloudKit init (`SFStairwaysApp.swift`)
- The catch block prints the error to console but the user only sees "Sync unavailable" + localizedDescription
- Diagnose: what specific error is being thrown? Common causes listed in comments: iCloud not signed in, CloudKit schema not deployed, Remote Notifications missing, Simulator
- If running on device with iCloud signed in, most likely cause is CloudKit schema not deployed in CloudKit Dashboard or entitlements mismatch

## 7. Constraints

- HealthKit queries are privacy-sensitive; iOS does not tell you whether read permission was denied (it just returns empty results). The app cannot distinguish "permission denied" from "no data recorded" at the API level.
- CloudKit diagnostics may require checking the CloudKit Dashboard manually; the app can only report the NSError it receives
- Any retry/delay for HealthKit must be minimal (1-2 seconds max) to avoid blocking the UI

## 8. Acceptance Criteria

- [ ] After completing an active walk on a physical device with Health permissions granted, stepCount and elevationGain are populated on the WalkRecord
- [ ] If HealthKit returns nil after an active walk, the user sees a visible indication (toast, label, or detail text) rather than silent failure
- [ ] The "Total steps" stat card shows the sum of captured steps (not dash) when at least one active walk has data
- [ ] iCloud sync status displays an actionable error message when unavailable
- [ ] Console logging added to HealthKit flow to aid future debugging (print start/end times, authorization status, query results)
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Services/HealthKitService.swift` — add error returns/logging, possible retry logic
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — surface HealthKit failure to user after endWalkSession
- `ios/SFStairways/Views/Progress/ProgressTab.swift` — improve "—" display for total steps when no data exists
- `ios/SFStairways/SFStairwaysApp.swift` — improve CloudKit error diagnosis/logging
- `ios/SFStairways/Views/Settings/SettingsView.swift` — improve sync unavailable detail text
