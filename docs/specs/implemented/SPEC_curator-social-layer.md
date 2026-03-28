SPEC: Curator & Social Layer | Project: sf-stairways | Date: 2026-03-27 | Status: Ready for implementation

---

## 1. Objective

Add a content and social engagement layer to the iOS app. Five features ship together as a cohesive set: curator commentary on stairways, user-submitted photos with a shared carousel, photo likes, user-level Hard Mode, and a private notes field with a curator promotion workflow. Oscar operates in a dedicated curator mode to populate canonical stairway content as he walks.

This spec depends on the Supabase backend being operational (project created, tables provisioned, `supabase-swift` integrated, Sign in with Apple working). See `docs/ARCHITECTURE_MULTI_USER.md` for backend prerequisites.

**Relationship to SPEC_curator-data.md:** The Curator Data spec (ships first, no Supabase dependency) introduces `StairwayOverride` with a local `description` field that Oscar populates during solo walks. When this Social Layer spec ships, `StairwayOverride.description` becomes a source for curator commentary promotion, alongside the existing `WalkRecord.notes`. The "Promote to Commentary" workflow (Section 3, rule 24) applies to both notes and description content. The Curator Data spec's `verifiedStepCount` and `verifiedHeightFt` fields migrate to `stairway_catalog.metadata` in Supabase as part of the multi-user transition.

---

## 2. Scope

**In scope:**

- Curator commentary model and UI (Supabase-backed, Oscar as sole curator)
- Curator mode: admin UI on StairwayDetail for writing/publishing commentary
- User photos: shared photo carousel on StairwayDetail with sort logic
- Photo likes: per-user binary toggle with like count display
- Hard Mode redesign: user-level global setting replacing the current per-stairway toggle
- Notes-to-commentary promotion workflow in curator mode
- New Supabase tables: `curator_commentary`, `photo_likes`
- Schema additions to existing tables: `walk_photos`, `user_profiles`, `walk_records`
- RLS policies for all new and modified tables

**Out of scope:**

- Automated content moderation (Oscar moderates manually via Supabase Dashboard for now)
- Public user profiles or leaderboards (future spec, see Social Features Roadmap in ARCHITECTURE_MULTI_USER.md)
- Photo comments or threads
- Push notifications for likes
- Web app support (deprecated)

---

## 3. Business Rules

### Curator Commentary

1. One commentary record per stairway. Oscar is the only curator. No multi-curator support needed.
2. Commentary has two states: draft (`is_published = false`) and published (`is_published = true`). Only published commentary is visible to regular users.
3. Commentary is tied to the stairway catalog, not to any user's walk record. It is canonical content, like step count or location.
4. Oscar accesses curator functionality through a curator mode toggle in Settings. Curator mode is gated by a `is_curator` flag on `user_profiles`. For launch, Oscar's account is the only one with `is_curator = true`, set manually in Supabase Dashboard.
5. When curator mode is active, StairwayDetail shows the curator editor section. When inactive (or for non-curator users), only published commentary is displayed.

### User Photos

6. Any authenticated user can submit photos for any stairway. Photos are tied to the user's walk record for that stairway. If no walk record exists, one is created with `walked = false` (same as current Save behavior).
7. Photos are public by default (`is_public = true`). Oscar can hide individual photos by setting `is_public = false` via Supabase Dashboard (manual moderation).
8. The photo carousel on StairwayDetail shows all public photos for that stairway across all users. Sort order: most recent first, except the photo with the highest like count is promoted to position two if it is not already the most recent.
9. Oscar's photos have no special data model treatment. They go through the same `walk_photos` table as any user submission.
10. Photos are uploaded to Supabase Storage at the path defined in ARCHITECTURE_MULTI_USER.md: `photos/{user_id}/{walk_record_id}/{photo_id}.jpg`. Thumbnails at `photos/{user_id}/{walk_record_id}/{photo_id}_thumb.jpg`.
11. Full images are compressed to max 2MB JPEG on-device before upload. Thumbnails are 400x400 JPEG, generated on-device.

### Photo Likes

