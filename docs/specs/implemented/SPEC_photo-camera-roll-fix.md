SPEC: Photo Camera Roll Save Fix | Project: sf-stairways | Date: 2026-03-28 | Status: Ready for implementation

## 1. Objective

Fix a bug where photos taken using the in-app camera are saved to SwiftData/CloudKit but not written to the user's camera roll. Photos should persist in both places so the user has a copy in their system Photos library.

## 2. Scope

- Fix the camera capture path in `CameraPicker` (inside `Services/PhotoService.swift`) to write captured images to `PHPhotoLibrary`
- Verify the app has `NSPhotoLibraryAddUsageDescription` permission declared
- No changes to the photo picker path ("Choose from Library" already reads from the library; those images are already in the camera roll)
- No UI changes

## 3. Business Rules

- When the user captures a photo using the in-app camera ("Take Photo"), the image must be saved to the system camera roll in addition to being stored in SwiftData.
- If the user denies photo library add permission, the photo still saves to SwiftData (the app's internal record) but does not save to camera roll. No error shown; silent fallback.
- This fix applies only to new captures going forward; no retroactive action on previously captured photos.

## 4. Data Model / Schema Changes

None. No changes to `WalkPhoto` or `WalkRecord`.

## 5. UI / Interface

None. This is a silent behavior fix. No new UI elements.

## 6. Integration Points

**`Services/PhotoService.swift` — `CameraPicker.Coordinator.imagePickerController(_:didFinishPickingMediaWithInfo:)`**

This is where the `UIImage` is available before it's converted to `Data` and returned via `onCapture`. The camera roll save should happen here, since we have the full `UIImage` object:

```swift
func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
) {
    picker.dismiss(animated: true)
    guard let image = info[.originalImage] as? UIImage,
          let data = image.jpegData(compressionQuality: 0.85) else { return }

    // Save to camera roll (silent failure if permission denied)
    PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAsset(from: image)
    }, completionHandler: nil)

    DispatchQueue.main.async {
        self.onCapture(data)
    }
}
```

Add `import Photos` at the top of the file.

**Info.plist (via Xcode Info tab):**

Verify `NSPhotoLibraryAddUsageDescription` is present. If missing, add it:
- Key: `NSPhotoLibraryAddUsageDescription`
- Value: `"Stairway photos are saved to your camera roll."`

Note: `NSPhotoLibraryAddUsageDescription` only requires "add" permission (not full read access). This is separate from `NSPhotoLibraryUsageDescription`, which will be needed later by the photo suggestions feature.

## 7. Constraints

- Native `Photos` framework only, no new dependencies.
- `PHPhotoLibrary.performChanges` is async and must not block the main thread. The `onCapture` callback should fire regardless of whether the camera roll save succeeds.
- Silent failure on permission denial. Do not show error toast or alert.

## 8. Acceptance Criteria

- [ ] User taps "Take Photo" in the bottom sheet, takes a photo. It appears in the photo carousel AND in the system camera roll (Photos app).
- [ ] Behavior is unchanged for photos added via "Choose from Library" (picker path).
- [ ] If photo library add permission is denied, photo still saves to SwiftData without crashing or showing an error.
- [ ] No new permission prompts appear for users who have already granted add-only photo access.
- [ ] Feedback loop prompt has been run.

## 9. Files Likely Touched

- `ios/SFStairways/Services/PhotoService.swift` — add `import Photos`, add `PHPhotoLibrary.performChanges` in `CameraPicker.Coordinator`
- Xcode Info tab — verify/add `NSPhotoLibraryAddUsageDescription`
