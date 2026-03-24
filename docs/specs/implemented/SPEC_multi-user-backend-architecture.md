SPEC: Multi-User Backend Architecture | Project: sf-stairways | Date: 2026-03-23 | Status: Ready for implementation

---

## 1. Objective

Design and document the backend architecture that will support a multi-user iOS app distributed on the Apple App Store. This is an architecture spec — the deliverable is a detailed design document and scaffolding, not a full implementation. The goal is to make decisions now so that solo-user feature work doesn't create debt that has to be unwound later.

## 2. Scope

Decisions and scaffolding needed:

- **Backend choice**: CloudKit public database vs. third-party backend (Supabase, Firebase, custom API)
- **Authentication**: Sign in with Apple, iCloud implicit auth, or third-party auth
- **Data ownership model**: How user data is isolated, what's shared (the 382-stairway catalog), what's private (walk records, photos)
- **Photo storage at scale**: CKAssets vs. object storage (S3/Cloudflare R2) with signed URLs
- **Social features roadmap**: What multi-user features are planned (leaderboards, shared walks, public profiles) — even if not built now
- **API layer**: Whether the iOS app talks directly to CloudKit or goes through an API server
- **Cost model**: Rough estimate of per-user costs at 100 / 1,000 / 10,000 users

Out of scope: implementing the backend, App Store submission, UI redesign for multi-user

## 3. Business Rules

- Every user gets their own walk log — no one can see or edit another user's data unless explicitly shared
- The 382-stairway catalog is shared/read-only — sourced from all_stairways.json, updated by Oscar
- Oscar retains admin capability to update the catalog, moderate content, manage users
- Free tier must be viable — no backend that requires paid plans at low user counts
- Privacy policy and data handling must be App Store compliant

## 4. Data Model / Schema Changes

This spec should produce a proposed schema for multi-user. Starting point from current single-user models:

**Current (single-user, SwiftData/CloudKit private):**
- `WalkRecord`: stairwayID, walked, dateWalked, notes, stepCount, createdAt, updatedAt, photos[]
- `WalkPhoto`: imageData, thumbnailData, caption, takenAt, createdAt, walkRecord

**Needed for multi-user:**
- `User` entity (linked to Apple ID or auth provider)
- `WalkRecord` gains a `userID` foreign key
- `WalkPhoto` gains a `userID` foreign key
- `StairwayCatalog` becomes a shared/public dataset
- Consider: `UserProfile` for display name, avatar, privacy settings

The architecture doc should present the full proposed schema with relationships.

## 5. UI / Interface

No UI work in this spec. However, the architecture doc should note UI implications:
- Where "Sign in with Apple" would appear in the flow
- How the app handles the transition from local-only to authenticated
- Migration path: existing solo-user data → user-owned data after account creation

## 6. Integration Points

- **Apple Developer account**: App Store Connect, provisioning profiles, push notification certificates
- **CloudKit Dashboard** (if staying with CloudKit): Public database schema, subscription setup
- **Third-party backend** (if chosen): Account setup, SDK integration, hosting
- **Sign in with Apple**: Entitlement, capability, Apple ID credential handling
- **Photo CDN** (if moving off CKAssets): Cloudflare R2, AWS S3, or Cloudinary at scale

## 7. Constraints

- Must support iOS 17+ (current deployment target)
- Oscar is a solo developer — architecture should favor managed services over self-hosted infrastructure
- No monthly hosting costs at zero users — pay-as-you-go or generous free tiers preferred
- The web app (GitHub Pages) is a separate concern for now — multi-user does not need to include it initially
- Architecture must not break the solo-user experience while multi-user is being built

## 8. Acceptance Criteria

- [ ] Architecture decision document produced at `docs/ARCHITECTURE_MULTI_USER.md` covering: backend choice (with rationale and alternatives considered), auth strategy, data model, photo storage, cost estimates, and migration plan from single-user
- [ ] Proposed multi-user schema documented with entity relationships
- [ ] Migration path from current CloudKit private DB to multi-user architecture is described
- [ ] Cost model estimated for 100 / 1K / 10K users
- [ ] Decision on CloudKit public DB vs. third-party backend is made with clear rationale
- [ ] Solo-user workstream is not blocked — changes identified that should happen now vs. later
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `docs/ARCHITECTURE_MULTI_USER.md` — NEW, main deliverable
- `docs/DECISIONS.md` — New entries for backend choice, auth strategy, photo storage
- `docs/PROJECT_STATE.md` — Updated to reflect architecture decisions
- No source code changes expected from this spec (architecture/design only)

### Evaluation Framework for Backend Choice

| Criteria | CloudKit Public DB | Supabase | Firebase |
|---|---|---|---|
| Free tier | 10GB data, 100MB assets/day, 2M requests/day | 500MB DB, 1GB storage, 50K auth users | 1GB Firestore, 5GB storage, 50K auth |
| Auth | Implicit iCloud (no sign-in UI) or Sign in with Apple | Sign in with Apple + email/password + social | Sign in with Apple + email/password + social |
| Photo storage | CKAssets (counts against storage) | Supabase Storage (S3-backed) | Firebase Storage (GCS-backed) |
| Swift SDK | Native (CloudKit framework) | supabase-swift (community) | firebase-ios-sdk (Google) |
| Vendor lock-in | Apple ecosystem only | PostgreSQL, portable | Google ecosystem |
| Offline support | Built into CloudKit | Requires manual caching | Firestore has offline mode |
| Oscar's familiarity | Already using CloudKit (private) | New | New |
