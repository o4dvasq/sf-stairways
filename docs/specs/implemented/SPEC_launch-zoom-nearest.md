SPEC: Launch Zoom to Nearest Stairway | Project: sf-stairways | Date: 2026-03-28 | Status: Ready for implementation

## 1. Objective

When the app launches and the splash screen dismisses, automatically zoom the map to the user's current location at a neighborhood-level zoom, centered on the nearest stairway. Currently the map starts at a fixed city-wide region (latDelta 0.06) regardless of where the user is.

## 2. Scope

Launch behavior and initial map camera position only. No changes to splash screen timing, data loading, or Around Me feature.

## 3. Business Rules

- On launch, if location permission is granted and a location fix is available, zoom to the nearest stairway within a reasonable radius.
- "Nearest stairway" means the stairway from `StairwayStore.stairways` with the shortest distance from the user's current `CLLocation`. Use the existing `Stairway.distance(from:)` method.
- The zoom level should be tight enough to see the immediate neighborhood (suggested latDelta ~0.008 to 0.012) but not so tight that you only see one pin.
- Center on the nearest stairway's coordinate (not the user's location), so the stairway is visible and tappable immediately.
- If location is unavailable (permission denied, no fix yet), fall back to the current default city-wide view. Do not block the UI waiting for location.
- Do not auto-select (open the bottom sheet for) the nearest stairway. Just zoom to it.
- The zoom should animate in after the splash dismisses, providing a smooth "landing" feeling.

## 4. Data Model / Schema Changes

None.

## 5. UI / Interface

### Current Flow

1. `SFStairwaysApp` shows `SplashView` overlay for 2.5 seconds.
2. `ContentView` (with `MapTab`) appears underneath. `MapTab.cameraPosition` is initialized to a static region: center (37.76, -122.44), span (0.06, 0.06).
3. `MapTab.onAppear` calls `locationManager.requestPermission()`.
4. Splash fades out. User sees city-wide map.

### New Flow

1. Same splash behavior (no change).
2. `MapTab` still initializes with the city-wide default (so the map has something to show immediately).
3. After `locationManager` delivers a location fix, `MapTab` computes the nearest stairway and updates `cameraPosition` with animation.
4. Timing: this should happen once, on first launch. Use a `@State private var hasZoomedToNearest = false` guard so subsequent tab switches or re-appearances don't re-trigger the zoom.

### Implementation

In `MapTab.swift`:

1. Add `@State private var hasZoomedToNearest = false`.
2. Add an `.onChange(of: locationManager.currentLocation)` modifier (or `.onReceive` if `LocationManager` publishes location).
3. When `currentLocation` transitions from `nil` to a valid location AND `hasZoomedToNearest == false`:
   - Find the nearest stairway: `store.stairways.filter(\.hasValidCoordinate).min(by: { $0.distance(from: location) < $1.distance(from: location) })`
   - If found, animate camera to a region centered on that stairway's coordinate with span ~(0.01, 0.01).
   - Set `hasZoomedToNearest = true`.
4. If `showSplash` is still true when the location arrives, defer the zoom until after splash dismisses. One way: check a binding or use a slight delay (~0.5s after splash fade completes at 2.9s total).

### LocationManager Consideration

`LocationManager` currently uses `@Observable` (or `@State`). Verify that `currentLocation` is published/observable so `.onChange` fires in `MapTab`. If `LocationManager` is a `CLLocationManagerDelegate` that sets `currentLocation` on the main actor, this should work. If not, may need to add a `@Published` wrapper or use Combine.

### Edge Case: User Not in SF

If the user opens the app outside San Francisco, the "nearest" stairway could be hundreds of miles away. The zoom would land on a random SF stairway, which is actually fine since all stairways are in SF and the user likely wants to see the SF map. No special handling needed.

## 6. Integration Points

- `MapTab.swift` — primary change (zoom logic).
- `LocationManager.swift` — verify `currentLocation` is observable; may need minor adjustment.
- `SFStairwaysApp.swift` — no changes needed (splash timing stays the same).

## 7. Constraints

- Must not block the main thread or delay app usability. If location takes 5+ seconds, the user should be able to interact with the city-wide map in the meantime.
- Must not interfere with the Around Me feature (which also zooms to user location when activated).
- Must not re-trigger on tab switches or when returning from background.
- iOS 17+ (already the floor).

## 8. Acceptance Criteria

- [ ] Launch app with location permission granted. After splash fades, map animates to a neighborhood-level zoom centered on the nearest stairway.
- [ ] The nearest stairway's pin is visible on screen after the zoom completes.
- [ ] Switching to List tab and back to Map tab does not re-trigger the zoom.
- [ ] Launch app with location permission denied. Map shows the default city-wide view (no crash, no hang).
- [ ] If location arrives before splash finishes, the zoom waits for splash to dismiss before animating.
- [ ] Feedback loop prompt has been run.

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/MapTab.swift`
- `ios/SFStairways/Services/LocationManager.swift` (possibly, to verify observability)
