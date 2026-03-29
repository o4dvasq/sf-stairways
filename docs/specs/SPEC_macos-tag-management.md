SPEC: macOS Tag Management, Table Sorting & App Icon | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

---

## 1. Objective

Three changes:

A. Move tag management (create, edit, assign, delete) exclusively to the macOS admin dashboard. iOS becomes read-only for tags (display + filter only, no editing).

B. Make all numeric columns in the macOS stairway table sortable.

C. Generate a macOS app icon using the white StairShape silhouette on brandOrange background.

## 2. Scope

**macOS additions:**
- Full tag CRUD via a new TagManagerSheet
- Enhanced tag assign/remove in detail panel and bulk operations
- Sidebar tag filter section
- All numeric table columns sortable
- App icon generation

**iOS removals:**
- Remove TagEditorSheet (tag creation and assignment UI)
- Remove all tag add/remove/create controls from StairwayBottomSheet
- Keep TagFilterSheet (filter stairways by tag, read-only)
- Keep tag display pills on StairwayBottomSheet (read-only, no X buttons)

## 3. Business Rules

### Tags (curator-only, macOS)

- Tags are a curator feature. All tag creation, editing, assignment, and deletion happens on macOS only.
- Tag names must be unique (case-insensitive). Reject duplicates at creation time.
- Tag ID generation: lowercase, spaces to hyphens, alphanumeric + hyphens only, max 30 characters (same logic currently in iOS TagEditorSheet, move to shared helper or replicate in macOS).
- Preset tags (isPreset == true) cannot be renamed or deleted.
- Deleting a custom tag also deletes all its TagAssignment records. Confirm with count of affected stairways.
- CloudKit deduplication: filter by unique tag ID before display (existing pattern).
- iOS displays tags via CloudKit sync but cannot modify them.

### Table Sorting

- All numeric columns in the macOS table support ascending/descending sort via column header click.
- Sortable columns: Height, Steps, Elev. Gain, Photos, Date Walked (plus existing Name sort).
- Nil/missing values sort to the bottom regardless of sort direction.

### App Icon

