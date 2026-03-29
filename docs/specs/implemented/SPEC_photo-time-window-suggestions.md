SPEC: Photo Time-Window Suggestions | Project: sf-stairways | Date: 2026-03-28 | Status: Ready for implementation

## 1. Objective

When a stairway has been marked as walked with a recorded date, automatically query the device's Photos library for images taken on that same day and surface them as inline suggestions in the bottom sheet. This mirrors Strava's post-walk photo suggestion behavior without requiring any Strava integration.

## 2. Scope

- New "Suggested Photos" inline section in `StairwayBottomSheet.swift`, positioned between the notes section and `PhotoCarousel`
- Query `PHPhotoLibrary` for images taken on `dateWalked` (full calendar day, device local time)
- Exclude images already added to this walk's photos (both local `WalkPhoto` and Supabase `SupabasePhoto`)
- Section dismisses permanently once the user has acted on all suggestions (added or dismissed individually)
- Only appears when: walk is marked as walked (`walked == true`), `dateWalked` is set, and at least one unreviewed suggestion exists

## 3. Business Rules

- **Time window:** Full calendar day of `dateWalked` in device local timezone (00:00:00 to 23:59:59). If `walkStartTime`/`walkEndTime` are set (from Active Walk Mode, a separate spec), use those precise timestamps instead.
- **Deduplication:** Any `PHAsset` whose `localIdentifier` matches an ID in `WalkRecord.addedPhotoAssetIDs` or `WalkRecord.dismissedPhotoIDs` is excluded from suggestions.
- **Persistence of dismissal:** If the user taps the dismiss button on a suggested photo, that `PHAsset.localIdentifier` is stored in `WalkRecord.dismissedPhotoIDs` so it is never re-suggested for this walk. Syncs via CloudKit.
- **Add behavior:** Tapping the add button on a suggestion creates a `WalkPhoto` with full-res `imageData` and thumbnail (same path as the existing photo picker), and appends the `PHAsset.localIdentifier` to `WalkRecord.addedPhotoAssetIDs` so it won't re-appear as a suggestion.
- **Section visibility:** Hidden entirely if walk is unwalked, no date is set, photo library permission is not `.authorized` or `.limited`, or all suggestions have been added/dismissed.
- **No permission prompt:** This feature does not independently trigger a photo library permission request. It relies on the existing photo picker or camera roll fix to have prompted earlier. If permission hasn't been granted, the section simply doesn't appear.

## 4. Data Model / Schema Changes

Add two fields to `WalkRecord`:

```swift
var dismissedPhotoIDs: [String] = []     // PHAsset localIdentifiers dismissed by user
var addedPhotoAssetIDs: [String] = []    // PHAsset localIdentifiers already added via suggestions
```

Both are `[String]` with default `[]`. CloudKit compatible (array of strings syncs fine). No migration risk.

Note: `addedPhotoAssetIDs` is needed because the existing `WalkPhoto` model does not store the source `PHAsset.localIdentifier`. Adding an optional field to `WalkPhoto` is an alternative but changes the model for a single feature's dedup need. The parallel array on `WalkRecord` is simpler.

## 5. UI / Interface

### Suggested Photos Section

Appears in `StairwayBottomSheet.swift` in the expanded content area, between `notesSection` and `PhotoCarousel`. Uses a horizontal scroll layout to match the existing carousel style.

```
┌─────────────────────────────────────────┐
│  Suggested from March 28, 2026          │  section header, .caption / .secondary
│  ┌──────┐  ┌──────┐  ┌──────┐    →     │  horizontal ScrollView
│  │ img  │  │ img  │  │ img  │          │  ~100x100pt thumbnail cards
│  │ [+]  │  │ [+]  │  │ [✕]  │          │  per-photo add/dismiss overlays
│  └──────┘  └──────┘  └──────┘          │
└─────────────────────────────────────────┘
```

- Horizontal `ScrollView` of thumbnail cards, approximately 100x100pt each (close to the 120x120 existing carousel cells but slightly smaller to visually distinguish suggestions from confirmed photos)
- Each card: thumbnail from `PHAsset` (loaded via `PHImageManager`), "+" overlay button (bottom-left, add) and "x" overlay button (top-right, dismiss)
- Section header: "Suggested from [formatted date]" in `.caption` / `.secondary` style
- No "Add All" button. Per-photo control only.
- Section animates out (`.transition(.opacity)`) when all suggestions are resolved
- Adding a photo shows a brief loading indicator on the card while the full-res image is fetched

