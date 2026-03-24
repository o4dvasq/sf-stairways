# Multi-User Backend Architecture — sf-stairways

_Date: 2026-03-23 | Status: Decided_

---

## 1. Decision Summary

| Area | Decision |
|---|---|
| Backend | **Supabase** (PostgreSQL + Auth + Storage) |
| Authentication | **Sign in with Apple** via Supabase |
| Photo storage | **Supabase Storage** initially → Cloudflare R2 if volume demands |
| API layer | iOS app talks **directly to Supabase** — no custom server |
| Data isolation | **Row Level Security** — users can only read/write their own rows |

---

## 2. Backend Choice: Supabase

### Decision: Supabase

### Why not CloudKit Public DB

CloudKit public database was the obvious first choice since the app already uses CloudKit private containers. It was rejected for these reasons:

- **iCloud account required.** Users must be signed into iCloud to use CloudKit. This creates a non-trivial drop-off for potential App Store users who haven't set up iCloud or disabled it.
- **Weak per-user isolation.** CloudKit public DB can filter by `creatorUserRecordID` but doesn't have a real access control layer. Row Level Security in PostgreSQL is more expressive and easier to audit.
- **No server-side logic.** CloudKit has no equivalent of Supabase Edge Functions. Any future business logic (leaderboard aggregation, content moderation) would require a separate API server.
- **Schema changes are painful.** CloudKit Dashboard schema management is clunky and migrations are manual.
- **Vendor lock-in within Apple.** All data is in Apple's ecosystem with no export path. PostgreSQL can be migrated anywhere.

### Why not Firebase

- Google ecosystem lock-in with no migration path
- Firestore's pricing model becomes unpredictable at scale (per-read billing)
- Firebase Auth + Sign in with Apple requires more ceremony than Supabase
- Oscar is not a Firebase user — learning cost with no clear advantage

### Why Supabase

- **PostgreSQL** — portable, familiar to any developer, full SQL query power
- **Row Level Security** — per-user data isolation is a first-class primitive, not an afterthought
- **Built-in auth** — Sign in with Apple + email/password handled natively, no separate auth service
- **Supabase Storage** — S3-compatible, included in free tier, sufficient for early-stage user counts
- **No iCloud requirement** — any Apple ID can sign in via Sign in with Apple regardless of iCloud setup
- **Free tier is sufficient for 0–100 users** — no hosting costs until meaningful traction
- **supabase-swift SDK** — actively maintained, good community, works on iOS 17+
- **Edge Functions** — Deno-based, available when custom server logic is needed
- **Oscar's existing comfort** — already uses Cloudinary (CDN pattern), GitHub API (REST pattern) — Supabase fits the same mental model

---

## 3. Authentication Strategy

### Decision: Sign in with Apple via Supabase

**Why Sign in with Apple:**
- App Store guideline 4.8 requires Sign in with Apple whenever a third-party login is offered
- Users get privacy-protecting email relay — no real email exposed unless they choose
- No password to forget — one tap auth for iOS users
- Supabase has native Sign in with Apple support

**Auth flow:**
1. App presents "Sign in with Apple" button (ASAuthorizationAppleIDButton)
2. iOS handles the Apple credential flow, returns an identity token
3. App sends the identity token to Supabase Auth
4. Supabase validates the token with Apple's servers and creates/returns a session
5. App stores the Supabase session (JWT) and uses it for all subsequent API calls

**Fallback:**
- Email/password login available via Supabase for users who can't use Sign in with Apple (edge case)

**Guest / unauthenticated state:**
- App works in local-only mode before sign-in (current behavior preserved)
- On first launch, prompt to create account is optional — not a hard gate
- Data created locally before sign-in is migrated on first auth (see Section 7)

**UI implications:**
- "Sign in with Apple" button appears on an onboarding screen or in Settings
- App must handle the "not signed in" state gracefully — local data is still usable
- After sign-in, synced indicator appears (similar to current iCloud sync badge)

---

## 4. Data Model

### Entity Relationship

```
auth.users (Supabase Auth managed)
    │
    ├──► user_profiles (1:1)
    │
    └──► walk_records (1:many)
              │
              └──► walk_photos (1:many)

stairway_catalog (shared, read-only for users)
    │
    └──► walk_records (many:1 — each walk references a stairway)
```

### Schema

**`user_profiles`**
```sql
CREATE TABLE user_profiles (
  id            uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name  text,
  avatar_url    text,
  is_public     boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
```

