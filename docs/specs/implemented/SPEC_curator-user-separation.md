SPEC: Curator/User Feature Separation | Project: sf-stairways | Date: 2026-04-04 | Status: Ready for implementation

---

# 1. Objective

Separate curator-only features from regular user features in the main iOS app to prepare for beta launch. Curators manage catalog data (tags, overrides, deletions) via the Admin app and macOS dashboard. Regular users interact with the app as consumers: they mark stairways walked, add personal notes, contribute photos, and see community activity. This spec also introduces a lightweight community metrics layer (climb counts per stairway) to give users a sense of shared activity.

# 2. Scope

**In scope:**
- Remove "Add Tag" button from `StairwayBottomSheet`; display existing tags as read-only pills
- Confirm notes remain per-user (already true via CloudKit private database architecture)
- Keep photo contribution flow unchanged (shared via Supabase)
- Add community climb count display per stairway
- Add community climb count aggregates to `NeighborhoodDetail`

**Out of scope (future community thread):**
- Badges: "First to Climb" (first non-curator user to walk a stairway), "Neighborhood Pioneer" (first to complete all stairways in a neighborhood), "Completionist" (all 382 stairways), etc.
- Leaderboards or user profiles
- Social features (following, activity feeds)
- Tag suggestions from users (potential future feature where users propose tags for curator review)

# 3. Business Rules

1. **Tags are curator-managed.** Regular users cannot create, assign, or remove tags. Tags assigned by curators via Admin/macOS are visible to all users as read-only pills on the stairway detail sheet.
2. **Notes are per-user.** Each user's `WalkRecord.notes` is stored in their private CloudKit database. Notes are not shared with other users. Curator commentary (Supabase `curator_commentary` table) remains the shared, published layer.
3. **Photos are shared.** Any authenticated user can contribute photos. Photos uploaded to Supabase are visible to all users via the `mergedPhotos` flow. This is intentional — community photo contributions enrich the catalog.
4. **Community climb counts are anonymous aggregates.** The app displays how many distinct users have walked each stairway. Individual user identities are not exposed. Counts are fetched from Supabase and cached locally.
5. **Curator mode UI is unchanged.** The `CuratorEditorView`, "Promote to Commentary" button, and curator-specific controls remain gated behind `authManager.isCurator && curatorModeActive`. This spec does not modify curator flows.

# 4. Data Model / Schema Changes

## Supabase (new table)

**`stairway_walk_events`**

| Column | Type | Notes |
|--------|------|-------|
| `id` | `uuid` | PK, default `gen_random_uuid()` |
| `stairway_id` | `text` | NOT NULL, matches catalog stairway ID |
| `user_id` | `uuid` | NOT NULL, FK to `auth.users` |
| `walked_at` | `timestamptz` | NOT NULL, default `now()` |
| `removed_at` | `timestamptz` | NULL = active walk; non-null = user removed the walk |

- Unique constraint on `(stairway_id, user_id)` — one row per user per stairway.
- When a user marks walked: upsert with `walked_at = now()`, `removed_at = NULL`.
- When a user removes a walk: update `removed_at = now()` (soft delete, preserves history for future badge logic).
- RLS policy: users can insert/update their own rows only. All authenticated users can read aggregate counts.

**`stairway_climb_counts`** (Supabase view or materialized view)

```sql
CREATE VIEW stairway_climb_counts AS
SELECT stairway_id, COUNT(DISTINCT user_id) AS climber_count
FROM stairway_walk_events
WHERE removed_at IS NULL
GROUP BY stairway_id;
```

This gives efficient per-stairway counts without exposing individual user data.

## iOS (SwiftData) — no model changes

- `WalkRecord.notes` is already per-user via CloudKit private database. No migration needed.
- Tags remain as-is in SwiftData. Only the UI changes (hide Add Tag).

## iOS (Supabase integration) — new service

**`CommunityService.swift`** — new `@Observable` service

- `climbCounts: [String: Int]` — dictionary of `stairwayID → climber_count`, cached in memory
- `fetchClimbCounts()` — queries `stairway_climb_counts` view from Supabase; called on app launch and pull-to-refresh
- `reportWalk(stairwayID:)` — upserts into `stairway_walk_events` when user marks walked
- `reportUnwalk(stairwayID:)` — sets `removed_at` when user removes a walk
- `climberCount(for stairwayID: String) -> Int` — returns cached count (0 if not found)
- Injected via `.environment()` from `SFStairwaysApp`

# 5. UI / Interface

## StairwayBottomSheet changes

### Tags section (`tagsSection`)
- **Remove** the `Button { showTagEditor = true }` block (the "+ Add Tag" dashed button)
- **Keep** the `ForEach(stairwayTags)` loop that displays existing tag pills as read-only
- **Remove** the `showTagEditor` state variable and the `.sheet(isPresented: $showTagEditor)` presenting `TagEditorSheet`
- If a stairway has zero tags, the tags section is simply not shown (no empty state needed)

### Notes section (`notesSection`)
- **No functional change.** Users can still add and edit their own notes via "Add Note" / tap-to-edit.
- The curator "Promote to Commentary" button remains gated behind `authManager.isCurator && curatorModeActive`.

### Photos
- **No change.** "Add a photo" button and upload flow remain.

