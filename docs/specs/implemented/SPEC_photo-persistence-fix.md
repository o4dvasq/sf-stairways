SPEC: Photo Persistence Fix — Local Photos Not Displayed | Project: sf-stairways | Date: 2026-03-28 | Status: Ready for implementation

## 1. Objective

Fix the bug where photos added during a walk are saved to SwiftData but never appear in the UI. The photo carousel currently only renders Supabase-hosted photos, so any photo added without a successful Supabase upload (no auth, offline, upload failure) is invisible despite being persisted locally.

## 2. Scope

Photo display pipeline only. No changes to Supabase upload logic, photo likes, or curator features.

## 3. Business Rules

- Photos saved locally via SwiftData must always be visible in the carousel, regardless of Supabase auth or connectivity state.
- If a photo exists both locally (SwiftData `WalkPhoto`) and remotely (Supabase `walk_photos` table), it should not appear twice.
- Local-only photos should be visually distinguished (e.g., a small cloud-slash icon overlay or subtle badge) so the user knows they haven't synced yet. This is optional but recommended.
- Photo display order: most recent first, same as current Supabase sort. Local-only photos interleave by `takenAt` / `createdAt` date.

## 4. Data Model / Schema Changes

None. The `WalkRecord.photos: [WalkPhoto]?` relationship and `WalkPhoto` model already store local photos correctly. The data is there; it's just not read by the display layer.

## 5. UI / Interface

### Root Causes (two independent bugs)

**Bug A — Local photos never displayed:**
`StairwayBottomSheet` passes `photoLikeService.sortedPhotos` (type `[SupabasePhoto]`) to `PhotoCarousel`. `PhotoLikeService.fetchPhotos()` only queries Supabase. The local `WalkPhoto` objects on the `WalkRecord` are never consulted.

**Bug B — Supabase-uploaded photos also invisible:**
Even when the Supabase upload succeeds, photos still don't appear. The `PhotoInsert` struct in `PhotoLikeService.swift` (around line 174) does NOT include an `is_public` field. The database schema defaults `is_public` to `false`. Meanwhile, `fetchPhotos()` filters with `.eq("is_public", value: true)`. Result: photo uploads succeed but the fetch query excludes them.

**Fix for Bug B:** Add `is_public: Bool` to the `PhotoInsert` struct and set it to `true` when inserting. This is a one-line struct change plus one field in the insert payload.

### Fix Approach

**Option A (recommended): Merge local + remote in StairwayBottomSheet**

1. In `StairwayBottomSheet`, after `photoLikeService.fetchPhotos()` completes, also read `walkRecord?.photoArray`.
2. Build a merged photo list. Create a lightweight wrapper type (or extend `PhotoCarousel` to accept a union type) that can represent either a `SupabasePhoto` (with URL-based loading) or a `WalkPhoto` (with `Data`-based loading).
3. Deduplicate: if a local `WalkPhoto` was successfully uploaded, the Supabase version has a matching `storage_path`. Since we don't currently store the Supabase photo ID on the local `WalkPhoto`, dedup by checking if the local photo's `createdAt` closely matches a Supabase photo's `created_at` for the same stairway. Alternatively, after a successful upload, delete the local `WalkPhoto` from SwiftData (simplest dedup — local photos are transient until uploaded).
4. Pass the merged list to `PhotoCarousel`.

**Option B (simpler, short-term): Show local photos as fallback when Supabase is empty**

1. If `photoLikeService.photos` is empty but `walkRecord?.photoArray` is not empty, display local photos using `Image(uiImage:)` from `WalkPhoto.thumbnailImage` / `WalkPhoto.fullImage`.
2. This avoids the merge complexity but means local photos disappear once any Supabase photo exists.

**Recommendation:** Option A is more robust. But if the intent is that Supabase is always the source of truth for photos in the long run, Option B with a clear "upload pending" indicator may be sufficient for solo use.

### PhotoCarousel Changes

`PhotoCarousel` currently takes `[SupabasePhoto]`. It needs to also handle local photos. Two paths:

- **Protocol approach:** Define a `DisplayablePhoto` protocol with `thumbnailView` and `fullImageView` computed properties. Have both `SupabasePhoto` and `WalkPhoto` conform. `PhotoCarousel` takes `[any DisplayablePhoto]`.
- **Enum approach:** `enum PhotoSource { case remote(SupabasePhoto), local(WalkPhoto) }`. PhotoCarousel takes `[PhotoSource]` and switches on the case for rendering.

The enum approach is simpler and avoids protocol witness table overhead for a small list.

### addPhoto() Cleanup

The current `addPhoto()` in `StairwayBottomSheet` creates a local `WalkPhoto`, appends it to the record, saves to SwiftData, then uploads to Supabase asynchronously. On successful upload, the new `SupabasePhoto` is inserted into `photoLikeService.photos`. This means:

- If upload succeeds: the photo appears in the carousel (via Supabase path) but also exists locally (potential duplicate).
- If upload fails: the photo is saved locally but invisible.

After this fix, the photo should appear immediately in the carousel from local data, and the Supabase upload is a background sync. On success, the local copy can optionally be cleaned up (or kept as a cache).

## 6. Integration Points

- `StairwayBottomSheet.swift` — merge local + remote photos before passing to carousel.
- `PhotoCarousel.swift` — accept and render both photo sources.
- `PhotoViewer.swift` — if full-screen view is used, it also needs to handle local `WalkPhoto.fullImage`.
- `WalkPhoto.swift` — no changes needed (model is fine).
- `PhotoLikeService.swift` — fix `PhotoInsert` struct to include `is_public: true` (Bug B fix).

## 7. Constraints

- Local `WalkPhoto.imageData` uses `@Attribute(.externalStorage)`, so SwiftData stores it on disk (not in the SQLite row). Loading should be fast but test with multiple photos.
- Like counts and like toggles only apply to Supabase photos. Local-only photos should not show the like overlay.
- The camera picker and photo library picker flows are unaffected — they already call `addPhoto()` which writes to SwiftData.

## 8. Acceptance Criteria

- [ ] Add a photo to a stairway while NOT signed into Supabase. Close and reopen the bottom sheet. The photo appears in the carousel.
- [ ] Add a photo while signed into Supabase. The photo appears immediately (from local data) and remains visible after the Supabase upload completes (no duplicate).
- [ ] Kill and relaunch the app. Previously added local photos still appear.
- [ ] Local-only photos do not show like count/heart overlay.
- [ ] Full-screen photo viewer works for both local and remote photos.
- [ ] Feedback loop prompt has been run.

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift`
- `ios/SFStairways/Views/Detail/PhotoCarousel.swift`
- `ios/SFStairways/Services/PhotoLikeService.swift` (fix `PhotoInsert` to set `is_public = true`)
- `ios/SFStairways/Views/Detail/PhotoViewer.swift` (if full-screen view needs local support)
- Possibly a new `PhotoSource.swift` enum or similar lightweight type
