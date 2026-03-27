# SPEC: Hard Mode (Proximity-Verified Walks)
**Project:** sf-stairways | **Date:** 2026-03-26 | **Status:** Ready for Implementation

---

## 1. Objective

Add an optional per-stairway "Hard Mode" that requires the user to be physically present (within 150m) before marking a stairway as Walked. Stairways opted into Hard Mode have their Mark Walked button disabled unless proximity is confirmed. Pre-existing walks on Hard Mode stairways receive an "unverified" badge on their map pin.

---

## 2. Scope

**In scope:**
- Per-stairway Hard Mode opt-in stored in WalkRecord
- Proximity check (150m radius) gating the Mark Walked action on opted-in stairways
- Disabled/grayed Mark Walked button when user is out of range in Hard Mode
- Unverified badge on map pins for walks that predate Hard Mode opt-in
- Hard Mode opt-in/opt-out UI in StairwayBottomSheet and StairwayDetail
- Proximity helper function on LocationManager

**Out of scope:**
- Global Hard Mode toggle
- Background geofence notifications
- Proximity requirement for the Save action
- Retroactive removal of Walked status on existing records
- Any server-side verification

---

## 3. Business Rules

1. **Per-stairway opt-in.** Hard Mode is a boolean stored per WalkRecord. The user controls this on a stairway-by-stairway basis.

2. **Opt-in for Unsaved stairways.** A user can enable Hard Mode on a stairway that has no WalkRecord yet. In this case, a new WalkRecord is created with `walked = false`, `hardMode = true` at opt-in time. This means opting into Hard Mode implies Save. Implementation: the Hard Mode toggle's action must call the same save pathway that the "Save" button uses (creating the WalkRecord in the model context), then set `hardMode = true` on the newly created record. See Section 5b for the exact flow.

3. **Proximity radius: 150m.** "Nearby" = user's current CLLocation is within 150 meters of the stairway's coordinate. Uses the existing `LocationManager.currentLocation` property.

4. **Mark Walked is disabled (not hidden) when out of range.** On a Hard Mode stairway, the Mark Walked button renders in a grayed/disabled state (opacity 0.4, `.disabled(true)`) if the user is not within 150m. No tap action fires. No toast or alert.

5. **Mark Walked is enabled when within 150m.** Proximity is computed in real time from `LocationManager.currentLocation`. No explicit "check in" action required — the button simply becomes active when the view re-renders with an updated location.

6. **Proximity check is silent.** No nudge, toast, or notification when the user enters range. The button state changes quietly on the next view update.

7. **Save is unaffected.** The Save (bookmark) action has no proximity requirement regardless of Hard Mode status.

8. **Unverified badge for pre-existing walks.** If a user opts a stairway into Hard Mode that already has `walked = true`, the walk is NOT removed. Instead, the WalkRecord gains `hardMode = true` and `proximityVerified = false`. The map pin displays a small amber badge.

9. **New walks on Hard Mode stairways are always verified.** When `toggleWalked()` fires on a Hard Mode stairway (only possible when within 150m), `proximityVerified = true` is written. See Section 4 for the `toggleWalked()` modification.

10. **Opting out of Hard Mode.** User can toggle Hard Mode off at any time. Sets `hardMode = false` on WalkRecord. `proximityVerified` is left unchanged (historical record). The unverified badge disappears because Hard Mode is off.

11. **No location = disabled.** If location permission is denied or `currentLocation` is nil, Mark Walked behaves as if the user is out of range (disabled) on Hard Mode stairways. A static label reads "Location required for Hard Mode."

12. **Closed stairways.** Closed stairways remain non-interactable regardless of Hard Mode. The Hard Mode toggle should be hidden (not just disabled) on closed stairways, since the user can't interact with them anyway.

---

## 4. Data Model / Schema Changes

### WalkRecord.swift — two new fields

Add to the existing `@Model` class:

```swift
var hardMode: Bool = false
var proximityVerified: Bool? = nil
// nil = Hard Mode was never enabled for this record (legacy / non-Hard Mode walk)
// false = Hard Mode enabled, walk predates opt-in (unverified)
// true = walk occurred while within 150m with Hard Mode active
```

**Migration:** SwiftData handles additive migrations automatically. Existing WalkRecords get `hardMode = false`, `proximityVerified = nil`. No manual migration needed.

