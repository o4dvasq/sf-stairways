# SPEC: Hard Mode Confirmation Prompt
**Project:** sf-stairways | **Date:** 2026-03-28 | **Status:** Ready for implementation

---

## 1. Objective

Replace the Hard Mode button-disabling behavior with a **confirmation prompt + unverified badge** approach. Rather than blocking Mark Walked when a user is out of range, allow them to always log a walk, but distinguish between proximity-verified (user was at the stairway) and unverified (logged from distance). This preserves Hard Mode's integrity signaling while avoiding punitive UX.

---

## 2. Scope

- Mark Walked button behavior in `StairwayBottomSheet.swift` (detail view)
- Active Walk Mode completion in `ActiveWalkManager`
- Walk record UI to show amber badge for unverified walks
- No per-stairway Hard Mode — this remains a global user-level toggle

**Out of scope:**
- New Hard Mode toggle (already exists in `AuthManager`)
- Changes to the Hard Mode setting UI in `SettingsView.swift`
- Pre-existing walk records or backward compatibility (handled by existing spec)

---

## 3. Business Rules

| Condition | Hard Mode | User Location | Action | Result |
|-----------|-----------|---------------|--------|--------|
| Mark Walked tapped | OFF | any | Mark immediately | `proximityVerified = nil`, no badge |
| Mark Walked tapped | ON | ≤150m | Mark immediately | `proximityVerified = true`, no badge |
| Mark Walked tapped | ON | >150m | Show confirmation alert | User taps Cancel: no change; User taps Mark Anyway: `proximityVerified = false`, amber badge |
| Active Walk Mode completed | ON | (implicit present) | Mark immediately | `proximityVerified = true`, no badge |
| Active Walk Mode completed | OFF | (any) | Mark immediately | `proximityVerified = nil`, no badge |

- **Mark Walked button is NEVER disabled** — always tappable, always interactive
- **Confirmation prompt only shows** when Hard Mode is ON and user is >150m from stairway
- **Amber badge** shown on walk records where `proximityVerified == false`
- **Active Walk Mode** implies presence — no proximity check required

---

## 4. Data Model / Schema Changes

### WalkRecord Model

Existing fields (no schema migration required):
```swift
var hardMode: Bool = false              // deprecated, kept for backward compat
var proximityVerified: Bool? = nil      // three-state: true/false/nil
var hardModeAtCompletion: Bool = false  // when logged, did user have Hard Mode ON?
```

**No new fields required.** The existing `proximityVerified` property handles all three states:
- `nil` = Hard Mode OFF or not yet defined (legacy walks)
- `true` = Hard Mode ON and user was within 150m (or completed Active Walk Mode)
- `false` = Hard Mode ON and user was >150m when confirmed "Mark Anyway"

---

## 5. UI / Interface

### 5.1 Mark Walked Button

**Current state** (`StairwayBottomSheet.swift`):
```swift
private var isMarkWalkedDisabled: Bool {
    guard authManager.hardModeEnabled else { return false }
    return !locationManager.isWithinRadius(150, ofLatitude: stairway.lat ?? 0, longitude: stairway.lng ?? 0)
}
```

Button is bound to `.disabled(isMarkWalkedDisabled)` and shows text "Hard Mode: get within 150m to mark as walked".

**After implementation:**
- Remove the `isMarkWalkedDisabled` computed property
- Remove `.disabled(isMarkWalkedDisabled)` modifier
- Remove the "Hard Mode: get within 150m..." help text
- Button always shows "Mark Walked" and is always enabled
- Tapping Mark Walked calls a new method `attemptMarkWalked()` that checks proximity before logging

### 5.2 Confirmation Alert

**When Hard Mode is ON and user is >150m away:**

```
Title:     "Mark as walked?"
Body:      "You're not near this stairway. You can still log it, but it won't count as proximity-verified."
Buttons:   [Cancel]  [Mark Anyway]
```

