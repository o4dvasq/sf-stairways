SPEC: iOS Admin App — Field Data Maintenance | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

---

## 1. Objective

Create a separate iOS app for stairway data maintenance while in the field. Mirrors the macOS Admin Dashboard concept: a dedicated tool for correcting catalog data, managing tags, and removing bad entries. Single-stairway editing only (no bulk operations). Shares the same CloudKit container so all changes sync to the main iOS app and macOS dashboard automatically.

## 2. Scope

A new iOS target in the existing Xcode project with four capabilities:

**A. Stairway browser** — Searchable, filterable list of all 1,144 stairways with quick access to edit any entry.

**B. Delete stairways** — Remove stairways from the catalog (e.g., duplicates, non-existent stairs discovered in the field).

**C. Edit overrides** — Correct step counts, heights, and add/edit curator descriptions on-site.

**D. Tag management** — Assign/remove tags on individual stairways, create new tags, delete custom tags.

## 3. Business Rules

### A. Stairway Browser

- List all stairways from `StairwayStore` (loaded from `all_stairways.json`).
- Search by name or neighborhood (same logic as the main app's SearchPanel).
- Filter by: All / Walked / Unwalked / Has Override / Has Issues.
  - "Has Override" = stairway has a StairwayOverride record.
  - "Has Issues" = missing height (no catalog height AND no override), or missing coordinates.
- Each row shows: stairway name, neighborhood, walked status icon, override indicator (pencil icon if override exists), tag count badge.
- Tapping a row opens the detail/edit screen.
- Sort options: alphabetical (default), neighborhood, date walked.

### B. Delete Stairways

Deleting a stairway from the field means marking it as hidden/removed, NOT deleting it from the bundled JSON (which is read-only at runtime).

Implementation:
- Create a new SwiftData model `StairwayDeletion` with fields: `stairwayID` (String), `deletedAt` (Date), `reason` (String, optional).
- When a stairway is "deleted," insert a `StairwayDeletion` record. This syncs via CloudKit to all devices.
- `StairwayStore` filters out any stairway whose ID appears in the deletions table. This affects the main iOS app, macOS app, and admin app.
- The admin app shows a "Removed Stairways" section (accessible from settings or a filter) where deleted stairways can be reviewed and restored (by deleting the `StairwayDeletion` record).
- Delete requires confirmation: "Remove [stairway name]? This hides it from all devices. You can restore it later."
- Optional: reason field in the confirmation dialog (e.g., "Doesn't exist," "Duplicate of X," "Private property").

### C. Edit Overrides

The detail/edit screen for a single stairway shows:

**Read-only catalog data (reference):**
- Name, neighborhood, coordinates, height (ft), closed status, source URL
- Walk record summary if walked: date, steps, elevation, notes

**Editable override fields:**
- Verified Step Count (numeric input, integer)
- Verified Height (ft) (numeric input, decimal allowed)
- Curator Description (multiline text editor)

**Behavior:**
- If no `StairwayOverride` exists for this stairway, one is created on first edit.
- Save button persists changes. Cancel discards.
- Show "last updated" timestamp on the override if it exists.
- Clearing all override fields and saving should delete the StairwayOverride record (no empty overrides).

### D. Tag Management

**On the stairway detail screen:**
- Show current tags as removable pills/chips. Tap X to remove a tag assignment.
- "Add Tag" button opens a picker showing all available tags. Tapping a tag creates a TagAssignment.
- "Create Tag" option in the picker for making a new custom tag inline (same slug generation as macOS: lowercase, spaces to hyphens, alphanumeric+hyphen only, max 30 chars).

**Standalone tag manager (accessible from app settings or toolbar):**
- List all tags with assignment counts.
- Preset tags: read-only display with counts.
- Custom tags: rename (inline), delete with cascade confirmation ("Delete tag 'X'? This removes it from N stairways.").

## 4. Data Model / Schema Changes

**New model: `StairwayDeletion`**
```
@Model
class StairwayDeletion {
    @Attribute(.unique) var stairwayID: String
    var deletedAt: Date
    var reason: String?

    init(stairwayID: String, deletedAt: Date = Date(), reason: String? = nil) {
        self.stairwayID = stairwayID
        self.deletedAt = deletedAt
        self.reason = reason
    }
}
```

This model must be added to the SwiftData `ModelContainer` schema in ALL three targets (iOS main app, iOS admin app, macOS app) so CloudKit sync works correctly.

**Existing models used (no changes):**
- `StairwayOverride` — curator corrections
- `StairwayTag` — tag definitions
- `TagAssignment` — stairway-tag join
- `WalkRecord` — walk data (read-only in admin app)

## 5. UI / Interface

### App Structure

Single `NavigationStack` with a list as the root. No tab bar needed — this is a focused tool.

**Root: Stairway List**
- Navigation title: "Admin"
- Search bar at top (always visible)
- Filter chips below search: All | Walked | Unwalked | Has Override | Has Issues
- Toolbar trailing: sort menu (Name / Neighborhood / Date Walked)
- Toolbar leading: Tag Manager button (tag icon)
- List rows: name, neighborhood subtitle, status icons (walked checkmark, override pencil, tag count)

**Detail/Edit Screen (push navigation):**
- Sections:
  1. **Catalog Data** — read-only reference (name, neighborhood, height, coords, closed, source)
  2. **Walk Data** — read-only if walked (date, steps, elevation, notes preview)
  3. **Overrides** — editable fields (step count, height, description) with Save/Cancel
  4. **Tags** — current tags as chips with X, Add Tag button
  5. **Actions** — "Remove Stairway" destructive button at bottom

**Tag Manager Sheet:**
- Presented modally from toolbar button
- Same layout as macOS TagManagerSheet adapted to iOS: list of tags with counts, swipe-to-delete for custom tags, rename via tap, create button

**Removed Stairways Sheet:**
- Accessible from a button in the stairway list toolbar or from a filter
- Shows deleted stairways with name, deletion date, reason
- Swipe to restore (deletes the StairwayDeletion record)

### Visual Style

- Follow the main iOS app's color palette (brandAmber, forestGreen, walkedGreen).
- Dark mode support (same as main app).
- Standard iOS List/Form patterns — no custom map UI needed.
- App icon: same StairShape silhouette but on a different background color (suggest brandAmber or a darker tone) to visually distinguish from the main app on the home screen.

## 6. Integration Points

**Shared code with main iOS app:**
- All SwiftData models (`Models/*.swift`) — shared via Xcode file membership in both targets
- `StairwayStore.swift` — shared (loads catalog, provides search/filter)
- `AppColors.swift` — shared
- `SyncStatusManager.swift` — shared (CloudKit status display)

**Shared code with macOS app:**
- Same CloudKit container (`iCloud.com.o4dvasq.sfstairways`)
- Same SwiftData schema

**Changes to existing apps:**
- Main iOS app: `StairwayStore` must filter out deleted stairways (query `StairwayDeletion` table, exclude matching IDs). This affects map pins, list, search, and progress counts.
- macOS app: Same deletion filtering in `StairwayBrowser`.
- Both apps: Add `StairwayDeletion` to their `ModelContainer` schema.

## 7. Constraints

- Bundle ID: `com.o4dvasq.SFStairways.admin` (follows existing pattern)
- Same CloudKit container as main app and macOS app
- The admin app does NOT need: map view, photo management, active walk mode, HealthKit, Supabase auth, or curator social features
- Keep the app lightweight — it's a utility, not a consumer app
- `all_stairways.json` must be included in the admin target's bundle resources (same file, added to both targets)
- The `StairwayDeletion` model is the only new schema addition. It must be added to all three targets' model containers before any target is run, or CloudKit schema migration will fail.

## 8. Acceptance Criteria

### Stairway Browser
- [ ] All 1,144 stairways appear in the list
- [ ] Search filters by name and neighborhood
- [ ] Filter chips work (All / Walked / Unwalked / Has Override / Has Issues)
- [ ] Sort options work (Name / Neighborhood / Date Walked)
- [ ] Walked/override/tag indicators display correctly on rows

### Delete Stairways
- [ ] Tapping "Remove Stairway" shows confirmation dialog
- [ ] Optional reason field in confirmation
- [ ] Deleted stairway disappears from admin app list
- [ ] Deleted stairway disappears from main iOS app (map, list, search, progress)
- [ ] Deleted stairway disappears from macOS app
- [ ] "Removed Stairways" view shows deleted entries
- [ ] Restoring a stairway makes it reappear everywhere

### Edit Overrides
- [ ] Can set verified step count (integer)
- [ ] Can set verified height (decimal)
- [ ] Can write/edit curator description
- [ ] New StairwayOverride created if none exists
- [ ] Changes persist after app restart
- [ ] Changes sync to main iOS app and macOS app via CloudKit
- [ ] Clearing all fields and saving removes the override record

### Tag Management
- [ ] Current tags shown as removable chips on detail screen
- [ ] Can add existing tag via picker
- [ ] Can create new custom tag inline
- [ ] Tag Manager sheet shows all tags with counts
- [ ] Can rename custom tags
- [ ] Can delete custom tags with cascade confirmation
- [ ] Preset tags are read-only

### General
- [ ] App builds and runs as a separate iOS target
- [ ] App icon is visually distinct from the main app
- [ ] CloudKit sync works across all three apps
- [ ] StairwayDeletion model added to all three targets' ModelContainer schemas
- [ ] No regressions in main iOS app or macOS app
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

**New directory:**
- `ios/SFStairwaysAdmin/` — admin app source

**New files:**
- `ios/SFStairwaysAdmin/SFStairwaysAdminApp.swift` — app entry point + ModelContainer
- `ios/SFStairwaysAdmin/Views/AdminBrowser.swift` — root stairway list with search/filter/sort
- `ios/SFStairwaysAdmin/Views/AdminDetailView.swift` — detail/edit screen (catalog, walk data, overrides, tags, delete)
- `ios/SFStairwaysAdmin/Views/AdminTagManager.swift` — tag list/CRUD sheet
- `ios/SFStairwaysAdmin/Views/RemovedStairwaysView.swift` — deleted stairway review/restore
- `ios/SFStairwaysAdmin/SFStairwaysAdmin.entitlements` — iCloud + CloudKit entitlements
- `ios/SFStairwaysAdmin/Assets.xcassets/` — admin app icon

**New shared model:**
- `ios/SFStairways/Models/StairwayDeletion.swift` — new SwiftData model (shared across all targets)

**Modified files:**
- `ios/SFStairways/Models/StairwayStore.swift` — add deletion filtering (exclude stairways with StairwayDeletion records)
- `ios/SFStairways/SFStairwaysApp.swift` — add StairwayDeletion to ModelContainer schema
- `ios/SFStairwaysMac/SFStairwaysMacApp.swift` — add StairwayDeletion to ModelContainer schema
- `ios/SFStairways.xcodeproj/` — new iOS admin target, shared file memberships

**Xcode project configuration:**
- New target: "SFStairwaysAdmin" (iOS app)
- Bundle ID: `com.o4dvasq.SFStairways.admin`
- Shared files: Models/*.swift, StairwayStore.swift, AppColors.swift, SyncStatusManager.swift
- Bundle resources: all_stairways.json, tags_preset.json
- Capabilities: iCloud (CloudKit), Background Modes (Remote Notifications)
- CloudKit container: iCloud.com.o4dvasq.sfstairways (same as existing)
