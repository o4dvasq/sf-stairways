SPEC: Map Pin UX — Tap Targets & Zoom Scaling | Project: sf-stairways | Date: 2026-03-28 | Status: Ready for implementation

## 1. Objective

Improve map pin usability by (a) expanding the invisible tap target beyond the visual pin bounds so you don't have to hit a 12pt circle precisely, and (b) scaling pin size up as the user zooms in so pins are easier to see and tap at close range.

## 2. Scope

Map pin tap targets and visual sizing on MapTab only. No changes to ListTab, bottom sheet, or data layer.

## 3. Business Rules

- The visual pin appearance (colors, stroke, opacity, dimming) is unchanged.
- Tap target must be at least 44x44pt (Apple HIG minimum) regardless of visual pin size.
- Pin visual size should scale smoothly between the current static sizes (floor) and roughly 2x those sizes (ceiling) as the map zooms from city-wide to street-level.
- Selected-pin size (currently 24pt) should also scale proportionally.
- Scaling should feel natural — no popping or jarring transitions.

## 4. Data Model / Schema Changes

None.

## 5. UI / Interface

### A. Expanded Tap Targets

In `MapTab.swift`, the `Annotation` content wraps `StairwayAnnotation` with `.onTapGesture`. The hit area currently matches the `Circle()` frame in `StairwayPin`.

**Approach:** Add an invisible padding/content shape to `StairwayPin` (or at the `Annotation` call site) so the tappable area is at least 44x44pt even when the visual circle is 12pt. Options:

- Wrap the `Circle()` in a transparent frame with `.contentShape(Rectangle())` sized to `max(44, pinSize)`.
- Or add `.padding()` with `.contentShape(Circle())`.

The key constraint: this must not break MapKit's annotation layout or cause overlapping hit regions to swallow taps for neighboring pins. Test with clusters of nearby stairways (e.g., the Filbert/Greenwich area has several within a block).

### B. Zoom-Responsive Pin Sizing

`MapTab` needs to read the current camera zoom level and pass a scale factor to `StairwayPin`.

**Approach:**

1. Add an `@State private var mapSpan: Double` to `MapTab` (tracks `region.span.latitudeDelta`).
2. Use `.onMapCameraChange(frequency: .continuous)` (iOS 17+) to update `mapSpan` as the user pans/zooms.
3. Compute a `pinScale: CGFloat` from `mapSpan`. Suggested mapping:
   - `latitudeDelta >= 0.05` (city view) → scale = 1.0 (current sizes)
   - `latitudeDelta <= 0.005` (street view) → scale = 2.0
   - Linear interpolation between those thresholds
4. Pass `pinScale` into `StairwayAnnotation` → `StairwayPin`.
5. In `StairwayPin`, multiply `pinSize` by the scale factor.
6. The 44pt minimum tap target (from part A) should also scale with zoom — at street level the tap target can be larger than 44pt if the pin is larger.

**Performance note:** `.onMapCameraChange(frequency: .continuous)` fires often. The scale factor computation is trivial (one clamp + lerp), but avoid triggering expensive re-renders. Since `pinScale` is a single `CGFloat` and SwiftUI diffing handles this efficiently, this should be fine. If profiling shows issues, switch to `.onMapCameraChange(frequency: .onEnd)`.

## 6. Integration Points

- `TeardropPin.swift` — `StairwayPin` struct: add `scale: CGFloat = 1.0` parameter, apply to `pinSize`.
- `StairwayAnnotation.swift` — pass through `scale` parameter.
- `MapTab.swift` — compute `pinScale` from camera, pass to each `StairwayAnnotation`.

## 7. Constraints

- iOS 17+ (already the floor).
- Must not regress Around Me dimming, unverified badge overlay, or closed-stairway styling.
- Test on device with dense stairway clusters to verify tap accuracy.

## 8. Acceptance Criteria

- [ ] Tapping near (but not directly on) a 12pt unsaved pin reliably selects it.
- [ ] At city-wide zoom (all of SF visible), pins render at current sizes.
- [ ] At street-level zoom (1-2 blocks visible), pins are visibly larger (roughly 2x).
- [ ] Pin size transitions smoothly during pinch-zoom with no popping.
- [ ] Selected pin highlight still works and animates correctly at all zoom levels.
- [ ] Dimmed pins, closed pins, and unverified badges render correctly at all scales.
- [ ] Feedback loop prompt has been run.

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/MapTab.swift`
- `ios/SFStairways/Views/Map/TeardropPin.swift` (StairwayPin)
- `ios/SFStairways/Views/Map/StairwayAnnotation.swift`
