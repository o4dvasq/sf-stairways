SPEC: CloudKit Sync Fix | Project: sf-stairways | Date: 2026-03-23 | Status: Ready for implementation

---

## 1. Objective

Get CloudKit sync actually working on the iOS app. Currently the app creates a CloudKit-configured ModelContainer but silently falls back to local-only storage. Walk data and photos should sync across Oscar's devices via iCloud private database.

## 2. Scope

- Diagnose and fix the CloudKit fallback behavior
- Ensure WalkRecord and WalkPhoto models sync to iCloud private database
- Add visible sync status indicator so the user knows if sync is active
- Out of scope: multi-user / public database, web app sync, backend API

## 3. Business Rules

- All walk data (WalkRecord, WalkPhoto) syncs via CloudKit private database — only Oscar's iCloud account
- App must still work offline — local-first, sync when connectivity is available
- Photo data (marked `@Attribute(.externalStorage)`) syncs as CKAssets
- No data loss on sync conflicts — last-write-wins is acceptable for single user
- Seed data (SeedDataService) should only run once, not re-seed after sync brings data from another device

## 4. Data Model / Schema Changes

The existing SwiftData models (WalkRecord, WalkPhoto) are already CloudKit-compatible:
- All attributes have defaults
- No unique constraints
- Relationships are optional

No schema changes expected. However, verify:
- CloudKit schema has been deployed in CloudKit Dashboard (Development → Production)
- Record types `CD_WalkRecord` and `CD_WalkPhoto` exist with correct fields

## 5. UI / Interface

Add a minimal sync status indicator:
- Small cloud icon in the navigation bar or settings area
- States: synced (checkmark), syncing (animated), offline (slash), error (exclamation)
- Tapping the icon shows last sync time and any error details
- No other UI changes

## 6. Integration Points

- **CloudKit Dashboard** (developer.apple.com): Verify container `iCloud.com.o4dvasq.sfstairways` exists, schema is deployed, development environment is active
- **Xcode capabilities**: Confirm Background Modes → Remote Notifications is enabled (required for CloudKit push-based sync)
- **Entitlements**: Current entitlements file looks correct (aps-environment, icloud-container-identifiers, icloud-services)

## 7. Constraints

- iOS 17+ deployment target (already set)
- Must work on physical device — CloudKit sync does not work in Simulator for push notifications
- Xcode project lives at `~/Desktop/SFStairways/` — source files are in `ios/SFStairways/` in this repo but the .xcodeproj is not version-controlled
- Apple Developer account required for CloudKit (already set up)

## 8. Acceptance Criteria

- [ ] App launches without falling back to local-only storage (no "CloudKit failed" log message)
- [ ] Walk data created on one device appears on another device signed into the same iCloud account
- [ ] Photos sync across devices (may take longer due to CKAsset size)
- [ ] App works offline — can create/edit walks without connectivity, syncs when back online
- [ ] Sync status indicator shows current state
- [ ] SeedDataService does not duplicate data when sync brings records from another device
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/SFStairwaysApp.swift` — CloudKit container initialization, possibly add Background Modes
- `ios/SFStairways/Services/SeedDataService.swift` — Guard against re-seeding when sync delivers existing records
- `ios/SFStairways/Views/ContentView.swift` — Sync status indicator
- `ios/SFStairways/SFStairways.entitlements` — May need Background Modes entitlement
- Xcode project (not in repo): Enable Background Modes → Remote Notifications capability

### Debugging Checklist for Claude Code

Since CloudKit issues are often configuration rather than code:

1. Open CloudKit Dashboard → verify container exists and has Development schema
2. Check Xcode → Signing & Capabilities → iCloud is enabled with the correct container selected
3. Check Xcode → Signing & Capabilities → Background Modes → Remote Notifications is checked
4. Check Console.app / Xcode console for CloudKit-specific error messages during launch
5. Verify the device is signed into iCloud with an active account
6. Test on physical device, not Simulator