- White StairShape (3-step ascending silhouette) on solid brandOrange (#E8602C) background.
- Rounded corners per macOS icon conventions (continuous corner radius).
- Generate all required sizes: 16, 32, 128, 256, 512 at 1x and 2x scales.

## 4. Data Model / Schema Changes

None. StairwayTag and TagAssignment models already exist and are registered in both iOS and macOS SwiftData containers.

## 5. UI / Interface

### A. macOS: Tag Manager Sheet (new view: `TagManagerSheet.swift`)

Accessed via a new toolbar button in StairwayBrowser (tag.fill icon). Opens as .sheet.

Layout:
- Header: "Tag Manager" title with total tag count subtitle
- Two sections:

**Preset Tags section:**
- Read-only list of preset tags with assignment counts
- Each row: tag name (non-editable), pill showing "N stairways"
- No delete/rename controls

**Custom Tags section:**
- List of user-created tags with inline rename and delete
- Each row: editable text field for name, assignment count pill, delete button (trash icon)
- Rename: edit text field, press Return or blur to save. Validate uniqueness before saving.
- Delete: trash button with confirmation alert: "This tag is assigned to N stairways. Delete?"
- "New Tag" row at bottom: text field + "Add" button with ID generation logic

### B. macOS: Enhanced Detail Panel Tags Section

Current behavior: assigned tags with remove (x) buttons, "Add Tag" dropdown of unassigned tags.

Add:
- "Create & Assign" option at bottom of "Add Tag" menu. Selecting it shows an inline text field below the FlowLayout. Type name, press Return to create the tag and assign it in one step.

### C. macOS: Enhanced Bulk Operations Sheet

Current behavior: single tag picker dropdown + "Assign Tag" button.

Add:
- "Remove Tag" section: second picker showing only tags assigned to at least one selected stairway. Button: "Remove Tag from All Selected". Deletes matching TagAssignment records.
- "Create new tag..." option at bottom of the existing assign picker. Shows inline text field to create and immediately bulk-assign.

### D. macOS: Sidebar Tag Filter

New "Tags" section in the sidebar below "Neighborhoods":
- Lists tags that have at least one assignment, with count of assigned stairways
- Clicking a tag filters the table to stairways with that tag assigned
- Intersects with neighborhood filter (both active = show stairways matching both)
- Clicking the active tag again (or a "Clear" option) deselects the filter

### E. macOS: Table Column Sorting

Current state: only Name column is sortable (via KeyPathComparator).

Add sortable columns:
- Height (Double?) — sort by `heightFt` on StairwayRow
- Steps (Int?) — sort by `verifiedStepCount`, falling back to `hkStepCount`
- Elev. Gain (Double?) — sort by `elevationGain`
- Photos (Int) — sort by `photoCount`
- Date Walked (Date?) — sort by `dateWalked`

Nil values should sort to the bottom in both ascending and descending order. This likely requires custom comparators rather than simple KeyPathComparators, since Swift's default optional comparison puts nil first.

### F. macOS: Toolbar Addition

Add tag.fill toolbar button next to existing Data Hygiene button. Opens TagManagerSheet.

### G. iOS: Make Tags Read-Only

**Remove:**
- `TagEditorSheet.swift` — delete this file entirely (or leave dead code; prefer deletion)
- StairwayBottomSheet tag section: remove "Add Tag" button that opens TagEditorSheet
- StairwayBottomSheet tag pills: remove the tap-to-remove gesture / X button
- Any tag create/assign/remove functions in StairwayBottomSheet

**Keep:**
- `TagFilterSheet.swift` — no changes, continues to work as-is for filtering
- Tag filter button on MapTab (opens TagFilterSheet)
- Tag display pills on StairwayBottomSheet — show assigned tags as read-only pills (same visual style, just not interactive)

## 6. Integration Points

**macOS new files:**
- `ios/SFStairwaysMac/Views/TagManagerSheet.swift` — tag CRUD sheet
- `ios/SFStairwaysMac/Assets.xcassets/AppIcon.appiconset/*.png` — generated icons
- `scripts/generate_macos_icon.swift` (or .py) — one-time icon generator

**macOS modified files:**
- `ios/SFStairwaysMac/Views/StairwayBrowser.swift` — toolbar button, sidebar tags section, tag filter state, sortable columns
- `ios/SFStairwaysMac/Views/StairwayDetailPanel.swift` — inline create-and-assign in tags section
- `ios/SFStairwaysMac/Views/BulkOperationsSheet.swift` — remove tag operation, create-new-tag option

**iOS modified files:**
- `ios/SFStairways/Views/Detail/StairwayBottomSheet.swift` — remove tag editor trigger, make tag pills read-only
- `ios/SFStairways/Views/Detail/TagEditorSheet.swift` — delete this file

**macOS asset catalog:**
- `ios/SFStairwaysMac/Assets.xcassets/AppIcon.appiconset/Contents.json` — updated with image references

## 7. Constraints

- No UIKit in macOS target; use AppKit/SwiftUI only
- Follow existing code patterns: @Environment(\.modelContext), try? modelContext.save(), GroupBox sections
- Tag deduplication: always filter tags through Set<String> on tag.id before display
- Icon generation: use CoreGraphics (Swift script) or Python with Pillow to render StairShape geometry at all sizes. Output PNGs placed in asset catalog with proper Contents.json.
- iOS tag filter must continue working after TagEditorSheet removal (TagFilterSheet is independent)
- Nil-bottom sorting requires custom Comparable wrappers or manual sort logic

## 8. Acceptance Criteria

### macOS Tag Management
- [ ] TagManagerSheet opens from toolbar, displays all preset and custom tags with assignment counts
- [ ] Can create a new custom tag with proper ID generation and uniqueness validation
- [ ] Can rename a custom tag (name updates, ID stays the same)
- [ ] Can delete a custom tag with confirmation showing affected stairway count
- [ ] Preset tags are not editable or deletable
- [ ] Detail panel "Add Tag" menu includes "Create & Assign" inline option
- [ ] Bulk operations sheet supports removing a tag from all selected stairways
- [ ] Bulk operations sheet supports creating a new tag inline during bulk assign

### macOS Tag Filter
- [ ] Sidebar shows "Tags" section below Neighborhoods with assignment counts
- [ ] Clicking a tag filters the table to matching stairways
- [ ] Tag filter intersects with neighborhood filter
- [ ] Can clear tag filter by clicking active tag or clear button

### macOS Table Sorting
- [ ] Height, Steps, Elev. Gain, Photos, Date Walked columns are all sortable
- [ ] Clicking column header toggles ascending/descending
- [ ] Nil values sort to bottom in both directions

### iOS Read-Only Tags
- [ ] TagEditorSheet is removed
- [ ] StairwayBottomSheet shows assigned tags as read-only pills (no add/remove controls)
- [ ] TagFilterSheet still works for filtering on the map
- [ ] No regressions in tag display or filter behavior

### App Icon
- [ ] macOS app icon shows white StairShape on brandOrange background at all required sizes
- [ ] Icon appears correctly in Dock, Finder, and About window

### General
- [ ] Deleting a tag cascades to remove all its TagAssignment records
- [ ] CloudKit duplicate tags handled via ID-based deduplication
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

**New files:**
- `ios/SFStairwaysMac/Views/TagManagerSheet.swift`
- `ios/SFStairwaysMac/Assets.xcassets/AppIcon.appiconset/*.png`
- `scripts/generate_macos_icon.swift` (or `.py`)

**Modified files:**
- `ios/SFStairwaysMac/Views/StairwayBrowser.swift`
- `ios/SFStairwaysMac/Views/StairwayDetailPanel.swift`
- `ios/SFStairwaysMac/Views/BulkOperationsSheet.swift`
- `ios/SFStairwaysMac/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `ios/SFStairways/Views/Detail/StairwayBottomSheet.swift`

**Deleted files:**
- `ios/SFStairways/Views/Detail/TagEditorSheet.swift`