**`stairway_catalog`**
```sql
CREATE TABLE stairway_catalog (
  id            text PRIMARY KEY,           -- e.g. "16th-avenue-tiled-steps"
  name          text NOT NULL,
  lat           double precision,
  lng           double precision,
  neighborhood  text,
  metadata      jsonb,                       -- steps, description, surface, etc.
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
```
Seeded from `data/all_stairways.json`. Admin-only writes.

**`walk_records`**
```sql
CREATE TABLE walk_records (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stairway_id   text NOT NULL REFERENCES stairway_catalog(id),
  walked        boolean NOT NULL DEFAULT false,
  date_walked   date,
  notes         text,
  step_count    integer,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, stairway_id)              -- one record per user per stairway
);
```

**`walk_photos`**
```sql
CREATE TABLE walk_photos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  walk_record_id  uuid NOT NULL REFERENCES walk_records(id) ON DELETE CASCADE,
  storage_path    text NOT NULL,            -- Supabase Storage object path
  thumbnail_path  text,
  caption         text,
  taken_at        timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);
```

### Row Level Security Policies

```sql
-- user_profiles: read own always; read others only if is_public
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own profile"
  ON user_profiles FOR ALL USING (auth.uid() = id);
CREATE POLICY "Public profiles are readable"
  ON user_profiles FOR SELECT USING (is_public = true);

-- stairway_catalog: read-only for authenticated users
ALTER TABLE stairway_catalog ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Catalog is readable by all authenticated users"
  ON stairway_catalog FOR SELECT USING (auth.role() = 'authenticated');

-- walk_records: users own their rows
ALTER TABLE walk_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users own their walk records"
  ON walk_records FOR ALL USING (auth.uid() = user_id);

-- walk_photos: users own their photos
ALTER TABLE walk_photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users own their walk photos"
  ON walk_photos FOR ALL USING (auth.uid() = user_id);
```

Oscar's admin access is via the Supabase Dashboard (service role key bypasses RLS) — no separate admin role needed until moderation features are built.

---

## 5. Photo Storage

### Decision: Supabase Storage → Cloudflare R2 if needed

**Phase 1 (0–1K users): Supabase Storage**
- Included in free tier (1GB), Pro tier adds more
- S3-compatible API — migration to R2 is a storage path swap, not a schema change
- Photos stored at path: `photos/{user_id}/{walk_record_id}/{photo_id}.jpg`
- Thumbnails at: `photos/{user_id}/{walk_record_id}/{photo_id}_thumb.jpg`
- RLS-style access via Supabase Storage policies (same `auth.uid()` pattern)

**Phase 2 (1K+ users or >50GB photos): Cloudflare R2**
- Zero egress costs — critical for photo-heavy apps (S3 charges per GB downloaded)
- $0.015/GB storage, free egress
- S3-compatible: the iOS SDK call changes only the bucket URL, not the logic
- Trigger: if monthly Supabase Storage bill exceeds $10, migrate to R2

**Photo sizing:**
- Full image: compress to max 2MB JPEG before upload (iOS PhotoKit handles this)
- Thumbnail: 400×400 JPEG, ~50KB, generated on-device before upload

---

## 6. Social Features Roadmap

These are not in scope for the current build — documented here to ensure the schema and architecture don't preclude them.

