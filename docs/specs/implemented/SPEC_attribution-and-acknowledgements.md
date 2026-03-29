SPEC: Attribution Links & Acknowledgements | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

---

## 1. Objective

Add proper attribution to the two data sources that power the stairway database: sfstairways.com (based on the work of Mary Burk and Adah Bakalinsky) and Urban Hiker SF (Alexandra Kenin). Add source links on both iOS and macOS detail screens, and a new Acknowledgements section in iOS Settings.

## 2. Scope

Three changes:

**A. Detail screen links** — Show relevant data source links on both the iOS bottom sheet and the macOS detail panel, based on which source(s) contributed data for that stairway.

**B. iOS Settings Acknowledgements section** — New section in SettingsView with attribution blurbs, website links, and a "Buy a Matcha" link for Urban Hiker SF.

**C. macOS About/Acknowledgements** — Equivalent acknowledgements accessible from the macOS app (menu bar or toolbar).

## 3. Business Rules

### Data Source Links on Detail Screens

- If a stairway has `source_url` (sfstairways.com): show "View on SF Stairways" link (already exists on iOS, already in macOS data table).
- If a stairway has `geocode_source == "urban_hiker"`: show "View on Urban Hiker SF Map" link pointing to the Google Maps custom map with the stairway's coordinates as the center: `https://www.google.com/maps/d/viewer?mid=1F4TY3dl4yiG6VBqigpnrFvhsbK_FYcsW&ll={lat},{lng}&z=18`
- If a stairway has both sources, show both links.
- The Urban Hiker map link uses the stairway's lat/lng to center the map at zoom level 18 so the user lands on the right marker.

### Acknowledgements Content

**SF Stairways (sfstairways.com)**
- Credit: "Stairway data originally compiled from the index in Stairway Walks in San Francisco by Adah Bakalinsky, maintained at sfstairways.com"
- Link: https://www.sfstairways.com

**Urban Hiker SF**
- Credit: "Additional stairway locations from the San Francisco Public Stairway Map by Alexandra Kenin / Urban Hiker SF"
- Links:
  - Website: https://www.urbanhikersf.com
  - Stairway Map: https://www.google.com/maps/d/viewer?mid=1F4TY3dl4yiG6VBqigpnrFvhsbK_FYcsW
  - Spreadsheet: https://bit.ly/sfstairsheet
  - Buy a Matcha: https://buymeacoffee.com/urbanhikersf (with note: "Support Alexandra's incredible work cataloging SF's stairways")

**Book**
- Credit: "Stairway Walks in San Francisco by Adah Bakalinsky — the original field guide that started it all"

## 4. Data Model / Schema Changes

None. The `geocode_source` field already exists on the Stairway struct (as `geocodeSource`). After the Urban Hiker import runs, new stairways will have `geocode_source: "urban_hiker"`, which is sufficient to determine which link to show.

## 5. UI / Interface

### A. iOS Detail Screen (StairwayBottomSheet)

Current state: has a "View on sfstairways.com" Link when `stairway.sourceURL` exists (lines 138-152).

Add below the existing sfstairways link:
- If `stairway.geocodeSource == "urban_hiker"` OR stairway has no sourceURL (i.e., it came from UH): show a "View on Urban Hiker SF Map" Link styled the same way (safari icon, forestGreen, arrow.up.right), pointing to the Google Maps URL with lat/lng.
- Use the same visual pattern as the existing sfstairways link for consistency.

### B. macOS Detail Panel (StairwayDetailPanel)

Current state: shows source URL in the data comparison grid.

Add a new row to the data comparison grid:
- If `stairway.geocodeSource == "urban_hiker"`: add a "UH Map" row with a Link to the Google Maps URL with lat/lng, same style as the existing Source row.

### C. iOS Settings — Acknowledgements Section

Add a new section to SettingsView, below the existing "Build" section:

