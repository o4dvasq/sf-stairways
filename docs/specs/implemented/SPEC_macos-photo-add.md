SPEC: macOS Photo Add + Notes Editing | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

## 1. Objective

Add the ability to retroactively add photos to stairway walk records from the macOS admin dashboard. This lets Oscar go back and attach photos taken on walks before the iOS app's photo workflow was working correctly. Also make personal notes editable from the Mac.

## 2. Scope

**A. Add photos from Mac**
- Add an "Add Photos" button to the photosSection in StairwayDetailPanel
- Clicking it opens an NSOpenPanel (standard macOS file picker) for selecting one or more image files (jpg, png, heic)
- Selected images are read as Data, a WalkPhoto is created for each, and attached to the stairway's WalkRecord
- Thumbnails are generated on import (use NSImage since UIImage is unavailable on macOS)
- Photos sync to iOS via CloudKit automatically
- If the stairway has no WalkRecord yet (not walked), either: (a) disable the Add Photos button with a note "Mark as walked first", or (b) auto-create a WalkRecord when adding photos. Prefer (a) for simplicity.
- Support drag-and-drop of image files onto the photos section as an alternative to the file picker

**B. Make personal notes editable on Mac**
- Currently the notes section shows personal notes as read-only text with a "Promote to Curator Description" button
- Add a "Edit" button that switches the notes text to an editable TextEditor
- Save edits back to WalkRecord.notes
- Keep the "Promote to Curator Description" button

**C. macOS thumbnail generation**
- WalkPhoto.generateThumbnail currently uses UIKit (guarded with #if canImport(UIKit)), falling back to returning the original data on macOS
- Add a proper macOS path using NSImage + NSBitmapImageRep to generate a scaled-down JPEG thumbnail (300px max width, 0.7 quality, matching the iOS behavior)
- This ensures thumbnails created on Mac are the same size as iOS thumbnails

## 3. Business Rules

- Photos added on Mac create WalkPhoto records in SwiftData, which sync via CloudKit to iOS
- Photos should be compressed before storage (JPEG 0.85, same as iOS PhotoService)
- HEIC files should be converted to JPEG on import
- The stairway must have a WalkRecord to attach photos (photos belong to a walk)
- Notes edits sync to iOS via CloudKit

## 4. Data Model / Schema Changes

None. Uses existing WalkPhoto model. The #if canImport(UIKit) guard in WalkPhoto.swift already handles the platform split.

## 5. UI / Interface

**Photos section in StairwayDetailPanel:**
- Existing photo grid (unchanged)
- Below the grid (or above it): "Add Photos..." button that opens NSOpenPanel
- Drop target indicator when dragging image files over the section
- After adding: new photos appear in the grid immediately

**Notes section in StairwayDetailPanel:**
- Personal notes displayed as text (current behavior)
- "Edit" button next to the "Personal Notes" label
- When editing: TextEditor replaces the Text view, with Save/Cancel buttons
- "Promote to Curator Description" button (unchanged)

## 6. Integration Points

- CloudKit: WalkPhoto records (including externalStorage blobs) sync to iOS
- Note: .externalStorage photos via CloudKit can be slow for large images. Compressing to JPEG 0.85 before storing helps.

## 7. Constraints

- No UIKit on macOS. Use NSImage, NSBitmapImageRep for image processing.
- Match iOS photo compression: JPEG quality 0.85, thumbnail at 300px max width quality 0.7
- NSOpenPanel must allow multiple selection and filter to image file types

## 8. Acceptance Criteria

- "Add Photos..." button appears in the photos section for walked stairways
- Clicking it opens a macOS file picker filtered to image types
- Selected images are added as WalkPhoto records with proper thumbnails
- Photos appear in the grid immediately after adding
- Photos sync to iOS app via CloudKit
- Personal notes can be edited inline and saved
- Notes edits sync to iOS
- Drag-and-drop of image files onto the photos section works
- Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairwaysMac/Views/StairwayDetailPanel.swift` — add photo button, NSOpenPanel, drag-drop, notes editing
- `ios/SFStairways/Models/WalkPhoto.swift` — improve macOS thumbnail generation in the #else branch