12. Each user can like a photo once. Tap to like, tap again to unlike. Binary toggle, no counts beyond 0 or 1 per user per photo.
13. Like count is displayed on the photo in the carousel (small overlay, bottom-left corner). The count is a denormalized `like_count` integer on `walk_photos`, updated via a Supabase trigger or Edge Function when likes are inserted/deleted.
14. Liked state persists per user in the `photo_likes` table. The app fetches the user's liked photo IDs on carousel load to render the correct toggle state.
15. A user can like photos on stairways they have not walked. Liking does not require a walk record.

### Hard Mode (User-Level Redesign)

16. Hard Mode becomes a user-level boolean setting on `user_profiles`, replacing the current per-stairway toggle on `WalkRecord`. When enabled, ALL walk completions require proximity verification (150m radius, same as current).
17. The per-stairway `hardMode` and `proximityVerified` fields on `WalkRecord` (SwiftData) are deprecated. The Supabase `walk_records` table uses `hard_mode boolean DEFAULT false` and `proximity_verified boolean` to record the state at completion time. `hard_mode` is stamped `true` on the record if the user's global Hard Mode was active when they marked the stairway walked. `proximity_verified` is `true` if the user was within 150m at completion.
18. The existing per-stairway Hard Mode toggle is removed from StairwayBottomSheet and StairwayDetail. A single Hard Mode toggle is added to the Settings screen.
19. When Hard Mode is enabled globally, the Mark Walked button is disabled (opacity 0.4, non-tappable) on ALL stairways when the user is more than 150m away. Same proximity check logic as current implementation (`LocationManager.isWithinRadius`).
20. The unverified badge on map pins is removed. With user-level Hard Mode, there is no concept of "retroactively enabling Hard Mode on an already-walked stairway." Hard Mode applies only to future completions.
21. The Progress tab should display a "Hard Mode" indicator next to walk entries that were completed with hard mode active. A small lock icon next to the date is sufficient.
22. Save action remains unaffected by Hard Mode. Users can save/bookmark stairways regardless of proximity.

### Notes Field

23. The existing private notes field on `walk_records` is unchanged in behavior. Notes are per-user, per-stairway, private, and stored in Supabase (migrated from SwiftData).
24. In curator mode, the StairwayDetail gains "Promote to Commentary" actions on both the notes section and the Curator Data description field (from SPEC_curator-data). Either action copies the respective text into the curator commentary editor for that stairway, pre-filling it. Oscar then edits and publishes as a separate action. The original notes/description are not modified.
25. "Promote to Commentary" is a convenience workflow, not a data link. Once promoted, the commentary and source text are independent. Editing notes or the description does not update commentary and vice versa.

---

## 4. Data Model / Schema Changes

### New Supabase Tables

**`curator_commentary`**
```sql
CREATE TABLE curator_commentary (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stairway_id   text NOT NULL REFERENCES stairway_catalog(id),
  curator_id    uuid NOT NULL REFERENCES auth.users(id),
  commentary    text NOT NULL,
  is_published  boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(stairway_id)  -- one commentary per stairway
);
```

**`photo_likes`**
```sql
CREATE TABLE photo_likes (
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  photo_id      uuid NOT NULL REFERENCES walk_photos(id) ON DELETE CASCADE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, photo_id)
);
```

### Modified Supabase Tables

**`user_profiles` — add two columns:**
```sql
ALTER TABLE user_profiles ADD COLUMN hard_mode_enabled boolean NOT NULL DEFAULT false;
ALTER TABLE user_profiles ADD COLUMN is_curator boolean NOT NULL DEFAULT false;
```

**`walk_photos` — add two columns:**
```sql
ALTER TABLE walk_photos ADD COLUMN is_public boolean NOT NULL DEFAULT true;
ALTER TABLE walk_photos ADD COLUMN like_count integer NOT NULL DEFAULT 0;
```

**`walk_records` — add two columns:**
```sql
ALTER TABLE walk_records ADD COLUMN hard_mode boolean NOT NULL DEFAULT false;
ALTER TABLE walk_records ADD COLUMN proximity_verified boolean;
```

