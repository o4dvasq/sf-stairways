SPEC: Map Launch Behavior + ProgressCard Label + HealthKit Check | Project: sf-stairways | Date: 2026-03-28 | Status: Ready for implementation

## 1. Objective

Three small fixes: (A) stop auto-zooming to nearest stairway on app launch, (B) rename the floating ProgressCard header from "Progress" to avoid label collision with the Stats tab, and (C) investigate the HealthKit "Not Authorized" display in Settings.

## 2. Scope

**A. Remove zoom-to-nearest on launch**
- Currently: when the user's location is first obtained, the map auto-zooms to the nearest stairway (MapTab lines 156-162, `zoomToNearest` function at line 284).
- New behavior: the map stays at the default city-wide view (`latitudeDelta: 0.06`, centered on SF). The user can manually zoom or use the location button.
- Remove `hasZoomedToNearest` state variable, the `.onChange(of: locationManager.currentLocation)` handler that calls `zoomToNearest`, the `launchTime` state variable and splash timing logic, and the `zoomToNearest(from:)` function itself.
- Keep `flyToUserLocation` and `flyTo(stairway)` — those are triggered by explicit user actions.

**B. Rename ProgressCard header**
- The floating card on the map (MapTab line 378) says `Text("Progress")`, which sits directly above the tab bar where the "Stats" tab label lives. Two instances of similar words stacked vertically is redundant.
- Remove the "Progress" title text from the card entirely. Let the numbers (stairway count, feet, steps) speak for themselves. The card already has a distinctive amber header bar, so removing the label keeps it clean.

**C. HealthKit authorization display**
- Settings currently shows "HealthKit: Not Authorized" with a "Request Permission" button. The `isAuthorized()` check uses `statusForAuthorizationRequest` which returns `.unnecessary` only after the system prompt has fired.
- Verify that tapping "Request Permission" actually triggers the iOS HealthKit permission dialog and that the status updates afterward.
- If the issue is that the entitlements file is missing the HealthKit capability, add it. Check the Xcode project for the HealthKit capability under Signing & Capabilities.
- Note: HealthKit entitlement (`com.apple.developer.healthkit`) must be present in the entitlements file AND enabled in the Xcode project target capabilities. The current entitlements file only has CloudKit/iCloud entries.

## 3. Business Rules

- No data changes. These are all UI/UX fixes.

## 4. Data Model / Schema Changes

None.

## 5. UI / Interface

**Map on launch:** Shows full SF city view (37.76, -122.44, span 0.06). User's blue dot appears when location is available but map does not auto-navigate.

**ProgressCard:** No title text. Just the amber header bar (now acting as a thin color accent) followed by the three stat lines.

**Settings HealthKit row:** Should transition from "Not Authorized" to "Authorized" after the user grants permission. If the HealthKit entitlement is missing, fix it so the system prompt can appear.

## 6. Integration Points

- HealthKit entitlement may need to be added to SFStairways.entitlements

## 7. Constraints

- Do not remove the `flyToUserLocation` or `flyTo(stairway)` functions — those serve explicit user navigation.

## 8. Acceptance Criteria

- App launches showing the full SF city map, does not auto-zoom to nearest stairway
- ProgressCard on map shows stats without a "Progress" title label
- Tapping "Request Permission" for HealthKit in Settings triggers the iOS permission dialog
- After granting HealthKit permission, Settings row updates to "Authorized"
- Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/MapTab.swift` — remove zoom-to-nearest logic, remove ProgressCard title text
- `ios/SFStairways.entitlements` — add HealthKit entitlement if missing
- `ios/SFStairways/SFStairways.xcodeproj/project.pbxproj` — HealthKit capability (if not already present)
