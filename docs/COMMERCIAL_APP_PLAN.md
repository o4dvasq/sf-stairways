# SF Stairways — Commercial App Planning Doc

**Date:** 2026-03-22
**Status:** Early planning
**Author:** Oscar Vasquez

---

## 1. Vision

Transform the current personal SF stairway tracking site (vanilla JS + Leaflet on GitHub Pages) into a commercial iOS/Android app where anyone can discover, track, photograph, rate, and share their San Francisco stairway walks.

## 2. Current State

The existing project is a single-user web app with no backend. All 382 SF stairways are mapped via Leaflet.js. A personal target list of 13 stairways (8 walked) is stored in a JSON file committed to GitHub. Photo uploads go to Cloudinary. The entire app lives in a single `index.html`.

What carries forward:

- **Stairway dataset** — `all_stairways.json` with 382 stairways, geocoded, is the reference table for the commercial app.
- **Map UX patterns** — marker colors, popup design, walk logging flow all translate directly.
- **Cloudinary integration pattern** — similar approach for photo storage at scale.

## 3. Business Model

- **$4.99 one-time purchase** on both App Store and Google Play.
- No ads. No subscriptions. No in-app purchases.
- Revenue is simple: unit sales. No recurring infrastructure to justify a subscription.

## 4. Core Features

### 4.1 Map & Discovery

- Interactive map showing all 382 SF stairways.
- Tap any stairway to see name, location, step count, neighborhood, and elevation data.
- "Learn More" links to external stairway websites (sfstairways.com, Atlas Obscura, blog posts, etc.) — no copied content, just outbound links.
- User-generated descriptions and reviews accumulate over time as organic content.
- Factual data (step count, cross streets, handrail presence, elevation gain) is freely usable and should be populated for all stairways.

### 4.2 Walk Logging — Easy Mode vs. Hard Mode

User selects their preferred mode in settings. Can switch anytime.

**Easy Mode:**
- Tap any stairway → "Mark as Walked" → enter date → done.
- Walked stairways show a **green circle** marker on the map.
- No location verification required.

**Hard Mode:**
- "Mark as Walked" button is only enabled when the user's GPS is within ~50–100 meters of the stairway.
- Walked stairways show a **gold star** marker on the map.
- Must handle GPS accuracy gracefully — SF's urban canyons can drift 30+ meters. Show a friendly message ("Get a little closer...") rather than a hard block.
- Hard mode walks carry more weight in the achievement system.

### 4.3 Photos

- Users can attach photos when logging a walk (or add them later).
- Photos are tied to the stairway, not just the user — anyone viewing that stairway can browse all user-submitted photos.
- Photo gallery per stairway, sorted by recency.
- Users can delete their own photos.

### 4.4 Ratings & Reviews

- 1–5 star rating per stairway, per user. Average displayed on the stairway detail page.
- Optional short text review alongside the rating.
- "Top review" surfaced on the stairway detail card.

### 4.5 Achievements & Social Sharing

- Badge system for milestones: 10 stairways walked, a full neighborhood completed, all 382 walked, etc.
- Hard mode badges are visually distinct from easy mode badges.
- Share-to-social generates a shareable card image (stairway photo + stats + badge) and uses the native share sheet (Instagram, Twitter/X, iMessage, etc.).
- Deep links back into the app so someone seeing a shared achievement can download it.

## 5. Technical Architecture

### 5.1 Frontend — React Native (Expo)

- React Native with Expo for iOS + Android from a single JS/TS codebase.
- React Native Maps (wraps Apple Maps on iOS, Google Maps on Android).
- Expo Location for GPS/geofencing (hard mode).
- Expo Image Picker for photo capture.
- Native share sheet via Expo Sharing.

Why not PWA: Apple's App Store policies make PWA distribution unreliable. A native wrapper via Expo gives full App Store access, push notifications, and proper GPS APIs.

### 5.2 Backend — Supabase

- **Auth:** Supabase Auth with Apple Sign-In (required for App Store) + Google Sign-In.
- **Database:** Postgres via Supabase. Tables: `stairways` (reference data), `walks` (user walk logs), `photos`, `ratings`, `users`, `achievements`.
- **File storage:** Supabase Storage for photos (replaces Cloudinary). Or keep Cloudinary if its free tier is sufficient.
- **API:** Supabase auto-generates a REST API from the Postgres schema. Row-level security (RLS) policies handle authorization — users can only edit their own walks, photos, and ratings.

Why Supabase: auth + Postgres + file storage + API in one package. Generous free tier. No custom backend code needed for the MVP.

### 5.3 Data Model (Simplified)

