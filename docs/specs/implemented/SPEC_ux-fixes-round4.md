SPEC: UX Fixes Round 4 — HealthKit, Mark/Unmark, Photo Badges, iCloud | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

Depends on: Nothing

---

## 1. Objective

Fix four issues identified during field testing on 2026-03-29:

A. HealthKit data not captured during active walks (steps/elevation always nil)
B. Redundant "Mark as Walked" buttons in the unwalked bottom sheet state
C. Red icloud.slash badges on photos when sync is unavailable
D. iCloud sync unavailable due to SwiftDataError 1 (schema mismatch)

## 2. Scope

**In scope:**
- Diagnose and fix HealthKit data capture failure
- Consolidate mark-walked buttons; replace "Not Walked" button with tappable checkmark + confirmation
- Fix photo badge display when Supabase/iCloud is unavailable
- Diagnose and fix CloudKit/SwiftData schema mismatch

**Out of scope:**
- New features or views
- Progress tab changes
- Neighborhood system changes

## 3. Issues and Fixes

### A. HealthKit Data Not Captured

**Symptom:** After ending an active walk, a notification/toast appears saying the app could not read Health data. Steps and elevation are nil on every WalkRecord despite HealthKit permissions being granted in iOS Settings.

**Root cause investigation:** The `HealthKitService.fetchWalkStats` function calls `requestAuthorization(toShare: [], read:)` every time, even though permissions are already granted. If this call throws (which it can in certain states, e.g., background execution, HealthKit store temporarily unavailable), the function returns (nil, nil) and the error is silently swallowed.

**Fixes:**

1. **Capture and log the actual error from requestAuthorization.** Change the catch block in `requestAuthorization` to print the error before returning false:
   ```swift
   } catch {
       print("[HealthKit] Authorization request threw: \(error)")
       return false
   }
   ```

2. **Don't re-request authorization on every query.** Use `isAuthorized()` to check if authorization has already been granted. Only call `requestAuthorization` if it hasn't. This avoids triggering edge cases where re-requesting throws.

3. **Increase the delay before querying.** The current 1-second delay may not be enough. HealthKit can take 2-3 seconds to flush pedometer data after motion stops. Increase to 2 seconds. This is a workaround; the long-term fix would be to use an HKObserverQuery or retry pattern.

4. **Add a retry.** If both steps and elevation come back nil, wait 2 more seconds and try once more before giving up. Log both attempts.

5. **Surface the actual failure reason to the user.** Update the toast in `endWalkSession()` to distinguish between "authorization failed" and "no data returned":
   - If authorization failed: "Health access denied — check Settings > Health > SF Stairways"
   - If authorized but no data: "No step data recorded for this walk (try a longer walk)"

6. **Return error info from fetchWalkStats.** Change the return type to include an optional error string so the caller can display appropriate feedback:
   ```swift
   static func fetchWalkStats(from start: Date, to end: Date) async -> (steps: Int?, elevationFeet: Double?, error: String?)
   ```

### B. Redundant Mark-Walked Buttons + Not Walked Replacement

**Symptom:** In the unwalked state, the bottom sheet shows three action options: a large "Mark as Walked" green button (in `walkedStatusSection`) AND "Start Walk" + "Mark Walked" (in `actionButtons`). "Mark as Walked" and "Mark Walked" are redundant.

**Fix:**

1. **Remove the large "Mark as Walked" button from `walkedStatusSection`.** In the unwalked state, `walkedStatusSection` should show nothing (or a minimal "Not yet walked" label). All actions live in `actionButtons`.