### Existing PhotoCarousel

Unchanged. Newly added photos from suggestions appear in the carousel on the next render (they're added to `WalkRecord.photos` via the same path as picker-added photos).

## 6. Integration Points

**New file: `Services/PhotoSuggestionService.swift`**

An `@Observable` class that:

1. Takes `dateWalked: Date`, `walkStartTime: Date?`, `walkEndTime: Date?`, `addedPhotoAssetIDs: [String]`, and `dismissedPhotoIDs: [String]`
2. Checks `PHPhotoLibrary.authorizationStatus(for: .readWrite)`. If not `.authorized` or `.limited`, returns empty.
3. Builds `PHFetchOptions` with predicate: `creationDate >= dayStart AND creationDate <= dayEnd` (or precise start/end if available), sorted by `creationDate` ascending.
4. Filters out assets whose `localIdentifier` is in `addedPhotoAssetIDs` or `dismissedPhotoIDs`.
5. Exposes `suggestions: [PHAsset]` on `@MainActor`.
6. Provides `loadFullImage(asset:) async -> Data?` helper using `PHImageManager.requestImage` for adding.

**`StairwayBottomSheet.swift` integration:**

- Add `@State private var suggestionService = PhotoSuggestionService()` (or instantiate in `.task`)
- In `.task` block (alongside existing curator/photo fetches), call `suggestionService.fetch(...)` with the walk record's dates and ID arrays
- Insert the suggested photos section view between `notesSection` and `PhotoCarousel`
- "Add" action: load full image from `PHAsset`, call existing `addPhoto(imageData:)`, append `localIdentifier` to `walkRecord.addedPhotoAssetIDs`, save context
- "Dismiss" action: append `localIdentifier` to `walkRecord.dismissedPhotoIDs`, save context

**Relationship to SPEC_photo-persistence-fix.md:**

The photo persistence fix ensures photos added via `addPhoto()` are visible in the carousel (both local and remote). Photo suggestions use the same `addPhoto()` path, so suggested photos will appear correctly once the persistence fix is implemented. These two specs should be implemented in order: persistence fix first, then suggestions.

## 7. Constraints

- `PhotosUI` / `Photos` framework only. No new third-party dependencies.
- `PHImageManager` requests must run off main thread. UI updates on `@MainActor`.
- Full-res image load (on add) should show a brief loading state on the card.
- Must not query Photos library on every SwiftUI render. Fetch once in `.task`, refresh only if `dateWalked` changes.
- `dismissedPhotoIDs` and `addedPhotoAssetIDs` must have default values of `[]` to satisfy CloudKit sync requirements.
- Requires `NSPhotoLibraryUsageDescription` in Info.plist (full read access, since we're fetching assets from the library). This is a broader permission than the add-only permission from the camera roll fix. Add: `"SF Stairways suggests photos from your library taken on the day you walked a stairway."`

## 8. Acceptance Criteria

- [ ] Bottom sheet for a walked stairway with a set date shows "Suggested from [date]" section if matching photos exist in the library
- [ ] Photos already added to the walk (via picker, camera, or previous suggestion) are excluded from suggestions
- [ ] Tapping "+" on a suggestion adds the photo to the walk's photo carousel and removes it from suggestions
- [ ] Tapping dismiss on a suggestion removes it from suggestions permanently (survives app restart and syncs via CloudKit)
- [ ] Section is hidden when walk is unwalked, date is unset, or all suggestions are resolved
- [ ] Section is hidden when photo library permission is not granted (no new permission prompt triggered by this feature)
- [ ] If `walkStartTime`/`walkEndTime` are set, the query uses the precise window instead of full day
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Models/WalkRecord.swift` — add `dismissedPhotoIDs: [String] = []` and `addedPhotoAssetIDs: [String] = []`
- `ios/SFStairways/Services/PhotoSuggestionService.swift` — new file, PHFetch query by date window
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — add suggested photos section in expanded content, wire add/dismiss actions
- Xcode Info tab — add `NSPhotoLibraryUsageDescription`