### Denormalized Like Count Trigger

```sql
CREATE OR REPLACE FUNCTION update_photo_like_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE walk_photos SET like_count = like_count + 1 WHERE id = NEW.photo_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE walk_photos SET like_count = like_count - 1 WHERE id = OLD.photo_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER photo_likes_count_trigger
  AFTER INSERT OR DELETE ON photo_likes
  FOR EACH ROW EXECUTE FUNCTION update_photo_like_count();
```

### RLS Policies

```sql
-- curator_commentary: published records readable by all authenticated users
ALTER TABLE curator_commentary ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Published commentary is readable"
  ON curator_commentary FOR SELECT
  USING (is_published = true AND auth.role() = 'authenticated');
CREATE POLICY "Curators can manage commentary"
  ON curator_commentary FOR ALL
  USING (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_curator = true)
  );

-- photo_likes: users own their likes; all authenticated can read (for count verification)
ALTER TABLE photo_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage their own likes"
  ON photo_likes FOR ALL
  USING (auth.uid() = user_id);
CREATE POLICY "Likes are readable"
  ON photo_likes FOR SELECT
  USING (auth.role() = 'authenticated');

-- walk_photos: public photos readable by all; owners manage their own
-- (update existing RLS — the current policy is owner-only)
CREATE POLICY "Public photos are readable"
  ON walk_photos FOR SELECT
  USING (is_public = true AND auth.role() = 'authenticated');
```

### SwiftData Changes (Transitional)

During the dual-write migration period (see ARCHITECTURE_MULTI_USER.md Section 7), the local SwiftData models need to coexist with Supabase. The following changes apply to local models:

**`WalkRecord.swift`** — deprecate per-stairway Hard Mode fields:
- `hardMode: Bool` — stop writing to this field. Read it only for backward compatibility with pre-migration data.
- `proximityVerified: Bool?` — same treatment.
- Add `hardModeAtCompletion: Bool = false` — stamped from user-level setting at walk completion time.
- Remove `showUnverifiedBadge` computed property (badge is removed per rule 20).

**No new SwiftData models for curator_commentary or photo_likes.** These are Supabase-only. The app reads them via the Supabase SDK, not SwiftData.

---

## 5. UI / Interface

### 5a. StairwayDetail — Curator Commentary Display (All Users)

Position: directly below the mini-map, above the header. Visible only when a published commentary record exists for this stairway.

```
┌─────────────────────────────────────┐
│         [Mini-Map 200pt]            │
├─────────────────────────────────────┤
│  "The 16th Avenue Tiled Steps are   │  ← curator commentary
│   best experienced at sunset when   │     italic, lightly bold,
│   the mosaic colors shift from      │     quoted style
│   warm golds to deep blues."        │
├─────────────────────────────────────┤
│  16th Avenue Tiled Steps            │  ← header (existing)
│  Golden Gate Heights                │
│  ...                                │
```

Styling:
- Font: `.subheadline`, italic, weight `.medium`
- Color: `.primary` (adapts to light/dark mode)
- Leading quotation mark rendered as a decorative element: large `"` in `.forestGreen` at 24pt, positioned top-left
- Padding: 16pt horizontal, 12pt vertical
- Background: `Color(.systemGray6)` with 10pt corner radius
- No attribution line (Oscar is the only curator; attribution adds clutter for a single voice)

### 5b. StairwayDetail — Curator Editor (Curator Mode Only)

When `user_profiles.is_curator == true` AND curator mode is active (stored as a local `@AppStorage` toggle), an editor section appears below the commentary display area (or in its place if no commentary exists yet).

```
┌─────────────────────────────────────┐
│  Curator Commentary           [Edit]│
│  ─────────────────────────────────  │
│  TextEditor (multiline)             │
│                                     │
│  ─────────────────────────────────  │
│  [Published ○]        [Save Draft]  │
│                    [Promote Notes ↑] │
└─────────────────────────────────────┘
```

