# SPEC: UI Improvements v2

## 1. Overview

A set of focused UI polish changes across the iOS app: slimmer nav bar with stair icon, cleaner map pins, fixed Progress card width, and a reworked StairwayDetail screen with a focused mini-map and Save action.

## 2. Goals

- Reduce visual clutter and polish key screens
- Make pins less busy and easier to read on the map
- Fix a layout bug in the ProgressCard orange title bar
- Make StairwayDetail more useful by showing location context immediately

## 3. Out of Scope

- Web app changes
- Any data model changes
- Photo workflow changes

## 4. Acceptance Criteria

1. **Nav bar** — orange top bar is shallower (less vertical padding). A white stair icon (`StairShape`) is centered in the bar. "SF Stairways" text is removed.
2. **Pins** — `StairShape` icon removed from inside pins. Pins are smaller across all three states.
3. **ProgressCard title bar** — the orange "Progress" header is only as wide as the grey content box (120pt), not full screen width.
4. **StairwayDetail top** — photo carousel replaced with a focused, non-interactive map showing the stairway location (or a placeholder if coordinates unavailable).
5. **StairwayDetail save** — a "Save" toolbar button appears when the stairway has no walk record. Tapping it creates a `WalkRecord(walked: false)`.

## 5. Implementation Plan

### File: `ios/SFStairways/Views/Map/MapTab.swift`

**topBar**:
- Reduce `.padding(.vertical, 10)` → `.padding(.vertical, 6)`
- Remove `Text("SF Stairways")` and its TODO comment
- Add `StairShape().fill(.white).frame(width: 26, height: 26)` centered using ZStack layout

**ProgressCard**:
- Remove `Spacer()` from the header `HStack` so the orange title row doesn't expand beyond the card width

### File: `ios/SFStairways/Views/Map/TeardropPin.swift`

**StairwayPin**:
- Remove the `StairShape` icon block (the icon centered in the bulb area)
- Reduce pin dimensions (~20% smaller):
  - unsaved: 38×48 → 30×38
  - saved/walked: 44×55 → 36×45
  - selected: 52×65 → 42×53
- Remove `iconSize` computed property (no longer needed)

### File: `ios/SFStairways/Views/Detail/StairwayDetail.swift`

**Top section**:
- Add `import MapKit`
- Replace `photoCarousel` call with `detailMap`
- Add `detailMap` computed var: non-interactive `Map` at 200pt height, zoomed to stairway location, with an orange `Marker`; falls back to grey placeholder if no coordinates

**Save button**:
- Add second `ToolbarItem` for Save: shown only when `walkRecord == nil` and stairway is not closed
- Tapping inserts `WalkRecord(stairwayID: stairway.id, walked: false)` and saves

## 6. No-spec flag

N/A

## 7. Dependencies

None — all changes are self-contained within existing files.

## 8. Risks

- `Map(initialPosition:)` requires iOS 17+ — already the minimum deployment target
- Removing the stair icon from pins may make all three pin states look less distinct; mitigated by the existing color differentiation (amber / light green / green)

## 9. Test Notes

No automated tests. Verify visually in Xcode simulator or device.