```
stairways
  id, name, latitude, longitude, step_count, neighborhood,
  cross_streets, elevation_gain, has_handrail, avg_rating,
  external_links (jsonb)

users
  id, display_name, auth_provider, mode_preference,
  created_at

walks
  id, user_id → users, stairway_id → stairways,
  walked_date, mode (easy|hard), created_at

photos
  id, user_id → users, stairway_id → stairways,
  storage_path, caption, created_at

ratings
  id, user_id → users, stairway_id → stairways,
  stars (1-5), review_text, created_at
  UNIQUE(user_id, stairway_id)

achievements
  id, user_id → users, achievement_type, earned_at,
  mode (easy|hard)
```

## 6. Content Strategy

### What NOT to do

- Do not copy descriptive text, curated lists, or photos from existing stairway websites. Their creative expression is copyrighted.
- Do not replicate someone's "Top 20 Stairways" ranking as a feature — the selection and arrangement of a curated list can be protectable.

### What's fine

- **Factual data** (step count, location, cross streets, elevation, handrail) is not copyrightable. Populate this for all 382 stairways.
- **Links to external content** — "Learn More" links to sfstairways.com, Atlas Obscura, blog posts, etc. This drives traffic to them, which most site owners welcome.
- **Original editorial content** — write your own one-sentence descriptions as you walk stairways. ("Steep 302-step climb through lush gardens with panoramic bay views.")
- **User-generated content** — reviews and descriptions from users are organic and entirely yours.
- **Organic "best of" lists** — your top-rated stairways emerge from user ratings, not from copying someone else's curation.

## 7. Content Moderation

Required because the app has user-generated photos and reviews visible to other users. Apple will reject the app without moderation tooling.

- **Automated NSFW detection** on photo upload (AWS Rekognition, Google Cloud Vision, or similar).
- **Report button** on every photo and review.
- **Review queue** — flagged content goes to a moderation queue for manual review.
- **User blocking** — ability to block another user's content from your view.
- Start simple: automated filter + report button. Scale moderation staffing only if user base grows significantly.

## 8. App Store Requirements

### Apple (iOS)

- Apple Developer Program: **$99/year**.
- **Sign in with Apple** is required if you offer any social login.
- **Privacy policy** and **terms of service** — must be hosted at a public URL.
- **Data deletion** — users must be able to request deletion of their account and all associated data (GDPR/CCPA compliance).
- **App Review** — expect 1–3 rounds of review. Common rejection reasons: missing moderation for UGC, unclear privacy policy, broken deep links.
- No IAP needed since it's a one-time paid app (Apple takes 30% of the $4.99, so you net ~$3.49 per sale).

### Google (Android)

- Google Play Developer account: **$25 one-time**.
- Similar privacy/data deletion requirements, but generally more relaxed review process.
- Google takes 15% on the first $1M in revenue (then 30%).

## 9. Cost Estimates

### Ongoing costs (monthly, at low-to-moderate scale)

| Item | Cost | Notes |
|------|------|-------|
| Apple Developer Program | $8.25/mo ($99/yr) | Required |
| Supabase (free tier) | $0 | Up to 50K monthly active users, 1GB storage |
| Supabase (Pro, if needed) | $25/mo | When you exceed free tier |
| Photo storage | ~$0 early on | Supabase includes 1GB free; Cloudinary free tier is 25K transformations/mo |
| NSFW detection API | ~$1–5/mo | Pay-per-image; negligible at low volume |
| **Total (early stage)** | **~$8–10/mo** | |

### Revenue math

At $4.99 per download (netting ~$3.49 after Apple's cut):

- 100 downloads → ~$349
- 1,000 downloads → ~$3,490
- 10,000 downloads → ~$34,900

Break-even on annual costs (~$120/year) requires about 35 downloads.

## 10. Phased Roadmap

### Phase 1 — MVP (8–12 weeks)

- Expo/React Native project setup.
- Supabase backend: auth, database, storage.
- Map with all 382 stairways.
- Walk logging (easy mode only).
- Photo upload and per-stairway gallery.
- 1–5 star ratings.
- Basic content moderation (automated + report button).
- App Store and Google Play submission.

### Phase 2 — Hard Mode + Social (4–6 weeks after launch)

- GPS-verified walk logging (hard mode).
- Star vs. circle marker distinction.
- Achievement/badge system.
- Social sharing with shareable card images.
- Deep links.

### Phase 3 — Community (ongoing)

- User reviews/descriptions.
- "Top review" surfacing.
- Neighborhood completion tracking.
- Leaderboards (optional — can be polarizing).
- Push notifications for nearby stairways (opt-in).

## 11. Open Questions

- **Expand beyond SF?** The data model supports any city, but the brand is "SF Stairways." Revisit after validating demand in SF.
- **Offline support?** Stairway data could be bundled in the app for offline use. Photos require connectivity. Worth considering for hikers in low-signal areas.
- **User profiles?** Public profiles showing walks/photos/achievements could drive engagement but add complexity and moderation surface area.
- **Walking routes?** Curated multi-stairway walking routes (e.g., "Telegraph Hill Loop") would be a compelling feature but require significant editorial effort.