- **Edit** button toggles between read and edit mode for the commentary text.
- **Published toggle**: switches `is_published`. When toggled on, the commentary immediately becomes visible to all users.
- **Save Draft**: writes commentary to Supabase with `is_published = false`.
- **Promote Notes**: copies the current notes text into the commentary TextEditor. Only visible when notes are non-empty. Does not modify the notes field.

### 5c. StairwayDetail — Photo Carousel (Replaces Current Photo Grid)

The current 3-column photo grid is replaced with a horizontally scrolling carousel showing all public photos for this stairway (across all users).

```
┌─────────────────────────────────────┐
│  Photos (12)                        │
│  ┌──────┐ ┌──────┐ ┌──────┐        │
│  │      │ │      │ │      │ ...    │
│  │ ♥ 5  │ │ ♥ 12 │ │ ♥ 3  │        │  ← like count overlay
│  └──────┘ └──────┘ └──────┘        │
│                              [+ Add]│
└─────────────────────────────────────┘
```

- Carousel: `ScrollView(.horizontal)` with `LazyHStack`. Each photo is a 120x120pt rounded rectangle (8pt corners) showing the thumbnail.
- Sort order: most recent (`created_at` desc), except the photo with the highest `like_count` is moved to position 2 if it is not already the most recent.
- Like count overlay: bottom-left of each photo, small pill with heart icon + count. Heart is filled (`.heart.fill`) if the current user has liked it, outline (`.heart`) if not.
- Tapping the like overlay toggles the like. Tapping the photo itself opens the full-screen PhotoViewer.
- The `[+ Add]` button at the end of the carousel opens the existing photo picker/camera flow.
- If no photos exist, show a single dashed-border placeholder tile with "Add a photo" prompt (similar to current empty state).

### 5d. Photo Like Interaction

- Tap the heart overlay on a carousel photo to toggle like/unlike.
- Optimistic UI: immediately flip the heart fill state and increment/decrement the count locally. Reconcile with server response.
- If the Supabase write fails, revert the local state and show a brief toast: "Couldn't save like."

### 5e. Settings Screen (New)

No Settings screen exists today. ContentView has three tabs: Map, List, Progress. Two options for adding Settings:

**Option A (recommended):** Add a gear icon button to the ProgressTab toolbar (left side, opposite the sync status icon). Tapping it presents a SettingsView as a sheet. This avoids adding a 4th tab and keeps the tab bar uncluttered.

**Option B:** Add a 4th "Settings" tab to ContentView's TabView. Feels heavy for the two toggles this spec introduces, but scales better if more settings are added later.

### 5e-1. Settings — Hard Mode Toggle

Remove the per-stairway Hard Mode toggle from StairwayBottomSheet and StairwayDetail. Add a single toggle to the new Settings screen.

```
┌─────────────────────────────────────┐
│  Settings                           │
│                                     │
│  🔒 Hard Mode              [Toggle] │
│  Require proximity (150m) to mark   │
│  stairways as walked                │
│                                     │
│  👤 Curator Mode            [Toggle] │  ← only visible if is_curator
│  Show curator tools on detail view  │
└─────────────────────────────────────┘
```

- Hard Mode toggle writes to `user_profiles.hard_mode_enabled` via Supabase.
- Also cached locally (`@AppStorage`) for offline access. Syncs on next app launch.
- When Hard Mode is active, Mark Walked is disabled on all stairways when user is >150m away. Same `LocationManager.isWithinRadius(150, ...)` check as the current implementation.

### 5f. Settings — Curator Mode Toggle

