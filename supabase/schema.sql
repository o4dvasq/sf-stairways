-- SF Stairways — Supabase Schema
-- Run this in Supabase Dashboard → SQL Editor → New Query
-- Covers: all tables from ARCHITECTURE_MULTI_USER.md + Curator & Social Layer spec
-- Date: 2026-03-27

-- ============================================================
-- 1. CORE TABLES (from ARCHITECTURE_MULTI_USER.md)
-- ============================================================

-- User profiles (extends Supabase Auth)
CREATE TABLE user_profiles (
  id              uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name    text,
  avatar_url      text,
  is_public       boolean NOT NULL DEFAULT false,
  hard_mode_enabled boolean NOT NULL DEFAULT false,
  is_curator      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Stairway catalog (382 SF stairways, admin-only writes)
CREATE TABLE stairway_catalog (
  id              text PRIMARY KEY,
  name            text NOT NULL,
  lat             double precision,
  lng             double precision,
  neighborhood    text,
  height_ft       double precision,
  closed          boolean NOT NULL DEFAULT false,
  geocode_source  text,
  source_url      text,
  metadata        jsonb,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Walk records (one per user per stairway)
CREATE TABLE walk_records (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stairway_id     text NOT NULL REFERENCES stairway_catalog(id),
  walked          boolean NOT NULL DEFAULT false,
  date_walked     date,
  notes           text,
  step_count      integer,
  hard_mode       boolean NOT NULL DEFAULT false,
  proximity_verified boolean,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, stairway_id)
);

-- Walk photos
CREATE TABLE walk_photos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  walk_record_id  uuid NOT NULL REFERENCES walk_records(id) ON DELETE CASCADE,
  storage_path    text NOT NULL,
  thumbnail_path  text,
  caption         text,
  taken_at        timestamptz,
  is_public       boolean NOT NULL DEFAULT true,
  like_count      integer NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. SOCIAL LAYER TABLES (from SPEC_curator-social-layer.md)
-- ============================================================

-- Curator commentary (one per stairway, Oscar as sole curator)
CREATE TABLE curator_commentary (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stairway_id     text NOT NULL REFERENCES stairway_catalog(id),
  curator_id      uuid NOT NULL REFERENCES auth.users(id),
  commentary      text NOT NULL,
  is_published    boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE(stairway_id)
);

-- Photo likes (one like per user per photo)
CREATE TABLE photo_likes (
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  photo_id        uuid NOT NULL REFERENCES walk_photos(id) ON DELETE CASCADE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, photo_id)
);

-- ============================================================
-- 3. INDEXES
-- ============================================================

CREATE INDEX idx_walk_records_user_id ON walk_records(user_id);
CREATE INDEX idx_walk_records_stairway_id ON walk_records(stairway_id);
CREATE INDEX idx_walk_photos_walk_record_id ON walk_photos(walk_record_id);
CREATE INDEX idx_walk_photos_user_id ON walk_photos(user_id);
CREATE INDEX idx_photo_likes_photo_id ON photo_likes(photo_id);
CREATE INDEX idx_curator_commentary_stairway_id ON curator_commentary(stairway_id);

-- ============================================================
-- 4. TRIGGERS
-- ============================================================

-- Auto-update updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER walk_records_updated_at
  BEFORE UPDATE ON walk_records
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER curator_commentary_updated_at
  BEFORE UPDATE ON curator_commentary
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Denormalized like count on walk_photos
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

-- Auto-create user_profiles row on new auth signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (id) VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 5. ROW LEVEL SECURITY
-- ============================================================

-- user_profiles
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own profile"
  ON user_profiles FOR ALL
  USING (auth.uid() = id);
CREATE POLICY "Public profiles are readable"
  ON user_profiles FOR SELECT
  USING (is_public = true);

-- stairway_catalog (read-only for authenticated users)
ALTER TABLE stairway_catalog ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Catalog is readable by all authenticated users"
  ON stairway_catalog FOR SELECT
  USING (auth.role() = 'authenticated');

-- walk_records (users own their rows)
ALTER TABLE walk_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users own their walk records"
  ON walk_records FOR ALL
  USING (auth.uid() = user_id);

-- walk_photos (users own theirs; public photos readable by all)
ALTER TABLE walk_photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users own their walk photos"
  ON walk_photos FOR ALL
  USING (auth.uid() = user_id);
CREATE POLICY "Public photos are readable"
  ON walk_photos FOR SELECT
  USING (is_public = true AND auth.role() = 'authenticated');

-- curator_commentary
ALTER TABLE curator_commentary ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Published commentary is readable"
  ON curator_commentary FOR SELECT
  USING (is_published = true AND auth.role() = 'authenticated');
CREATE POLICY "Curators can manage commentary"
  ON curator_commentary FOR ALL
  USING (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_curator = true)
  );

-- photo_likes
ALTER TABLE photo_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage their own likes"
  ON photo_likes FOR ALL
  USING (auth.uid() = user_id);
CREATE POLICY "Likes are readable"
  ON photo_likes FOR SELECT
  USING (auth.role() = 'authenticated');

-- ============================================================
-- 6. STORAGE BUCKET
-- ============================================================
-- Run this separately in Supabase Dashboard → Storage → Create Bucket
-- Bucket name: photos
-- Public: false (access controlled via RLS-style storage policies)
--
-- Then add a storage policy in Dashboard → Storage → Policies:
--   Name: "Users can upload their own photos"
--   Allowed operation: INSERT
--   Policy: (bucket_id = 'photos' AND auth.uid()::text = (storage.foldername(name))[1])
--
--   Name: "Anyone can view photos"
--   Allowed operation: SELECT
--   Policy: (bucket_id = 'photos')