**CloudKit:** Both fields sync automatically via existing CloudKit container.

### WalkRecord.swift — modify `toggleWalked()`

The existing `toggleWalked()` method currently flips `walked`, sets `dateWalked`, and updates `updatedAt`. Add proximity verification logic:

```swift
func toggleWalked() {
    walked.toggle()
    if walked {
        dateWalked = dateWalked ?? Date()
        // Hard Mode: mark as proximity-verified when walking via Hard Mode
        if hardMode {
            proximityVerified = true
        }
    }
    updatedAt = Date()
}
```

### WalkRecord.swift — new computed property

Add a convenience computed property for badge display logic:

```swift
var showUnverifiedBadge: Bool {
    hardMode && walked && proximityVerified == false
}
```

---

## 5. UI / Interface

### 5a. Proximity Helper (LocationManager.swift)

Add a public method to the existing `LocationManager` class:

```swift
/// Returns true if user is within the given radius (meters) of the coordinate.
/// Returns false if location is unavailable.
func isWithinRadius(_ meters: Double, ofLatitude lat: Double, longitude lng: Double) -> Bool {
    guard let currentLocation else { return false }
    let target = CLLocation(latitude: lat, longitude: lng)
    return currentLocation.distance(from: target) <= meters
}
```

**Usage from views:**
```swift
let isNearby = locationManager.isWithinRadius(150, ofLatitude: stairway.lat ?? 0, longitude: stairway.lng ?? 0)
```

This is stateless and called at render time. No geofence regions, no background monitoring, no CLRegion registration.

**Note:** `LocationManager.currentLocation` is already `@Observable`. SwiftUI views that read it will re-render when the location updates (distance filter is 50m, so updates are frequent enough for a 150m radius check).

### 5b. StairwayBottomSheet (StairwayBottomSheet.swift)

**New: Hard Mode toggle row** — added below the existing action buttons, above the "View Details" link:

```
┌─────────────────────────────────────┐
│  Vulcan Stairway                    │
│  Noe Valley · 0.3 km               │
│                                     │
│  [Unsave]          [Mark Walked ✓]  │  ← disabled if Hard Mode + out of range
│                                     │
│  ─────────────────────────────────  │
│  🔒 Hard Mode          [Toggle]     │  ← new row
│  Require proximity to mark walked   │
│  ─────────────────────────────────  │
│  [View Details →]                   │
└─────────────────────────────────────┘
```

**Implementation details:**

1. **New environment/state needed:** The view needs access to `LocationManager` to compute proximity. Add `@Environment` or pass it in. Also needs the `Stairway` model (already available as `stairway` property).

2. **Hard Mode toggle row:**
```swift
VStack(alignment: .leading, spacing: 4) {
    Divider()
    HStack {
        Image(systemName: "lock.fill")
            .foregroundColor(.forestGreen)
        Text("Hard Mode")
            .font(.subheadline)
            .fontWeight(.medium)
        Spacer()
        Toggle("", isOn: hardModeBinding)
            .labelsHidden()
    }
    Text("Require proximity to mark walked")
        .font(.caption)
        .foregroundColor(.secondary)
}
```

3. **Hard Mode toggle binding:** This is the trickiest part. The toggle needs to:
   - **If WalkRecord exists:** Toggle `walkRecord.hardMode`. If turning ON and `walked == true`, also set `proximityVerified = false` (marking existing walk as unverified).
   - **If no WalkRecord (unsaved stairway):** Call the `onSave` callback first to create the WalkRecord, then set `hardMode = true` on the newly created record. Because the callback is asynchronous relative to SwiftData context saves, the cleanest approach is: call `onSave()`, then on the next render the `walkRecord` parameter will be non-nil, and the toggle state will reflect `walkRecord.hardMode`. However, this means the toggle fires `onSave` but doesn't set `hardMode = true` in the same gesture. **Recommended solution:** Add a new callback `onToggleHardMode: (Bool) -> Void` that the parent view handles. The parent creates the WalkRecord if needed, then sets `hardMode`. This keeps the bottom sheet stateless.