**Implementation:**
```swift
func attemptMarkWalked() {
    guard authManager.hardModeEnabled else {
        // Hard Mode OFF: mark immediately
        markWalked()
        return
    }

    let isWithinRange = locationManager.isWithinRadius(150,
        ofLatitude: stairway.lat ?? 0,
        longitude: stairway.lng ?? 0)

    if isWithinRange {
        // Hard Mode ON + within 150m: mark immediately
        markWalked()
    } else {
        // Hard Mode ON + out of range: show confirmation alert
        showConfirmationAlert()
    }
}

private func showConfirmationAlert() {
    let alert = UIAlertController(
        title: "Mark as walked?",
        message: "You're not near this stairway. You can still log it, but it won't count as proximity-verified.",
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Mark Anyway", style: .default) { _ in
        self.markWalked(proximityVerified: false)
    })

    // Present alert
}

private func markWalked(proximityVerified: Bool? = nil) {
    let record = WalkRecord(
        stairwayId: stairway.id,
        date: Date(),
        hardModeAtCompletion: authManager.hardModeEnabled,
        proximityVerified: proximityVerified
    )

    // If Hard Mode ON and no explicit proximityVerified passed, default to true
    if authManager.hardModeEnabled && proximityVerified == nil {
        record.proximityVerified = true
    }

    // Save record
}
```

**Cancel:** Dismisses alert, no changes to record or UI.
**Mark Anyway:** Dismisses alert, logs walk with `proximityVerified = false`.

### 5.3 Amber Badge on Walk Records

**Current badge logic** (should already be present from existing Hard Mode spec):

On walk list rows and detail views, show an amber `⚠️` badge when:
```swift
if let proximityVerified = walkRecord.proximityVerified, !proximityVerified {
    // Show amber badge
}
```

**No UI changes required** — this badge behavior is inherited from the original Hard Mode spec.

---

## 6. Integration Points

### 6.1 StairwayBottomSheet.swift

File path: `ios/SFStairways/Views/StairwayBottomSheet.swift`

**Current Mark Walked button logic:**
- Remove `isMarkWalkedDisabled` computed property
- Remove `.disabled(isMarkWalkedDisabled)` modifier
- Replace button action with call to `attemptMarkWalked()` (new method)

**New method to add:**
- `attemptMarkWalked()` — determines whether to prompt or mark immediately
- `showConfirmationAlert()` — presents UIAlertController with confirmation prompt
- `markWalked(proximityVerified:)` — logs walk record with appropriate `proximityVerified` value

### 6.2 ActiveWalkManager (Start Walk / Stop Walk)

File path: `ios/SFStairways/Services/ActiveWalkManager.swift` (or equivalent)

**Current behavior:** When user taps "Stop Walk" / ends session, log a walk record.

**After implementation:**
When logging a walk from Active Walk Mode completion:
```swift
func endActiveWalk(for stairway: Stairway) {
    let record = WalkRecord(
        stairwayId: stairway.id,
        date: Date(),
        hardModeAtCompletion: authManager.hardModeEnabled,
        proximityVerified: authManager.hardModeEnabled ? true : nil
    )
    // Save record
}
```

**Rationale:** Starting a walk at the stairway implies physical presence. No proximity check or prompt needed. If Hard Mode is ON, automatically set `proximityVerified = true`.

### 6.3 WalkRecord Model

File path: `ios/SFStairways/Models/WalkRecord.swift`

**No schema changes required.** Existing fields are sufficient:
- `hardModeAtCompletion: Bool` — already captures whether Hard Mode was ON when walk was logged
- `proximityVerified: Bool?` — already supports three-state logic

**Ensure initializer accepts `proximityVerified` parameter** (if not already present):
```swift
init(
    stairwayId: UUID,
    date: Date,
    hardModeAtCompletion: Bool,
    proximityVerified: Bool? = nil
) {
    // ...
}
```

### 6.4 LocationManager

No changes required. Continue to use existing method:
```swift
func isWithinRadius(_ radiusMeters: Double, ofLatitude lat: Double, ofLongitude lng: Double) -> Bool
```

