# SPEC: Camera During Active Walk
**Project:** sf-stairways
**Date:** 2026-03-28
**Status:** Ready for implementation

---

## 1. Objective

Enable users to easily take photos during an active walk session by adding a prominent camera button to the active session banner. Photos taken mid-walk should be seamlessly attached to the walk record being tracked.

---

## 2. Scope

### In Scope
- Add a camera button to the `activeSessionBanner` in `StairwayBottomSheet.swift`
- Button should be visually prominent (large, easily tappable) alongside "End Walk" and "Cancel" buttons
- Reuse existing `CameraPicker` and `PhotoPicker` components
- Ensure photos taken during active walk are properly buffered and attached to the walk record
- Handle the case where a walk record may not yet exist when photos are taken

### Out of Scope
- Changes to the header camera menu (already works and is now more visible with `camera.fill` + `Color.forestGreen`)
- Photo editing, filtering, or post-processing
- Camera permissions flow (use existing permission handling in `CameraPicker`)
- CloudKit/Supabase sync details for photos (delegate to existing `addPhoto` mechanism)

---

## 3. Business Rules

1. **Photo Availability:** Camera and photo library options must be available during an active walk, not just in the detail view header.

2. **Walk Record Lifecycle:**
   - Create `WalkRecord` immediately when "Start Walk" is tapped (with `walked: false`)
   - Photos taken during the session attach to this record directly
   - Set `walked: true` when "End Walk" is tapped
   - If "Cancel" is tapped, the `WalkRecord` remains (with `walked: false`) but photos are still attached to it—the user can later resume or delete if they choose

3. **Photo Attribution:** All photos taken during an active walk session must be attributed to the walk record for that session. Timestamp and location (if available via `LocationManager`) should be captured by `WalkPhoto`.

4. **UI Consistency:** The camera button in the banner should have the same visual style as "End Walk" and "Cancel" buttons (consistent icon, color, size, spacing).

---

## 4. Data Model / Schema Changes

### No Schema Changes Required
The existing `WalkRecord` and `WalkPhoto` models already support photos attached to a walk.

### Code Changes
- **`ActiveWalkManager.swift`:** When `startWalk()` is called, immediately create and persist a `WalkRecord` with `walked: false`. This record becomes the target for photos taken during the session.
- **`WalkRecord` (if needed):** Verify `walked` property exists and defaults to `false`. On `endWalk()`, set `walked: true`. On `cancelWalk()`, leave as `false` (users can review/delete later).

---

## 5. UI / Interface

### Active Session Banner Layout
Current banner shows:
```
[Elapsed Timer (MM:SS)] [End Walk] [Cancel]
```

New banner layout (horizontal stack):
```
[Elapsed Timer] [Camera] [End Walk] [Cancel]
```

### Camera Button Specifications
- **Icon:** `camera.fill` (matches header camera icon for consistency)
- **Color:** `Color.forestGreen` (matching the header icon update)
- **Size:** Same as action buttons (44pt+ tap target)
- **Action:** Tap opens a simple menu with two options:
  1. "Take Photo" → opens `CameraPicker` (full-screen)
  2. "Choose from Library" → opens `PhotoPicker` (sheet)
- **Behavior:** After photo is selected/taken, immediately return to active walk banner (dismiss sheet/full-screen cover). The photo is attached to the active `WalkRecord` via `addPhoto(imageData:)`.

### State Management
- Reuse existing `showCamera` and `showPhotoPicker` state variables in `StairwayBottomSheet`
- These variables already toggle visibility of `CameraPicker` and `PhotoPicker`
- Ensure they are properly reset after a photo is added

---

## 6. Integration Points

### `StairwayBottomSheet.swift`
- Add camera button to `activeSessionBanner` view
- Position: between elapsed timer and "End Walk" button
- Tap handler: toggle a new menu (or reuse existing menu pattern) to show "Take Photo" and "Choose from Library" options

### `ActiveWalkManager.swift`
- **`startWalk()`:** Create a `WalkRecord` immediately with:
  - `stairwayID`: the stairway being walked
  - `startTime`: current time
  - `walked: false`
  - Persist to SwiftData/CloudKit
