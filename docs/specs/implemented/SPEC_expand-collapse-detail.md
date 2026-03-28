SPEC: Expand/Collapse Stairway Detail | Project: sf-stairways | Date: 2026-03-28 | Status: Ready for implementation

## 1. Objective

Replace the current two-view flow (bottom sheet → NavigationLink → full StairwayDetail with redundant mini-map) with a single expandable bottom sheet. Tapping a stairway pin opens a compact summary sheet; dragging or tapping "More" expands the same sheet to reveal full detail content. No separate view, no redundant map.

## 2. Scope

Consolidate `StairwayBottomSheet` and `StairwayDetail` into a single sheet with two presentation states: collapsed (summary) and expanded (full detail).

### Current Flow (remove)

1. Tap pin → `StairwayBottomSheet` appears at `.height(390)` detent
2. Sheet has "View details" NavigationLink → pushes `StairwayDetail`
3. `StairwayDetail` has its own mini-map, header, stats, walk status, curator section, notes, photos, source link
4. User sees the stairway pin on the map behind the sheet AND a mini-map inside the detail view — redundant

### New Flow

1. Tap pin → single sheet appears at `.height(390)` detent (collapsed state)
2. Collapsed state shows: header (name, neighborhood), stats row (height, photos), walk status card, action buttons (Save/Mark Walked/Unmark/Remove)
3. User can drag up to `.large` detent OR tap an expand affordance to see full content
4. Expanded state (`.large`) adds: curator commentary (published, for all users), notes section, photos section, curator editor (curator mode only), source link
5. No mini-map anywhere. The map is always visible behind the sheet at the collapsed detent.

### Implementation Approach

**Merge content into `StairwayBottomSheet`.** Move the following from `StairwayDetail` into `StairwayBottomSheet`:

- `notesSection` (with Add Note / Save / Cancel pattern)
- `PhotoCarousel` (Supabase photos)
- `CuratorCommentaryView` (published commentary, visible to all)
- `CuratorEditorView` (curator mode only)
- `curatorSection` (local StairwayOverride editor, curator mode only)
- Source link

**Remove or deprecate `StairwayDetail`.** Once all content lives in the bottom sheet, `StairwayDetail` is no longer needed. Either delete it or keep it as dead code for reference (developer preference).

**Remove the "View details" NavigationLink** from the bottom sheet. Replace with a subtle expand indicator or just rely on the drag-to-expand gesture.

**Sheet detents in `MapTab`:**

```swift
.presentationDetents([.height(390), .large])
.presentationDragIndicator(.visible)
.presentationBackgroundInteraction(.enabled(upThrough: .height(390)))
```

The `.large` detent gives nearly full-screen height while keeping the sheet dismissible. The drag indicator is already visible. `.presentationBackgroundInteraction(.enabled(upThrough: .height(390)))` allows map interaction only at the collapsed height.

**Content layout inside the sheet:**

```
[Collapsed — always visible at .height(390)]
  - Header: name, neighborhood, back arrow, camera button
  - Stats row: height, photos count
  - Walk status card (Mark as Walked / Walked with date)
  - Action buttons (Save/Unsave, Mark Walked, Unmark, Remove)

[Expanded — visible when dragged to .large]
  - Curator commentary (published, all users — bold italic quote style)
  - My Notes (Add Note button / saved note display / edit with Save/Cancel)
  - Photos (Supabase photo carousel + Add a photo)
  - Curator editor (curator mode only — commentary draft/publish)
  - Curator data section (StairwayOverride — curator mode only)
  - Source link (sfstairways.com)
```

**Data dependencies:** The expanded section needs the same `@Query`, `@Environment`, and `@State` properties currently on `StairwayDetail`: `walkRecords`, `overrides`, `authManager`, `curatorService`, `photoLikeService`, `notesText`, `editingNotes`, `editingDate`, curator fields. These will need to move into the bottom sheet or be passed in.

**Recommended approach:** Since the bottom sheet is presented as a `.sheet` from `MapTab`, it can access `@Environment` and `@Query` directly. Move the `@State` properties (notesText, editingNotes, editingDate, curator fields) into the sheet. The `CuratorService` and `PhotoLikeService` can be `@State` properties initialized with `.task { }` on appear, same as the current `StairwayDetail`.

### What to Remove from StairwayDetail

- The `detailMap` section (entire mini-map) — this is the redundant element
- The `header` section (duplicated from bottom sheet)
- The `statsRow` (duplicated from bottom sheet)
- The `NavigationStack` wrapper
- The toolbar with Save button and camera menu (these are already on the bottom sheet header)

Essentially, everything. The file can be deleted.

## 3. Business Rules

- Collapsed sheet shows enough to take action (save, mark walked, see status)
- Expanded sheet shows everything else (notes, photos, commentary, curator tools)
- Map remains interactive at the collapsed detent
- No navigation push — everything is in one sheet

## 4. Data Model / Schema Changes

None.

## 5. UI / Interface

- Single bottom sheet with two heights: ~390pt (collapsed) and large (expanded)
- Drag indicator visible for affordance
- Smooth expand/collapse via standard SwiftUI sheet detent gestures
- No mini-map, no NavigationLink, no navigation push

## 6. Integration Points

- `CuratorService` and `PhotoLikeService` fetch data on sheet appear (same as current)
- `@Query` for walkRecords and overrides (available in sheet via SwiftData environment)

## 7. Constraints

- iOS 17+ sheet presentation APIs
- Must preserve all existing functionality (notes save, photo capture, curator editing, walk toggle, date editing)
- The sheet's collapsed content must fit cleanly at 390pt height
- Performance: avoid loading photos/commentary until the user expands to `.large`

## 8. Acceptance Criteria

- [ ] Tapping a pin opens a single bottom sheet (no navigation push)
- [ ] Collapsed sheet shows header, stats, walk status, action buttons
- [ ] Dragging up to large reveals notes, photos, commentary, curator tools, source link
- [ ] No mini-map appears anywhere
- [ ] `StairwayDetail.swift` is removed or deprecated
- [ ] Notes persist correctly with Add Note / Save / Cancel flow
- [ ] Photos load and display in expanded state
- [ ] Curator commentary displays for all users in expanded state
- [ ] Curator editor works in expanded state (curator mode only)
- [ ] Map remains interactive at collapsed detent
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — major expansion, absorbs StairwayDetail content
- `ios/SFStairways/Views/Map/MapTab.swift` — remove NavigationLink, possibly adjust sheet detents
- `ios/SFStairways/Views/Detail/StairwayDetail.swift` — delete or deprecate
- `ios/SFStairways/Views/Detail/PhotoCarousel.swift` — no changes, just moved into bottom sheet
- `ios/SFStairways/Views/Detail/CuratorCommentaryView.swift` — no changes, just moved into bottom sheet
- `ios/SFStairways/Views/Detail/CuratorEditorView.swift` — no changes, just moved into bottom sheet
