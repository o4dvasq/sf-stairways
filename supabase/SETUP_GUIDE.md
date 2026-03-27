# Supabase Setup Guide — SF Stairways

Follow these steps in order. Steps 1-4 are in the Supabase Dashboard. Step 5 is Apple Developer Portal. Step 6 configures them together.

---

## Step 1: Create the Supabase Project

1. Go to https://supabase.com and sign up / log in
2. Click **New Project**
3. Organization: create one (e.g., "o4dvasq") or use existing
4. Project name: `sf-stairways`
5. Database password: generate a strong one and save it in your password manager
6. Region: pick the closest to SF (West US or `us-west-1`)
7. Click **Create new project** — takes ~2 minutes to provision

Once ready, note these values from **Settings → API**:
- **Project URL**: `https://xxxxx.supabase.co`
- **anon (public) key**: `eyJhbGciOi...` (safe to embed in the app)
- **service_role key**: `eyJhbGciOi...` (NEVER embed in the app — admin only)

---

## Step 2: Run Schema SQL

1. Go to **SQL Editor** in the Supabase Dashboard
2. Click **New Query**
3. Paste the contents of `supabase/schema.sql` from the repo
4. Click **Run** — should complete with no errors
5. Verify in **Table Editor** that these tables exist:
   - `user_profiles`
   - `stairway_catalog`
   - `walk_records`
   - `walk_photos`
   - `curator_commentary`
   - `photo_likes`

---

## Step 3: Seed Stairway Catalog

1. Go to **SQL Editor** → **New Query**
2. Paste the contents of `supabase/seed_catalog.sql`
3. Click **Run** — inserts 382 rows
4. Verify in **Table Editor → stairway_catalog**: should show 382 rows
5. Spot check: search for "16th-avenue-tiled-steps" — should have lat/lng/neighborhood

---

## Step 4: Create Storage Bucket

1. Go to **Storage** in the Supabase Dashboard
2. Click **Create a new bucket**
3. Name: `photos`
4. Public bucket: **OFF** (we control access via policies)
5. Click **Create bucket**
6. Go to **Storage → Policies** for the `photos` bucket
7. Add these policies:

**Policy 1: Upload own photos**
- Name: `Users can upload their own photos`
- Allowed operation: INSERT
- Target roles: authenticated
- Policy definition (using SQL): `(bucket_id = 'photos' AND auth.uid()::text = (storage.foldername(name))[1])`

**Policy 2: View all photos**
- Name: `Anyone authenticated can view photos`
- Allowed operation: SELECT
- Target roles: authenticated
- Policy definition: `(bucket_id = 'photos')`

**Policy 3: Delete own photos**
- Name: `Users can delete their own photos`
- Allowed operation: DELETE
- Target roles: authenticated
- Policy definition: `(bucket_id = 'photos' AND auth.uid()::text = (storage.foldername(name))[1])`

---

## Step 5: Configure Sign in with Apple

### Apple Developer Portal

1. Go to https://developer.apple.com → **Certificates, Identifiers & Profiles**
2. Under **Identifiers**, find your App ID (`com.o4dvasq.SFStairways`)
3. Enable the **Sign in with Apple** capability if not already enabled
4. No `.p8` key needed for native iOS — Apple's `ASAuthorizationAppleIDProvider` handles the credential exchange on-device, and Supabase just validates the identity token

### Supabase Dashboard

1. Go to **Authentication → Providers**
2. Find **Apple** and toggle **Enable Sign in with Apple** to ON
3. Fill in:
   - **Client IDs**: `com.o4dvasq.SFStairways` (this is the Bundle ID field)
   - **Secret Key (for OAuth)**: leave empty — only needed for web-based Sign in with Apple, not native iOS
   - **Allow users without an email**: leave OFF
4. Ignore the "OAuth secret keys expire every 6 months" warning and the Callback URL — both are web-only
5. Click **Save**

---

## Step 6: Mark Oscar as Curator

After you sign in for the first time (once the iOS auth flow is implemented):

1. Go to **Authentication → Users** in Supabase Dashboard
2. Find your user row, copy the `id` (UUID)
3. Go to **SQL Editor** → New Query:
```sql
UPDATE user_profiles
SET is_curator = true, display_name = 'Oscar'
WHERE id = 'YOUR-UUID-HERE';
```
4. Run it. You now have curator privileges.

---

## Step 7: Verify Everything

Run this verification query in SQL Editor:

```sql
SELECT 'user_profiles' AS tbl, count(*) FROM user_profiles
UNION ALL SELECT 'stairway_catalog', count(*) FROM stairway_catalog
UNION ALL SELECT 'walk_records', count(*) FROM walk_records
UNION ALL SELECT 'walk_photos', count(*) FROM walk_photos
UNION ALL SELECT 'curator_commentary', count(*) FROM curator_commentary
UNION ALL SELECT 'photo_likes', count(*) FROM photo_likes;
```

Expected: stairway_catalog = 382, everything else = 0 (until the app starts writing data).

---

## Files Created

| File | Purpose |
|------|---------|
| `supabase/schema.sql` | All tables, indexes, triggers, RLS policies |
| `supabase/seed_catalog.sql` | 382-row INSERT for stairway_catalog |
| `supabase/SETUP_GUIDE.md` | This file |

## What's Next

After completing this setup, hand `docs/specs/SPEC_supabase-ios-integration.md` to Claude Code for the iOS-side implementation: adding `supabase-swift`, configuring the client, and implementing Sign in with Apple auth flow.