2. **In the unwalked state, `actionButtons` shows only:** "Start Walk" and "Mark Walked" (as today, but now they're the only action buttons, no duplication).

3. **Replace the "Not Walked" button with a tappable checkmark on the walked status banner.** When a stairway is marked as walked, the green "Walked" banner already shows a checkmark icon and date. Make the checkmark/banner itself tappable. On tap, show a confirmation alert:
   - Title: "Mark as Not Walked?"
   - Message: "This will remove the walk record for this stairway."
   - Buttons: "Cancel" (default) and "Remove" (destructive)
   - On confirm: call the existing `removeRecord()` function

4. **Remove the "Not Walked" `ActionButton` entirely from the walked state's `actionButtons`.** The only way to unmark is now through the confirmation dialog on the walked banner.

### C. Red icloud.slash Badges on Photos

**Symptom:** Every local photo in the carousel shows a red `icloud.slash` badge. This looks like an error state even though the photos are saved locally and functional.

**Context:** The badge logic in `PhotoCarousel` (line 62-69) shows `icloud.slash` on all `.local` photos. Red = upload failed (photo ID in `failedPhotoIDs`), gray = pending upload. When Supabase is unavailable (no account, no connection), ALL local photos show this badge.

**Fix:**

1. **Hide the cloud badge entirely when the user is not signed into Supabase.** If there's no authenticated user (`userId == nil`), the cloud sync badge is meaningless. Don't show it.

2. **When signed in but sync unavailable:** Show a single, subtle indicator at the section level ("Photos not syncing") rather than per-photo badges. Individual red badges on every photo creates visual noise that suggests something is broken with each photo individually.

3. **Keep the per-photo badge only when:** the user IS signed in, sync IS generally working, but a specific photo failed to upload. In that case, the red badge on that specific photo is meaningful.

### D. iCloud Sync Unavailable — SwiftDataError 1

**Symptom:** Settings shows "Sync unavailable" with error "The operation couldn't be completed. (SwiftData.SwiftDataError error 1.)"

**Root cause:** `SwiftDataError` error code 1 typically indicates a schema mismatch between the local SwiftData schema and the CloudKit schema. This happens when new model types or properties are added to the SwiftData schema (e.g., `StairwayTag`, `TagAssignment`, `StairwayDeletion` were added) but the corresponding record types and fields haven't been created in the CloudKit Dashboard.

**Fix:**

1. **Deploy the updated schema to CloudKit Dashboard.** In Xcode:
   - Open the CloudKit Dashboard (or use Xcode's CloudKit schema tools)
   - For the container `iCloud.com.o4dvasq.sfstairways`, verify that record types exist for ALL SwiftData models: `WalkRecord`, `WalkPhoto`, `StairwayOverride`, `StairwayTag`, `TagAssignment`, `StairwayDeletion`
   - Each model's stored properties must have corresponding fields in the CloudKit record type
   - Deploy the schema to Production (if previously only in Development)

2. **Alternative: use `ModelConfiguration` with `allowsSave: true` and schema migration.**  SwiftData should auto-create CloudKit record types on first sync if the schema is initialized correctly. If it's failing, the schema definition passed to `ModelContainer` may not match what CloudKit expects. Verify the `Schema` initializer in `SFStairwaysApp.init()` includes all 6 model types.

3. **Improve the error display.** The current error message is unhelpful. Map known SwiftData error codes to human-readable messages:
   - SwiftDataError code 1: "CloudKit schema needs updating — open Xcode and deploy the schema to CloudKit Dashboard"
   - Include a note in the Settings UI that this requires a rebuild from Xcode

4. **Consider: initialize CloudKit in Development mode first.** If deploying to a physical device from Xcode, CloudKit should auto-create schema in Development. Once verified, deploy to Production. The error may be because the app is hitting a Production CloudKit environment that doesn't have the latest schema.

## 4. Data Model / Schema Changes

None. The SwiftData models are correct; the CloudKit schema needs to catch up.

## 5. Acceptance Criteria

- [ ] After an active walk, HealthKit step count and elevation are populated on the WalkRecord (test on physical device with Health permissions granted)
- [ ] If HealthKit data cannot be captured, a specific error message is shown (not generic)
- [ ] Console logs show HealthKit authorization status, query time window, and results
- [ ] No duplicate "Mark as Walked" / "Mark Walked" buttons in the unwalked state
- [ ] "Not Walked" button is removed; unmarking is done by tapping the walked banner with a confirmation dialog
- [ ] Local photos do not show cloud badges when user is not signed into Supabase
- [ ] iCloud sync works after CloudKit schema is deployed (verify on physical device)
- [ ] iCloud sync error message is human-readable
- [ ] Feedback loop prompt has been run

## 6. Files Likely Touched

- `ios/SFStairways/Services/HealthKitService.swift` — error capture, retry logic, return type change
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — remove duplicate mark button, replace Not Walked with confirmation dialog, update HealthKit error display
- `ios/SFStairways/Views/Detail/PhotoCarousel.swift` — conditional cloud badge display
- `ios/SFStairways/SFStairwaysApp.swift` — verify schema includes all model types
- `ios/SFStairways/Views/Settings/SettingsView.swift` — improved error message mapping
- CloudKit Dashboard — deploy updated schema (manual step, not code)