```
Section: "Acknowledgements"

  "Data Sources"  (header text, .caption.bold, .secondary)

  Row: SF Stairways logo/icon area
    "Stairway data originally compiled from the index in
     Stairway Walks in San Francisco by Adah Bakalinsky,
     maintained at sfstairways.com"
    Link -> https://www.sfstairways.com

  Row: Urban Hiker SF
    "Additional stairway locations from the San Francisco
     Public Stairway Map by Alexandra Kenin / Urban Hiker SF"
    Link -> https://www.urbanhikersf.com
    Link -> "View the Stairway Map" (Google Maps link)

  Row: Buy a Matcha
    HStack with cup icon (cup.and.saucer.fill)
    "Support Alexandra's incredible work cataloging SF's stairways"
    Link -> https://buymeacoffee.com/urbanhikersf
    Use brandAmber color for the icon/accent to make it warm and inviting

  Row: The Book
    HStack with book icon (book.fill)
    "Stairway Walks in San Francisco by Adah Bakalinsky —
     the original field guide that started it all"
```

Visual style: follow the existing SettingsView patterns (List with Sections, Label rows, .font(.subheadline) for body text, Link with arrow.up.right for external URLs).

### D. macOS Acknowledgements

Add acknowledgements accessible from the macOS app. Two options (implementer's choice):
- Option A: Add an "Acknowledgements" section to the bottom of the sidebar in StairwayBrowser
- Option B: Add a Help > Acknowledgements menu item or a toolbar info button that opens a sheet

Content is the same as the iOS Settings section.

## 6. Integration Points

**iOS modified files:**
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — add Urban Hiker map link
- `ios/SFStairways/Views/Settings/SettingsView.swift` — add Acknowledgements section

**macOS modified files:**
- `ios/SFStairwaysMac/Views/StairwayDetailPanel.swift` — add UH Map row to data grid
- `ios/SFStairwaysMac/Views/StairwayBrowser.swift` — add acknowledgements (sidebar or menu)

## 7. Constraints

- No new dependencies or packages.
- Links open in the system browser (default behavior for SwiftUI Link).
- The Google Maps URL format for deep-linking to a custom map with coordinates: `https://www.google.com/maps/d/viewer?mid=1F4TY3dl4yiG6VBqigpnrFvhsbK_FYcsW&ll={lat},{lng}&z=18`
- The "Buy a Matcha" link should feel warm and appreciative, not transactional.
- Follow existing SettingsView visual patterns exactly.
- The acknowledgements section should work regardless of whether the Urban Hiker import has been run yet (some stairways may not have geocodeSource set).

## 8. Acceptance Criteria

### Detail screen links
- [ ] iOS bottom sheet shows "View on Urban Hiker SF Map" link for stairways with geocodeSource == "urban_hiker"
- [ ] iOS bottom sheet still shows "View on sfstairways.com" link for stairways with sourceURL
- [ ] Stairways with both sources show both links
- [ ] macOS detail panel shows UH Map row for geocodeSource == "urban_hiker" stairways
- [ ] Google Maps link opens in browser, centered on the correct stairway coordinates

### iOS Acknowledgements
- [ ] New "Acknowledgements" section appears in SettingsView below Build section
- [ ] SF Stairways attribution with working link to sfstairways.com
- [ ] Urban Hiker SF attribution with working links to urbanhikersf.com and Google Maps
- [ ] "Buy a Matcha" row with working link to buymeacoffee.com/urbanhikersf
- [ ] Book attribution for Stairway Walks in San Francisco
- [ ] Visual style matches existing SettingsView sections

### macOS Acknowledgements
- [ ] Acknowledgements accessible from the macOS app
- [ ] Same content as iOS section
- [ ] All links functional

### General
- [ ] No regressions in existing detail screen or settings functionality
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

**Modified files:**
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift`
- `ios/SFStairways/Views/Settings/SettingsView.swift`
- `ios/SFStairwaysMac/Views/StairwayDetailPanel.swift`
- `ios/SFStairwaysMac/Views/StairwayBrowser.swift`