- Only visible when `user_profiles.is_curator == true`.
- Toggles curator tools on/off in StairwayDetail.
- Stored locally via `@AppStorage("curatorModeActive")`. Not synced to Supabase (it's a UI preference, not a data setting).

### 5g. ProgressTab — Hard Mode Indicator

In the "Recent walks" section, walk entries completed with `hard_mode = true` display a small lock icon (SF Symbol `lock.fill`, 10pt, `.forestGreen`) to the left of the date.

```
  ✓  Vulcan Stairway          🔒 Mar 27
     Noe Valley
```

No other changes to ProgressTab.

### 5h. Map Pins — Remove Unverified Badge

Remove the amber exclamation badge from `TeardropPin`. The `showUnverifiedBadge` property and its rendering code are deleted. `StairwayAnnotation` no longer passes this value. The concept of "unverified walk" does not exist in the user-level Hard Mode model.

---

## 6. Integration Points

### Supabase SDK Calls (New)

| Operation | Table | Method |
|---|---|---|
| Fetch published commentary for a stairway | `curator_commentary` | `SELECT ... WHERE stairway_id = X AND is_published = true` |
| Upsert commentary (curator) | `curator_commentary` | `UPSERT` on `stairway_id` |
| Fetch public photos for a stairway | `walk_photos` | `SELECT ... WHERE stairway_id via walk_records JOIN AND is_public = true ORDER BY created_at DESC` |
| Fetch user's liked photo IDs | `photo_likes` | `SELECT photo_id WHERE user_id = auth.uid()` |
| Toggle like | `photo_likes` | `INSERT` or `DELETE` |
| Read Hard Mode setting | `user_profiles` | `SELECT hard_mode_enabled WHERE id = auth.uid()` |
| Write Hard Mode setting | `user_profiles` | `UPDATE hard_mode_enabled` |
| Upload photo | Supabase Storage | `upload(path, fileData)` |

### Photo Query (Carousel Sort)

The carousel needs all public photos for a stairway, sorted by `created_at DESC`, with the most-liked photo promoted to position 2. Two approaches:

**Option A (recommended): fetch + client-side sort.** Query all public photos for the stairway ordered by `created_at DESC`. On the client, find the photo with max `like_count`, and if it's not at index 0, move it to index 1. Simple, no complex SQL.

**Option B: server-side.** A Supabase Edge Function or PostgreSQL function that returns photos in the correct order. Overkill for the expected photo volume per stairway (<50 photos).

---

## 7. Constraints

- **Supabase backend must be operational.** This spec cannot be implemented until: Supabase project created, tables provisioned (including new ones from this spec), `supabase-swift` integrated, and Sign in with Apple auth flow working.
- **Hard Mode redesign is a breaking change.** The per-stairway `hardMode` field on existing WalkRecords becomes meaningless. During migration (ARCHITECTURE_MULTI_USER.md Section 7), existing records with `hardMode = true` should be migrated as `hard_mode = true` on the `walk_records` row, but the behavior changes from per-stairway to user-level.
- **No offline curator editing.** Curator commentary reads/writes go through Supabase. If offline, curator tools are disabled with a "Requires connection" message. Regular user features (walk logging, notes) continue to work offline via local cache.
- **Photo carousel loads from network.** Thumbnails are fetched from Supabase Storage on carousel render. Implement lazy loading with placeholder shimmer. Cache thumbnails locally after first fetch.
- **Like count is eventually consistent.** The denormalized `like_count` on `walk_photos` is updated by a database trigger. In rare race conditions, the displayed count may lag by one. This is acceptable.
- **Curator mode is Oscar-only at launch.** `is_curator` is set manually in Supabase Dashboard. No in-app admin panel for managing curator permissions.
- **iOS 17+ deployment target unchanged.**
- **No third-party packages beyond `supabase-swift`** (already decided in ARCHITECTURE_MULTI_USER.md).

---

## 8. Acceptance Criteria

### Curator Commentary
- [ ] `curator_commentary` table exists in Supabase with correct schema and RLS
- [ ] Published commentary displays on StairwayDetail below the mini-map, styled italic/medium with decorative quote mark
- [ ] Commentary is hidden when no record exists or `is_published = false`
- [ ] Curator editor appears in StairwayDetail only when curator mode is active and user has `is_curator = true`
- [ ] Commentary can be saved as draft or published
- [ ] "Promote Notes" copies notes text into the commentary editor without modifying notes

### User Photos
- [ ] Photo carousel on StairwayDetail shows all public photos for the stairway across all users
- [ ] Photos sorted by most recent first, with most-liked photo at position 2 (if not already most recent)
- [ ] Users can submit photos for any stairway (creates walk record if needed)
- [ ] Photos upload to Supabase Storage at the correct path
- [ ] Thumbnails are generated on-device (400x400) and uploaded alongside full images
- [ ] Photos default to `is_public = true`

### Photo Likes
- [ ] `photo_likes` table exists with correct schema and RLS
- [ ] Like toggle works: tap to like, tap again to unlike
- [ ] Like count displays on each photo in the carousel
- [ ] Heart icon reflects current user's liked state (filled vs outline)
- [ ] Optimistic UI updates immediately, reverts on failure
- [ ] `like_count` on `walk_photos` is updated by database trigger

### Hard Mode (User-Level)
- [ ] Per-stairway Hard Mode toggle removed from StairwayBottomSheet and StairwayDetail
- [ ] Single Hard Mode toggle in Settings writes to `user_profiles.hard_mode_enabled`
- [ ] When enabled, Mark Walked is disabled on all stairways when user is >150m away
- [ ] Walk records completed with Hard Mode active have `hard_mode = true` and `proximity_verified = true`
- [ ] Save action is unaffected by Hard Mode
- [ ] Unverified badge removed from map pins
- [ ] ProgressTab shows lock icon on hard-mode walk entries

### Notes
- [ ] Existing notes functionality unchanged
- [ ] "Promote to Commentary" action visible in curator mode when notes are non-empty
- [ ] Promotion pre-fills curator editor; notes remain unmodified

### General
- [ ] All new Supabase tables have RLS enabled with correct policies
- [ ] Curator mode toggle in Settings, visible only to curators
- [ ] App degrades gracefully when offline (curator tools disabled, photos show cached thumbnails, likes queue for retry)
- [ ] Feedback loop prompt has been run

---

## 9. Files Likely Touched

| File | Change |
|------|--------|
| **New Files** | |
| `Services/SupabaseManager.swift` | Supabase client singleton (if not already created by backend setup spec) |
| `Services/CuratorService.swift` | Fetch/upsert curator commentary via Supabase |
| `Services/PhotoLikeService.swift` | Like toggle, fetch user's liked IDs, optimistic update logic |
| `Views/Detail/CuratorCommentaryView.swift` | Published commentary display (all users) |
| `Views/Detail/CuratorEditorView.swift` | Curator mode editor (draft/publish, promote notes) |
| `Views/Detail/PhotoCarousel.swift` | Horizontal scrolling carousel with like overlays |
| `Views/Settings/SettingsView.swift` | Hard Mode toggle, Curator Mode toggle (new screen or section) |
| **Modified Files** | |
| `Views/Detail/StairwayDetail.swift` | Insert CuratorCommentaryView below map, replace photo grid with PhotoCarousel, remove per-stairway Hard Mode section, add "Promote to Commentary" action in curator mode |
| `Views/Map/StairwayBottomSheet.swift` | Remove Hard Mode toggle row and related binding/callback |
| `Views/Map/MapTab.swift` | Remove `onToggleHardMode` callback |
| `Views/Map/TeardropPin.swift` | Remove `showUnverifiedBadge` property and badge rendering code |
| `Views/Map/StairwayAnnotation.swift` | Remove `showUnverifiedBadge` passthrough |
| `Views/Progress/ProgressTab.swift` | Add lock icon to recent walks with `hard_mode = true` |
| `Models/WalkRecord.swift` | Deprecate `hardMode` and `proximityVerified` fields; remove `showUnverifiedBadge` computed property |
| `Models/WalkPhoto.swift` | Add `likeCount`, `isPublic` fields (for local cache during dual-write period) |
| `Resources/AppColors.swift` | Verify `accentAmber` removal (no longer needed for unverified badge) |
| `Views/ContentView.swift` | Add Settings tab or navigation to SettingsView |
| **Supabase (SQL)** | |
| Migration SQL | `CREATE TABLE curator_commentary`, `CREATE TABLE photo_likes`, `ALTER TABLE` additions, trigger function, RLS policies |