| Phase | Feature | Prerequisite |
|---|---|---|
| 1 (now) | Private walk logs per user | This spec |
| 2 | Optional public profiles with walk counts | user_profiles.is_public |
| 3 | Per-stairway leaderboard (who's walked the most) | walk_records aggregation query |
| 4 | Neighborhood completion badges | walk_records + stairway_catalog.neighborhood |
| 5 | Community photo feed (public stairway photos) | walk_photos + public flag |
| 6 | Shared walks (co-log a walk with a friend) | New walk_participants join table |

The current schema supports Phases 1–4 without changes. Phase 5 requires adding `is_public` to `walk_photos`. Phase 6 requires a new join table.

---

## 7. Migration: Single-User → Multi-User

### Current state
- SwiftData local storage + CloudKit private container (sync broken, effectively local-only)
- No user concept — all data belongs to the device

### Migration strategy

The migration is triggered by the user's first sign-in, not by an app update. The app continues to work locally until the user chooses to create an account.

**Step 1 — Add Supabase SDK (no behavior change)**
- Add `supabase-swift` as a Swift Package dependency
- Configure Supabase project URL and anon key in app config
- No UI changes, no data writes

**Step 2 — Auth gate (optional sign-in prompt)**
- Add "Sign in with Apple" to Settings screen
- On sign-in: create `auth.users` row + `user_profiles` row
- App now has a valid Supabase session

**Step 3 — One-time migration on first sign-in**
```
For each WalkRecord in SwiftData local store:
  1. Ensure stairway exists in stairway_catalog (upsert from bundled JSON)
  2. Insert walk_records row with user_id = auth.uid()
  3. For each WalkPhoto:
     a. Upload image data to Supabase Storage
     b. Insert walk_photos row with storage_path
  4. Mark local record as "synced" (add isSynced flag to SwiftData model)
```

**Step 4 — Dual-write period (optional)**
- During the migration window, write to both SwiftData and Supabase
- Once migration confirmed complete, SwiftData becomes a local cache only
- CloudKit private container is abandoned (the sync bug becomes irrelevant)

**Step 5 — Remove SwiftData/CloudKit (future cleanup)**
- Once Supabase is the source of truth, remove CloudKit capability and SwiftData models
- This is a future PR, not part of this spec

### Impact on solo-user workstream
- **CloudKit sync fix (SPEC_cloudkit-sync-fix)** — still worth doing. Fixing CloudKit sync improves the solo experience now. The migration in Step 4 will supersede it later, but don't delay solo UX work waiting for multi-user.
- The two specs are independent and non-blocking.

---

## 8. Cost Model

### Assumptions
- Average walk records per user: 50 (out of 382 stairways)
- Average photos per user: 20 photos × 1.5MB full + 50KB thumb ≈ 31MB/user
- DB row size: ~500 bytes per walk_record, ~200 bytes per walk_photo row

### Supabase Free Tier limits
- Database: 500MB
- Storage: 1GB
- Auth: 50,000 monthly active users
- Edge Functions: 500K invocations/month

| User count | DB size | Photo storage | Auth MAU | Monthly cost |
|---|---|---|---|---|
| 100 users | ~3MB | ~3GB | 100 | **$0** (storage: Supabase free 1GB → R2 free 10GB) |
| 1,000 users | ~30MB | ~31GB | 1,000 | **~$1–5** (R2: $0.015×31GB ≈ $0.47/mo; Supabase free tier for DB+auth) |
| 10,000 users | ~300MB | ~310GB | 10,000 | **~$20–30** (R2: ~$4.65/mo; Supabase Pro $25/mo for DB headroom) |

At 10,000 users the total backend cost is approximately **$25–30/month** — dominated by Supabase Pro for the database, with R2 handling photos cheaply due to zero egress fees.

### Comparison: CloudKit Public DB at the same scale
- CloudKit free tier: 10GB data, 100MB assets/day transferred, 2M requests/day
- At 10,000 users with active photo uploads: 100MB/day asset transfer limit would be hit quickly
- No dollar cost, but rate limiting is a hard constraint that CloudKit doesn't let you pay past without Apple Developer Enterprise tier

---

## 9. What to Do Now vs. Later

### Do now (doesn't block solo UX work)
- [ ] Create Supabase project (free, takes 2 minutes)
- [ ] Create tables and RLS policies (SQL above, run in Supabase Dashboard)
- [ ] Seed `stairway_catalog` from `data/all_stairways.json` (one-time script)
- [ ] Add `supabase-swift` to Xcode project as a Swift Package (no behavior change)
- [ ] Configure Supabase URL + anon key in app (environment variable or Info.plist)

### Do later (App Store track)
- [ ] Implement Sign in with Apple + Supabase auth flow
- [ ] Build one-time migration: local SwiftData → Supabase
- [ ] Wire up walk_records read/write to Supabase
- [ ] Wire up walk_photos upload/download to Supabase Storage
- [ ] Add "Sign in" to Settings UI
- [ ] Build user profile screen
- [ ] Remove CloudKit private container + SwiftData after migration confirmed

---

## 10. Integration Checklist

- [ ] Supabase project created at supabase.com (free tier)
- [ ] Tables created: `user_profiles`, `stairway_catalog`, `walk_records`, `walk_photos`
- [ ] RLS enabled on all tables
- [ ] `stairway_catalog` seeded from `data/all_stairways.json`
- [ ] Supabase Storage bucket created: `photos` (private, RLS enforced)
- [ ] `supabase-swift` added to Xcode project
- [ ] Supabase URL + anon key stored in `ios/SFStairways/Config/` (gitignored)
- [ ] Sign in with Apple entitlement added to Xcode project
- [ ] Sign in with Apple configured in Supabase Auth dashboard