### 6.5 AuthManager

No changes required. Continue to use existing property:
```swift
var hardModeEnabled: Bool
```

---

## 7. Constraints

- **150m proximity threshold** is fixed (same as original Hard Mode spec)
- **No new data model fields** — all state fits into existing `proximityVerified` property
- **Alert presentation** must be in SwiftUI (use `@State` alert or `.alert()` modifier with Combine state)
- **Active Walk Mode** behavior is deterministic — no prompt, always sets `proximityVerified = true` when Hard Mode is ON
- **Pre-existing walks** with `proximityVerified = nil` retain amber badge behavior (original spec unchanged)

---

## 8. Acceptance Criteria

- [ ] Mark Walked button is NEVER disabled — always tappable regardless of Hard Mode or user location
- [ ] Hard Mode OFF: Mark Walked logs immediately, no prompt shown, `proximityVerified = nil`
- [ ] Hard Mode ON + within 150m: Mark Walked logs immediately, no prompt shown, `proximityVerified = true`, no amber badge
- [ ] Hard Mode ON + >150m: Confirmation alert shown with "Mark as walked?" title and out-of-range message
- [ ] Confirmation alert Cancel button: dismisses alert, no walk logged, no UI changes
- [ ] Confirmation alert Mark Anyway button: logs walk with `proximityVerified = false`, amber badge shown on record
- [ ] Active Walk Mode completion: walks logged with `proximityVerified = true` (if Hard Mode ON) or `nil` (if Hard Mode OFF), no prompt shown
- [ ] Amber badge displays on walk records where `proximityVerified == false` (both in list and detail views)
- [ ] All existing Hard Mode tests pass; new tests added for confirmation prompt logic
- [ ] Code compiles without warnings

---

## 9. Files Likely Touched

| File | Change Summary |
|------|-----------------|
| `ios/SFStairways/Views/StairwayBottomSheet.swift` | Remove `isMarkWalkedDisabled` logic; add `attemptMarkWalked()`, `showConfirmationAlert()`, `markWalked(proximityVerified:)` methods; bind Mark Walked button to new logic |
| `ios/SFStairways/Services/ActiveWalkManager.swift` | When ending session: set `proximityVerified = true` if Hard Mode is ON |
| `ios/SFStairways/Models/WalkRecord.swift` | Ensure initializer accepts `proximityVerified` parameter (likely already present) |
| `ios/SFStairways/Views/[List/Detail Views]` | Verify amber badge displays when `proximityVerified == false` (existing logic, no changes expected) |

**No new files required.**

---

## Implementation Notes

1. **Alert presentation in SwiftUI:** Use `.alert()` modifier with a state variable to manage alert visibility, or wrap UIAlertController in a `UIViewControllerRepresentable` if needed for consistency with existing codebase style.

2. **Proximity check:** Reuse `locationManager.isWithinRadius(150, ...)` — do not create new location methods.

3. **State stamping:** Always capture `authManager.hardModeEnabled` at log time (already done via `hardModeAtCompletion`). This preserves historical context if Hard Mode is later disabled.

4. **Badge logic:** The amber badge for `proximityVerified == false` is inherited from the original Hard Mode spec. Verify it's already implemented in walk list and detail views.

5. **Active Walk Mode:** Confirm `ActiveWalkManager` has access to `authManager` for the Hard Mode check. If it doesn't, add dependency injection.

6. **Testing:** Add unit tests for:
   - `attemptMarkWalked()` calls `showConfirmationAlert()` when Hard Mode ON and >150m
   - `attemptMarkWalked()` calls `markWalked()` directly when Hard Mode ON and ≤150m
   - `attemptMarkWalked()` calls `markWalked()` directly when Hard Mode OFF (any location)
   - Alert Cancel does not create a record
   - Alert Mark Anyway creates record with `proximityVerified = false`
   - Active Walk Mode completion sets `proximityVerified = true` when Hard Mode ON

