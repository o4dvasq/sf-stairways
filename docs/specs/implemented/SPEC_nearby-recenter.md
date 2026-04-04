SPEC: Nearby Filter Recenters Map | Project: sf-stairways | Date: 2026-04-03 | Status: Ready for implementation

## 1. Objective

When the user taps the "Nearby" filter pill on the map, recenter the map on their current location in addition to filtering for nearby stairways. Currently, Nearby only filters the pin set but doesn't move the camera, so users may be looking at a different part of the city.

## 2. Scope

MapTab.swift only.

## 3. Business Rules

- Tapping "Nearby" should move the map camera to the user's current location at a zoom level that shows the 1500m radius of nearby stairways
- If location is unavailable, keep current behavior (show all, or show a toast)

## 4. Data Model / Schema Changes

None.

## 5. UI / Interface

When `filter` changes to `.nearby`:
1. Get `locationManager.currentLocation`
2. Animate the camera to center on that location with a span of ~0.025 (roughly covers the 1500m filter radius)
3. The stairway filter already handles showing only nearby pins

Implementation: add an `.onChange(of: filter)` modifier (or extend the existing Picker action) that triggers a camera move when switching to `.nearby`:

```swift
.onChange(of: filter) { _, newValue in
    if newValue == .nearby, let location = locationManager.currentLocation {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        )
        withAnimation { cameraPosition = .region(region) }
    }
}
```

## 6. Integration Points

None.

## 7. Constraints

iOS 17+. Requires location permission already granted.

## 8. Acceptance Criteria

- [ ] Tapping "Nearby" recenters map on user's current location
- [ ] Zoom level is appropriate to see nearby stairways (~1500m radius)
- [ ] Animation is smooth (not a jump cut)
- [ ] Switching back to "All" or "Walked" does NOT move the camera (user stays where they are)
- [ ] If location unavailable, no crash, no camera move

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/MapTab.swift` — add `.onChange(of: filter)` or extend filter picker action