### Community climb count (new)
- Add a `climberCountBadge` view in the stairway info area (near the height stat, below the header).
- Display: `person.2.fill` icon + "N climbers" (or "1 climber" singular) in secondary text color.
- Only show when `climberCount > 0`.
- When the current user is the only climber, show "You're the first!" in a subtle highlight (brandOrange tint). This replaces the generic "1 climber" text and hints at the future badge system.
- Data source: `communityService.climberCount(for: stairway.id)`

### Mark Walked integration
- When `markWalked()` succeeds, also call `communityService.reportWalk(stairwayID:)` (fire-and-forget, non-blocking).
- When walk is removed (the existing remove-walk alert action), also call `communityService.reportUnwalk(stairwayID:)`.
- Both calls are guarded by `authManager.isAuthenticated`. Unauthenticated users (local-only mode) do not report to community counts.

## NeighborhoodDetail changes

- Add aggregate community stat: "N total climbers across M stairways" line below the progress bar (or near it).
- Computed by summing `climberCount` for all stairways in the neighborhood.
- Only shown when aggregate > 0.

## ProgressTab — no changes for beta

Community metrics on the progress tab (e.g., "You've climbed more stairways than X% of users") are deferred to the community features thread.

# 6. Integration Points

- **Supabase:** New `stairway_walk_events` table + `stairway_climb_counts` view. RLS policies. `CommunityService` queries and writes.
- **CloudKit:** No changes. WalkRecord continues syncing via private database.
- **Admin app / macOS dashboard:** No changes. Tag management remains exclusive to these targets.
- **AuthManager:** `CommunityService` reads `authManager.isAuthenticated` and `authManager.userId` to gate Supabase writes.

# 7. Constraints

- Community climb counts require Supabase authentication. Users in local-only mode (no Sign in with Apple) see no community data and do not contribute to counts.
- Counts are eventually consistent — there may be a brief delay between marking walked and seeing the updated count.
- The `stairway_walk_events` table must be seeded with the curator's existing walks (Oscar's 8 walked stairways) to avoid showing "0 climbers" on stairways the curator has walked. This can be a one-time migration script.
- No offline queue for walk event reporting in beta. If Supabase is unreachable when marking walked, the local SwiftData walk succeeds silently and the community count is not updated. A retry/sync mechanism is deferred.

# 8. Acceptance Criteria

- [ ] "+ Add Tag" button is not visible in `StairwayBottomSheet` for non-curator users
- [ ] Existing tags display as read-only pills on stairways that have them
- [ ] Stairways with no tags show no tags section (no empty state)
- [ ] "Add Note" and note editing work unchanged for all users
- [ ] Notes are confirmed per-user (not visible to other users via CloudKit)
- [ ] "Add a photo" button and photo upload flow work unchanged
- [ ] `stairway_walk_events` table exists in Supabase with proper RLS
- [ ] `stairway_climb_counts` view returns correct aggregates
- [ ] Climb count badge appears on `StairwayBottomSheet` when count > 0
- [ ] "You're the first!" displays when current user is sole climber
- [ ] `NeighborhoodDetail` shows aggregate community climb stat
- [ ] Marking walked fires `communityService.reportWalk()` for authenticated users
- [ ] Removing a walk fires `communityService.reportUnwalk()` for authenticated users
- [ ] Unauthenticated users see no community data and do not write to Supabase
- [ ] Admin app and macOS dashboard tag management is unaffected
- [ ] Curator mode features (CuratorEditorView, Promote to Commentary) are unaffected
- [ ] Feedback loop prompt has been run

# 9. Files Likely Touched

**iOS (modify):**
- `Views/StairwayBottomSheet.swift` — remove Add Tag button, add climb count badge, wire reportWalk/reportUnwalk
- `Views/Neighborhood/NeighborhoodDetail.swift` — add aggregate community stat

**iOS (new):**
- `Services/CommunityService.swift` — Supabase climb count queries and walk event reporting

**iOS (modify, minor):**
- `SFStairwaysApp.swift` — create and inject `CommunityService` into environment

**Supabase (new, manual):**
- SQL migration: `stairway_walk_events` table, `stairway_climb_counts` view, RLS policies
- Seed script: insert Oscar's existing 8 walks into `stairway_walk_events`

**No changes:**
- `TagEditorSheet.swift` — still exists for Admin/macOS use, just not presented from main app bottom sheet
- `Models/*.swift` — no SwiftData model changes
- `Services/AuthManager.swift` — no changes (already exposes `isAuthenticated`, `userId`, `isCurator`)
- Admin app views, macOS views — unchanged

---

## Future: Community Features (Separate Thread)

These items are explicitly deferred and noted here for continuity:

- **"First to Climb" badge** — awarded to the first non-curator user to walk a stairway. Requires `stairway_walk_events` ordered by `walked_at`. Display as a small badge icon on the stairway detail.
- **"Neighborhood Pioneer" badge** — first user to complete all stairways in a neighborhood. Requires cross-referencing walk events against the stairway catalog grouped by neighborhood.
- **"Completionist" badge** — first user to walk all 382 stairways.
- **User profile / badge showcase** — a profile view showing earned badges, walk count, neighborhoods completed.
- **Leaderboard** — opt-in ranking by walk count, neighborhood completion, etc.
- **Activity feed** — recent community walks, photo contributions, badge awards.
- **Tag suggestions** — users propose tags for curator review (queue in Supabase, approve via Admin).
