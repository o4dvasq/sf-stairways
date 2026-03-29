SPEC: Map UI Fixes + Bottom Sheet Cleanup | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

## 1. Objective

Fix several map UI issues: label swap between the floating card and the tab bar, reposition the search button, remove auto-zoom on launch, and clean up the bottom sheet to hide internal metadata from end users.

## 2. Scope

**A. Swap "Stats" / "Progress" labels**
- The floating ProgressCard on the map (MapTab ~line 378) currently says "Progress". Change it to "Stats".
- The tab bar label in ContentView (line 25) currently says "Stats". Change it to "Progress".
- The ProgressTab navigation title (line 101) currently says "Stats". Change it to "Progress".
- Rationale: the floating card shows quick stats (counts, heights). The tab is the full progress view (completion ring, neighborhood breakdown, recent walks).

**B. Reposition search button**
- The search magnifying glass is currently in a VStack above the ProgressCard in the bottomTrailing overlay (MapTab lines 68-88). It's not visible or easily discoverable there.
- Move it to the bottom of the screen, at the same vertical height as the tab bar, as its own standalone circle to the right of the tab bar. Same 32x32 size, same white-on-translucent styling as the top bar buttons.
- This means removing it from the bottomTrailing overlay and placing it as a floating circle that sits at tab-bar level on the trailing edge.

**C. Remove zoom-to-nearest on launch**
- Currently: when the user's location is first obtained, the map auto-zooms to the nearest stairway (MapTab `zoomToNearest` triggered by `.onChange` of location).
- New behavior: the map stays at the default city-wide view (latitudeDelta: 0.06, centered on SF). User navigates manually.
- Remove: `hasZoomedToNearest` state var, the `.onChange(of: locationManager.currentLocation)` handler, `launchTime` state var and splash timing logic, and the `zoomToNearest(from:)` function.
- Keep: `flyToUserLocation` and `flyTo(stairway)` (explicit user actions).

**D. Bottom sheet: hide metadata, keep elevation gained**
- The statsRow in StairwayBottomSheet currently shows: step count, height, elevation gained, "HealthKit data not found", and photo count.
- Hide from end users:
  - "HealthKit data not found" text (line ~303)
  - Photo count ("2 photos" / "3 photos") (line ~310)
- Keep visible:
  - Stairway height (from scraped/verified data)
  - Elevation gained (from HealthKit, when available) — this is useful UX data
  - Verified step count (from curator overrides)
- The walkStatusCard currently shows walk method text: "Logged manually", "Active Walk (no HealthKit data)", "Fetching HealthKit stats...", and the retroactive HealthKit pull button. Hide all of this from end users. The card should show: "Walked" + date + edit pencil. Nothing else.
- These hidden data points will be accessible through the upcoming admin/management dashboard instead.

## 3. Business Rules

No data changes. UI display only.

## 4. Data Model / Schema Changes

None.

## 5. UI / Interface

**Floating card on map:** Header says "Stats" (was "Progress"). Shows stairway count, feet, steps.

**Tab bar:** Third tab labeled "Progress" with chart icon (was "Stats").

**Progress tab navigation title:** "Progress" (was "Stats").

**Search button:** Standalone 32x32 circle with magnifying glass, floating at tab-bar height on the trailing edge. Visually separate from the tab bar but at the same vertical level.

**Bottom sheet statsRow for a walked stairway:**
- Shows: verified step count (if available), stairway height, elevation gained (if available)
- Does NOT show: "HealthKit data not found", photo count

**Bottom sheet walkStatusCard for a walked stairway:**
- Shows: green checkmark, "Walked", date, edit pencil
- Does NOT show: "Logged manually", "Active Walk (no HealthKit data)", "Fetching HealthKit stats...", retroactive pull button

## 6. Integration Points

None.

## 7. Constraints

- Do not remove `flyToUserLocation` or `flyTo(stairway)` functions.
- Do not remove the HealthKit data fetching logic itself — just hide the status text from the UI. The data still gets stored on WalkRecord.
- Elevation gained should remain visible when available.

## 8. Acceptance Criteria

- Floating card on map says "Stats"
- Tab bar third tab says "Progress"
- Progress tab navigation title says "Progress"
- Search button appears as a floating circle at tab-bar height on the right edge
- App launches at city-wide zoom, does not auto-zoom to nearest stairway
- Bottom sheet for a walked stairway shows height + elevation gained, no HealthKit status text, no photo count, no walk method text
- Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/MapTab.swift` — ProgressCard title, search button repositioning, remove zoom-to-nearest
- `ios/SFStairways/Views/ContentView.swift` — tab bar label change
- `ios/SFStairways/Views/Progress/ProgressTab.swift` — navigation title change
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — statsRow cleanup, walkStatusCard cleanup
