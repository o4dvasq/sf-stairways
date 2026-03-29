SPEC: Photo Upload & Sync Fix | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

## 1. Objective

Photos taken in the app show a slashed-cloud icon indicating they haven't synced. Diagnose and fix the photo upload pipeline so photos reliably reach Supabase and the local fallback copies are cleaned up.

## 2. Current Architecture

Photos follow a dual-storage path (StairwayBottomSheet.swift, `addPhoto` function):

1. User takes/selects a photo
2. A local `WalkPhoto` is created in SwiftData immediately (offline-first)
3. An async Supabase upload is attempted via `PhotoLikeService.uploadPhoto()`
4. If upload succeeds, the local `WalkPhoto` is deleted (avoiding duplicates)
5. If upload fails, the local `WalkPhoto` stays as a fallback

The `PhotoCarousel` renders local photos with a cloud-slash badge (line ~59), indicating they're local-only and haven't been uploaded to Supabase.

The fact that photos are showing the cloud-slash icon means step 3 (Supabase upload) is failing silently and the local copies persist.

## 3. Investigation Needed

The implementation should diagnose why uploads are failing. Likely causes:

**A. Supabase auth session expired or missing**
- `PhotoLikeService.uploadPhoto()` requires an authenticated Supabase session
- If the user's session expired or was never established, uploads silently fail
- Check: is `AuthManager.session` valid when `uploadPhoto` is called?

**B. Supabase storage bucket permissions**
- The `photos/` bucket needs INSERT permission for authenticated users
- Check RLS policies on the bucket and the `walk_photos` table

**C. Walk record not synced to Supabase**
- Upload flow first upserts a walk_record to Supabase (PhotoLikeService lines 137-144), then fetches the server-side walk_record ID
- If the upsert fails (e.g., missing Supabase walk_records table, RLS issue), the entire upload chain fails
- The Supabase walk_record uses a different ID system than SwiftData's local WalkRecord

**D. Silent error swallowing**
- The catch block in `addPhoto` does nothing with the error
- No logging, no user feedback, no retry

## 4. Scope of Fix

**Phase 1: Diagnose and log (this spec)**
- Add error logging to the `addPhoto` catch block so upload failures are visible (at minimum, print to console)
- Add a visible indicator in the UI when a photo upload fails (e.g., red badge instead of cloud-slash)
- Check Supabase auth state before attempting upload; if not authenticated, skip upload and log why

**Phase 2: Retry mechanism**
- Add a retry queue for failed uploads
- On app foreground or network change, retry pending uploads
- Show upload progress/status somewhere accessible (Settings or the admin dashboard)

**Phase 3: Cleanup**
- After successful upload, verify the local WalkPhoto is deleted
- Add a one-time migration to retry uploading any existing local-only WalkPhotos

## 5. Business Rules

- Photos should always be saved locally first (offline-first is correct)
- Upload to Supabase should happen reliably when the user is authenticated and online
- The user should never lose a photo due to upload failure (local copy is the safety net)
- Upload failures should be visible, not silent

## 6. Data Model / Schema Changes

None for Phase 1. Phase 2 may add an `uploadStatus` field to WalkPhoto or a separate upload queue.

## 7. UI / Interface

**Phase 1 changes only:**
- Replace the generic cloud-slash badge with a more informative indicator:
  - Cloud-slash (gray) = not yet uploaded, pending
  - Cloud-slash (red/amber) = upload failed
- Add upload error details to console logs

## 8. Integration Points

- Supabase storage bucket (`photos/`)
- Supabase `walk_photos` table
- Supabase `walk_records` table (upserted during upload flow)
- Supabase auth session (via AuthManager)

## 9. Acceptance Criteria

**Phase 1:**
- Upload failures are logged to console with specific error messages
- Photo badge distinguishes between "pending upload" and "upload failed"
- Supabase auth state is checked before attempting upload
- If not authenticated, photo is saved locally with a clear log message (not a silent failure)

**Phase 2 (future):**
- Failed uploads are retried automatically
- Existing local-only photos are uploaded on next successful auth

- Feedback loop prompt has been run

## 10. Files Likely Touched

- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — addPhoto error handling
- `ios/SFStairways/Services/PhotoLikeService.swift` — upload error propagation
- `ios/SFStairways/Views/Detail/PhotoCarousel.swift` — badge indicator logic
- `ios/SFStairways/Services/AuthManager.swift` — auth state check helper
