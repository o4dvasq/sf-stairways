SPEC: Remove HealthKit & Walk Recording | Project: sf-stairways | Date: 2026-03-30 | Status: Ready for implementation

## 1. Objective

Remove the "Active Walk" recording flow (Start Walk / End Walk) and all HealthKit integration from the app. The app is a San Francisco stairway exploration tracker, not a fitness or hike-tracking app. Walk data enrichment (elevation, step counts) will happen after the fact via the Mac admin dashboard and curator override fields, using data from Apple Watch workouts or Strava. "Mark Walked" becomes the sole action for logging a stairway visit.

This reverses SPEC_active-walk-mode.md. The WalkRecord model fields added by that spec (walkStartTime, walkEndTime, elevationGain) are retained as nullable columns so existing data is preserved and CloudKit sync is not disrupted, but no new code writes to them. The stepCount field (predates active walk mode) is also retained but no longer auto-populated.

## 2. Scope

- Remove HealthKitService.swift entirely
- Remove ActiveWalkManager.swift entirely
- Remove all "Start Walk" / "End Walk" / active session UI from the iOS app
- Remove HealthKit authorization UI from SettingsView
- Remove HealthKit entitlement from the app
- Remove HealthKit-related data hygiene checks from the Mac app
- Clean up references in all three targets (iOS, Mac, Admin)
- Preserve "Mark Walked" as the primary (and only) walk-logging action

## 3. Business Rules

- **Mark Walked** remains the sole mechanism for logging a stairway visit. Behavior unchanged from current implementation.
- **No HealthKit permission prompt.** The app no longer requests or checks HealthKit authorization.
- **Existing walk data preserved.** WalkRecords that have stepCount, elevationGain, walkStartTime, or walkEndTime populated retain those values. They just won't be displayed in the iOS app anymore. The Mac admin dashboard may still show them in the data comparison table for reference.
- **Curator overrides are the path for enrichment.** Verified step count and verified height on StairwayOverride remain the canonical way to add elevation/distance data. These are populated manually via the Mac admin dashboard.
- **Photo suggestion time window.** PhotoSuggestionService currently accepts optional walkStartTime/walkEndTime to narrow the photo search window. With active walks removed, this falls back to the full calendar day window (dateWalked). The parameters can be removed or left as unused optionals; either approach is fine.

## 4. Data Model / Schema Changes

**No schema changes.** All fields remain in place to avoid CloudKit migration issues:

- `WalkRecord.stepCount: Int?` — retained, no longer auto-populated
- `WalkRecord.elevationGain: Double?` — retained, no longer auto-populated
- `WalkRecord.walkStartTime: Date?` — retained, no longer auto-populated
- `WalkRecord.walkEndTime: Date?` — retained, no longer auto-populated

The `walkMethod` computed property on WalkRecord can be removed or simplified. It currently distinguishes "Active Walk" from "Active Walk (no HealthKit data)" which is no longer meaningful.

## 5. UI / Interface

### iOS App (SFStairways)

**StairwayBottomSheet:**
- Remove "Start Walk" button from the unwalked action buttons. "Mark Walked" becomes the only button.
- Remove the active session banner (elapsed timer, "End Walk" button, "Cancel" button)
- Remove steps and elevation display from the stats row (lines showing HealthKit step count and elevation gain for active walks)
- Remove `startWalk()`, `endWalkSession()`, `finalizeActiveWalk()` functions
- Remove the `@Environment(ActiveWalkManager.self)` dependency

**SettingsView:**
- Remove the entire HealthKit authorization section (the row showing authorization status and "Request Permission" button)
- Remove `import HealthKit`
- Remove `healthKitAuthorized` state variable and its `.task` initializer

### Mac App (SFStairwaysMac)

**DataHygieneView:**
- Remove the `missingHealthKit` issue category ("Missing HealthKit Data"). This check is no longer relevant.