- **`endWalk()`:** Set `walked: true` on the `WalkRecord`, finalize timing, and persist
- **`cancelWalk()`:** Leave `walked: false`, mark as cancelled (or introduce a `status` enum), persist

### `CameraPicker` / `PhotoPicker`
- No changes required
- Continue to call `addPhoto(imageData:)` which attaches photos to the current `WalkRecord`

### `WalkPhoto` / `WalkRecord`
- Verify relationship is properly established
- Ensure `addPhoto(imageData:)` targets the active `WalkRecord` (get it from `ActiveWalkManager.currentWalkRecord` or similar)

---

## 7. Constraints

1. **Camera Permissions:** User must grant camera permissions before using the camera. This is handled by `CameraPicker`; no additional permission flow needed.

2. **Photo Timing:** Photos taken during walk must be timestamped accurately (captured by `WalkPhoto` automatically).

3. **Walk Record Must Exist:** The camera button should only appear if a walk is actively in progress. This is already guaranteed by the `activeSessionBanner` only being shown when `activeWalkManager.isWalkActive == true`.

4. **Button Layout:** The active session banner may need layout adjustments to fit camera button without overcrowding. Ensure all buttons remain easily tappable (44pt minimum tap target).

5. **Performance:** Creating a `WalkRecord` on "Start Walk" vs. deferring until "End Walk" must not impact app startup or walk initiation performance.

---

## 8. Acceptance Criteria

- [ ] Camera button appears in `activeSessionBanner` when a walk is active
- [ ] Camera button is visually prominent (44pt+ tap target, green color, clear icon)
- [ ] Tapping camera button opens a menu with "Take Photo" and "Choose from Library" options
- [ ] Selecting "Take Photo" opens the camera via `CameraPicker`
- [ ] Selecting "Choose from Library" opens photo picker via `PhotoPicker`
- [ ] Photos taken/selected during active walk are attached to the active `WalkRecord`
- [ ] After a photo is added, the app returns to the active session banner (camera sheet/cover is dismissed)
- [ ] `WalkRecord` is created immediately on "Start Walk" with `walked: false`
- [ ] `walked` is set to `true` on "End Walk"
- [ ] Cancelling a walk leaves the `WalkRecord` in `walked: false` state (for potential review)
- [ ] All photos are properly synced via CloudKit/existing sync mechanism
- [ ] Camera button behavior is consistent with header camera icon (same icon, color, actions)
- [ ] No regression in existing photo upload workflow from the header menu

---

## 9. Files Likely Touched

### Primary Files
1. **`ios/SFStairways/Views/StairwayBottomSheet.swift`**
   - Add camera button to `activeSessionBanner` view
   - Connect tap handler to `showCamera` / `showPhotoPicker` state or menu logic

2. **`ios/SFStairways/Services/ActiveWalkManager.swift`**
   - Modify `startWalk()` to create `WalkRecord` immediately (not on end)
   - Add `currentWalkRecord` property to track active walk's record
   - Modify `endWalk()` to set `walked: true`
   - Modify `cancelWalk()` to handle incomplete walks

3. **`ios/SFStairways/Models/WalkRecord.swift`** (if needed)
   - Verify `walked: Bool` property exists and is properly initialized
   - Ensure relationship to `WalkPhoto` is bidirectional

### Secondary Files
4. **`ios/SFStairways/Models/WalkPhoto.swift`** (review only)
   - Verify photo model stores timestamp, location, and walk reference

5. **`ios/SFStairways/Services/PhotoService.swift`** (review only)
   - Verify `addPhoto(imageData:)` correctly attaches to current walk record

### No Changes Needed
- `CameraPicker.swift` (reuse as-is)
- `PhotoPicker.swift` (reuse as-is)
- Header camera menu icon (already updated to `camera.fill` + `Color.forestGreen`)

---

## Implementation Notes

- **Walk Record Creation Timing:** Creating the record on "Start Walk" rather than "End Walk" simplifies photo attachment logic and allows mid-walk deletion recovery. Verify this doesn't conflict with any existing walk-lifecycle logic.
- **Menu Pattern:** Determine if a simple action sheet/alert menu is preferred, or if a custom menu view matches the app's design language better.
- **Testing:** Test photo attachment during a walk that is later cancelled to ensure orphaned photos are handled gracefully.
