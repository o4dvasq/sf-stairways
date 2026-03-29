SPEC: macOS Admin Dashboard | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

## 1. Objective

Build a macOS companion app for data management, curation, and review. The iOS app stays clean and user-facing. All metadata, data hygiene, note promotion, and per-stairway review happens on Mac via shared CloudKit data.

## 2. Scope

**Platform decision: macOS (SwiftUI + SwiftData + CloudKit)**

The macOS app shares the same CloudKit container (`iCloud.com.o4dvasq.sfstairways`) as the iOS app. SwiftData models are identical. All walk records, overrides, tags, tag assignments, and photos sync automatically via CloudKit with zero additional sync work.

**Architecture: new macOS target in the existing Xcode project**

Add a macOS target to `SFStairways.xcodeproj`. Share the Models/ directory and StairwayStore between iOS and macOS. The macOS app gets its own Views/ and its own entry point.

## 3. MVP Features

### A. Stairway Browser (main view)

Three-column layout (NavigationSplitView):

**Sidebar (left):**
- Neighborhood list with walked/total counts
- "All Stairways" option at top
- Filter controls: All / Walked / Unwalked
- Search field

**Stairway List (middle):**
- Table rows for stairways in selected neighborhood/filter
- Columns: Name, Walked (checkmark), Height, Steps, Elevation Gained, Photos, Date Walked
- Sortable by any column
- Color coding: green row for walked, default for unwalked

**Detail Panel (right):**
Side-by-side data for the selected stairway:

| Catalog Data | Walk Data |
|---|---|
| Name | Walk status |
| Neighborhood | Date walked |
| Height (ft) | Elevation gained (HealthKit) |
| Step count (scraped) | Step count (HealthKit) |
| Coordinates | Walk method |
| Source URL | Proximity verified |
| Closed status | Hard mode |

Below the comparison table:
- **Curator Overrides section:** Editable fields for verified step count, verified height, curator description. Save button writes to StairwayOverride.
- **Notes section:** Personal notes (from WalkRecord.notes) displayed alongside curator description (from StairwayOverride.stairwayDescription). "Promote to Commentary" button copies notes to curator description.
- **Tags section:** Current tag assignments with add/remove.
- **Photos section:** Grid of local + Supabase photos with upload status indicators. Ability to delete local photos.

### B. Data Hygiene Dashboard

A separate tab or view showing:
- Stairways missing height data
- Stairways missing coordinates (can't be mapped)
- Walked stairways missing HealthKit data (candidates for retroactive pull)
- Local photos that failed Supabase upload
- Stairways with notes but no curator description (promotion candidates)
- Walk records with `proximityVerified == false`

### C. Bulk Operations

- Select multiple stairways in the list → bulk tag assignment
- Select multiple stairways → bulk mark as walked (with date picker)
- Export filtered stairway data as CSV

## 4. Business Rules

- All edits to WalkRecord, StairwayOverride, StairwayTag, and TagAssignment sync back to iOS via CloudKit automatically.
- The macOS app is read/write. Changes made on Mac appear on iPhone after CloudKit sync.
- No Supabase integration in the macOS app for MVP. Photos from Supabase won't be visible on Mac initially (only local/CloudKit photos). This can be added later.

## 5. Data Model / Schema Changes

None. The macOS app uses the exact same SwiftData models as iOS:
- `WalkRecord`
- `WalkPhoto`
- `StairwayOverride`
- `StairwayTag`
- `TagAssignment`

The `Stairway` value type loads from the same bundled `all_stairways.json`.
`StairwayStore` provides the same resolver helpers.

## 6. UI / Interface

**Window:** Standard macOS window, resizable, minimum size ~1000x600.

**Navigation:** NavigationSplitView with three columns. Sidebar shows neighborhoods. Middle column shows stairway table. Detail column shows the full data panel.

**Toolbar:** Filter toggles (All/Walked/Unwalked), search, data hygiene button (opens hygiene dashboard as sheet or tab).

**Color scheme:** Match iOS dark theme where possible. ForestGreen for walked indicators, brandAmber for unwalked/alerts.

## 7. Integration Points

- CloudKit container: `iCloud.com.o4dvasq.sfstairways` (same as iOS)
- Bundled resource: `all_stairways.json` (copy into macOS target)
- Bundled resource: `neighborhood_centroids.json`, `neighborhood_adjacency.json` (for neighborhood grouping)
- Shared code: Models/, StairwayStore, AppColors

## 8. Project Setup Steps

1. In Xcode: File > New > Target > macOS App (SwiftUI lifecycle)
2. Name: "SFStairways Mac" (or similar), bundle ID: `com.o4dvasq.SFStairways.mac`
3. Add to same CloudKit container: `iCloud.com.o4dvasq.sfstairways`
4. Add shared files to macOS target membership: all Models/*.swift, StairwayStore.swift, AppColors.swift
5. Add bundled JSON resources to macOS target
6. Create macOS-specific Views/ directory
7. Create macOS entry point (SFStairwaysMacApp.swift) with same ModelContainer setup as iOS

## 9. Constraints

- Keep iOS and macOS model files in sync. Any model change must compile for both targets.
- No HealthKit on macOS (HealthKit is iOS-only). The macOS app can display HealthKit data that was synced via CloudKit from the iOS WalkRecord, but cannot fetch new HealthKit data.
- macOS app is personal use only (no App Store). Run from Xcode or as a Developer ID signed app.

## 10. Acceptance Criteria

- macOS app launches and displays all stairways from bundled JSON
- Walk records sync from CloudKit and display correctly (walked status, dates, notes, HealthKit data)
- Stairway detail panel shows catalog data side-by-side with walk data
- Curator overrides can be edited and saved (syncs back to iOS)
- Notes can be promoted to curator commentary
- Tags can be viewed and assigned
- Data hygiene view flags stairways with missing data
- Feedback loop prompt has been run

## 11. Files Likely Touched

- `ios/SFStairways.xcodeproj/project.pbxproj` — add macOS target, shared file memberships
- New: `ios/SFStairways Mac/` directory (or `ios/SFStairwaysMac/`)
  - `SFStairwaysMacApp.swift` — entry point
  - `Views/StairwayBrowser.swift` — main three-column view
  - `Views/StairwayDetailPanel.swift` — detail panel
  - `Views/DataHygieneView.swift` — data hygiene dashboard
  - `Views/BulkOperationsSheet.swift` — bulk actions
- Shared (add macOS target membership):
  - `ios/SFStairways/Models/*.swift`
  - `ios/SFStairways/Resources/StairwayStore.swift`
  - `ios/SFStairways/Resources/AppColors.swift`
  - `ios/SFStairways/Resources/*.json` (bundled data files)