**StairwayDetailPanel:**
- In the data comparison table, the "walk" column for elevation and steps can either be removed or relabeled. If kept, label as "Walk Data (legacy)" or similar. These fields may still have data from past active walks.

**StairwayBrowser:**
- Remove or hide the elevationGain sort option and table column. The HealthKit-sourced elevation data is sparse and no longer growing.
- Remove comments referencing HealthKit

**BulkOperationsSheet:**
- Remove "Elevation Gain (ft)" and "Steps" from CSV export, or keep as optional legacy columns.

### Admin App (SFStairwaysAdmin)

**AdminDetailView:**
- Remove the Walk Data section that displays stepCount and elevationGain.

## 6. Integration Points

- **HealthKit framework:** Remove entirely. No more `import HealthKit` anywhere.
- **Entitlements:** Remove `com.apple.developer.healthkit` from both entitlement files (`ios/SFStairways.entitlements` and `ios/SFStairways/SFStairways.entitlements`).
- **PhotoSuggestionService:** Remove walkStartTime/walkEndTime parameters. The service falls back to its dateWalked-based window.
- **SeedDataService:** Remove `cleanRetroactiveStatsIfNeeded()` migration function. It was a one-time cleanup that has already run.
- **SFStairwaysApp.swift:** Remove ActiveWalkManager instantiation and environment injection.

## 7. Constraints

- Do not delete or modify WalkRecord schema fields. Removing SwiftData properties that exist in CloudKit causes migration failures.
- Ensure the "Mark Walked" flow (including Hard Mode proximity check, dateWalked stamping, and confirmation toast) is completely untouched.
- The Xcode project file (project.pbxproj) must be updated to remove file references for deleted files (HealthKitService.swift, ActiveWalkManager.swift).

## 8. Acceptance Criteria

- [ ] App builds and runs without HealthKit framework linked
- [ ] No HealthKit permission prompt appears on fresh install
- [ ] "Start Walk" button does not appear anywhere in the iOS app
- [ ] "Mark Walked" button works correctly for unwalked stairways
- [ ] Previously walked stairways with HealthKit data still display correctly (walked status preserved)
- [ ] Mac admin dashboard builds without errors
- [ ] Admin app builds without errors
- [ ] Data Hygiene view no longer shows "Missing HealthKit Data" category
- [ ] No references to HealthKitService or ActiveWalkManager remain in compiled code
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

**Delete:**
- `ios/SFStairways/Services/HealthKitService.swift`
- `ios/SFStairways/Services/ActiveWalkManager.swift`

**Modify (iOS):**
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — remove walk session UI, Start Walk button, HealthKit display
- `ios/SFStairways/Views/Settings/SettingsView.swift` — remove HealthKit section
- `ios/SFStairways/SFStairwaysApp.swift` — remove ActiveWalkManager
- `ios/SFStairways/Models/WalkRecord.swift` — remove walkMethod computed property
- `ios/SFStairways/Services/PhotoSuggestionService.swift` — remove walkStartTime/walkEndTime params
- `ios/SFStairways/Services/SeedDataService.swift` — remove cleanRetroactiveStatsIfNeeded()
- `ios/SFStairways.entitlements` — remove HealthKit entitlement
- `ios/SFStairways/SFStairways.entitlements` — remove HealthKit entitlement

**Modify (Mac):**
- `ios/SFStairwaysMac/Views/DataHygieneView.swift` — remove missingHealthKit category
- `ios/SFStairwaysMac/Views/StairwayDetailPanel.swift` — remove or relabel HealthKit fields
- `ios/SFStairwaysMac/Views/StairwayBrowser.swift` — remove elevationGain column/sort
- `ios/SFStairwaysMac/Views/BulkOperationsSheet.swift` — remove HealthKit fields from CSV export

**Modify (Admin):**
- `ios/SFStairwaysAdmin/Views/AdminDetailView.swift` — remove Walk Data section

**Modify (Project):**
- `ios/SFStairways.xcodeproj/project.pbxproj` — remove file references for deleted files