4. **Mark Walked button disabled state:** When `walkRecord?.hardMode == true`:
   - Compute `let isNearby = locationManager.isWithinRadius(150, ofLatitude: stairway.lat ?? 0, longitude: stairway.lng ?? 0)`
   - If `!isNearby`: apply `.opacity(0.4)` and `.disabled(true)` to the Mark Walked button.
   - If `isNearby`: render normally.
   - If `walkRecord?.hardMode != true`: no change to existing behavior.

5. **"Location required" label:** Show below the Mark Walked button only when `walkRecord?.hardMode == true && locationManager.currentLocation == nil && locationManager.authorizationStatus != .authorizedWhenInUse`:
```swift
Text("Location required for Hard Mode")
    .font(.caption2)
    .foregroundColor(.unwalkedSlate)
```

6. **Hide on closed stairways:** Wrap the Hard Mode toggle section in `if !stairway.isClosed { ... }` (or however the closed state is accessed — verify the property name).

7. **Sheet detent:** The existing `.presentationDetents([.height(340), .medium])` may need the fixed height bumped to ~390 to accommodate the new toggle row. Test visually.

### 5c. StairwayDetail (StairwayDetail.swift)

**Hard Mode toggle** — add the same toggle UI below the existing "Walk Status Card" section (the card with the walked/not-walked toggle button and optional date display).

- Same toggle layout as bottom sheet (lock icon, label, sublabel, Toggle).
- Same binding logic: toggle `walkRecord.hardMode`, create WalkRecord if unsaved.
- Same "Location required" label when applicable.
- Same disabled state on the walked toggle when Hard Mode + out of range.
- Hide on closed stairways.

**Implementation note:** StairwayDetail currently has access to `walkRecord` and `stairway`. It will additionally need access to `LocationManager` (via `@Environment` or passed prop) for the proximity check.

### 5d. Map Pin — Unverified Badge (TeardropPin.swift)

**New parameter on `StairwayPin`:**

Add to existing properties:
```swift
var showUnverifiedBadge: Bool = false
```

Default is `false` so existing call sites don't break.

**Badge overlay** — render when `showUnverifiedBadge == true`:

```swift
// Inside the existing ZStack, after the StairShape icon:
if showUnverifiedBadge {
    Circle()
        .fill(Color.accentAmber)  // #E8A838
        .frame(width: 12, height: 12)
        .overlay(
            Image(systemName: "exclamationmark")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.white)
        )
        .offset(x: pinWidth * 0.35, y: -(pinHeight * 0.35))
}
```

**Positioning notes:**
- The badge sits at the top-right of the teardrop bulb area.
- Using proportional offsets (`pinWidth * 0.35`, `pinHeight * 0.35`) so the badge scales correctly across all three pin sizes (38×48, 44×55, 52×65).
- The badge is a fixed 12pt circle regardless of pin size — small enough to not obscure the pin, large enough to be visible.
- `accentAmber` (#E8A838) is distinct from `brandAmber` (#D4882B, used for unsaved pins) — verify it reads clearly at 12pt on the green walked-pin background.

### 5e. StairwayAnnotation (StairwayAnnotation.swift)

Currently passes `pinState`, `isSelected`, `isDimmed`, `isClosed` to `StairwayPin`.

**Add:** Compute and pass `showUnverifiedBadge`:

```swift
StairwayPin(
    state: pinState,
    isSelected: isSelected,
    isDimmed: isDimmed,
    isClosed: stairway.isClosed,  // verify property name
    showUnverifiedBadge: walkRecord?.showUnverifiedBadge ?? false
)
```

This uses the computed property added to WalkRecord in Section 4.

---

## 6. Integration Points

| File | Change |
|------|--------|
| `Models/WalkRecord.swift` | Add `hardMode: Bool`, `proximityVerified: Bool?`, `showUnverifiedBadge` computed property; modify `toggleWalked()` |
| `Services/LocationManager.swift` | Add `isWithinRadius(_:ofLatitude:longitude:)` method |
| `Views/Map/StairwayBottomSheet.swift` | Hard Mode toggle row, disabled Mark Walked logic, new `onToggleHardMode` callback |
| `Views/Map/StairwayAnnotation.swift` | Pass `showUnverifiedBadge` to `StairwayPin` |
| `Views/Map/TeardropPin.swift` | Add `showUnverifiedBadge` property; render amber badge overlay |
| `Views/Detail/StairwayDetail.swift` | Hard Mode toggle in walk status section, disabled walked toggle, "Location required" label |
| `Views/Map/MapTab.swift` | Pass `onToggleHardMode` callback to bottom sheet; implement the callback (create WalkRecord if needed, set `hardMode`) |

---

## 7. Constraints

- No third-party packages. `CLLocation.distance(from:)` is native.
- No background geofencing (`CLRegion` monitoring). Proximity is checked only at render time when the user is actively viewing a stairway.
- No server-side verification. Trust is entirely client-side.
- SwiftData migration is additive — no destructive schema changes.
- The three-state pin model (Unsaved / Saved / Walked) is unchanged. Hard Mode is a modifier on top of it, not a new state. The badge is a decoration on the Walked state only.
- `accentAmber` (#E8A838) is currently only used for the splash screen. This spec introduces its first in-app usage (unverified badge). Verify it reads clearly at 12pt on the green walked-pin background before shipping.
- The `LocationManager.currentLocation` property is already `@Observable`. SwiftUI views will re-render when location updates, which happens at the existing 50m `distanceFilter`. This is sufficient for a 150m proximity check — no need to decrease the distance filter.
- **Ordering note:** This spec touches `TeardropPin.swift`, which is also touched by the Nav/Pin/Progress Visual spec (StairShape offset fix). If implementing both, the pin offset fix should land first, then the badge overlay is added on top. The badge offset values assume the StairShape is already correctly centered in the bulb.

---

## 8. Acceptance Criteria

- [ ] `hardMode` and `proximityVerified` fields exist on WalkRecord with correct defaults
- [ ] Hard Mode toggle appears in StairwayBottomSheet and StairwayDetail for non-closed stairways
- [ ] Hard Mode toggle is hidden on closed stairways
- [ ] Toggling Hard Mode ON for an unsaved stairway creates a WalkRecord with `walked = false`, `hardMode = true`
- [ ] Toggling Hard Mode ON for an already-walked stairway sets `hardMode = true`, `proximityVerified = false`
- [ ] Mark Walked button is visually disabled (opacity 0.4, non-tappable) when Hard Mode is on and user is >150m from stairway
- [ ] Mark Walked button is active when Hard Mode is on and user is ≤150m from stairway
- [ ] Marking a stairway walked via Hard Mode sets `proximityVerified = true` (via modified `toggleWalked()`)
- [ ] Stairways with `hardMode == true && walked == true && proximityVerified == false` show amber exclamation badge on map pin
- [ ] Badge does not appear on non-Hard-Mode walked stairways
- [ ] Badge does not appear on Hard-Mode stairways where `proximityVerified == true`
- [ ] Badge disappears when Hard Mode is toggled off
- [ ] "Location required for Hard Mode" label appears when location is unavailable and Hard Mode is on
- [ ] Save action works normally on Hard Mode stairways regardless of proximity
- [ ] Existing WalkRecords are unaffected at migration — `hardMode = false`, `proximityVerified = nil`
- [ ] CloudKit sync correctly propagates `hardMode` and `proximityVerified` across devices
- [ ] Bottom sheet height accommodates the new toggle row without clipping
- [ ] Feedback loop prompt has been run

---

## 9. Files Likely Touched

| File | Change |
|------|--------|
| `Models/WalkRecord.swift` | Add `hardMode: Bool = false`, `proximityVerified: Bool? = nil`, `showUnverifiedBadge` computed prop; modify `toggleWalked()` |
| `Services/LocationManager.swift` | Add `isWithinRadius(_:ofLatitude:longitude:)` method |
| `Views/Map/MapTab.swift` | Wire `onToggleHardMode` callback to bottom sheet; implement Hard Mode WalkRecord creation/toggle |
| `Views/Map/StairwayBottomSheet.swift` | Hard Mode toggle row; Mark Walked disabled state; `onToggleHardMode` callback prop; "Location required" label |
| `Views/Map/StairwayAnnotation.swift` | Pass `showUnverifiedBadge` from WalkRecord to StairwayPin |
| `Views/Map/TeardropPin.swift` | Add `showUnverifiedBadge: Bool` property; render amber Circle + exclamationmark overlay |
| `Views/Detail/StairwayDetail.swift` | Hard Mode toggle below walk status card; disabled walked toggle; "Location required" label; needs LocationManager access |
