SPEC: Curator Notes-to-Commentary Workflow | Project: sf-stairways | Date: 2026-03-28 | Status: Ready for implementation

## 1. Objective

Define the full workflow for how personal notes become published curator commentary visible to all users. Oscar (sole curator) writes personal notes on walked stairways, then selectively promotes them to published commentary that appears prominently on the stairway detail view for all users.

## 2. Scope

### User-Facing Experience

**For all users (including Oscar when NOT in curator mode):**

When viewing a stairway that has published curator commentary, they see a prominent commentary block at the top of the expanded detail section. The commentary is styled as a blockquote: bold italic text with a large opening quotation mark in forest green, on a subtle gray background. This is the `CuratorCommentaryView` that already exists.

The commentary appears above the user's own "My Notes" section, making it the first thing they see when expanding the sheet.

**For Oscar (curator mode active):**

1. **Write personal notes** on any walked stairway via the "My Notes" section (Add Note → type → Save). These are local/CloudKit `WalkRecord.notes`, private to Oscar.

2. **Promote to commentary.** When notes exist and curator mode is active, a "Promote to Commentary" button appears in the notes section header. Tapping it:
   - Opens the `CuratorEditorView` (already exists) pre-filled with the note text
   - Oscar can edit the text before publishing
   - "Save Draft" saves to Supabase `curator_commentary` as unpublished
   - "Publish" saves and sets `is_published = true`, making it visible to all users

3. **Edit commentary directly.** The `CuratorEditorView` also allows writing commentary from scratch without starting from notes. It shows draft/published status and allows toggling between published and unpublished.

### Current State (what exists)

The infrastructure is already built:

- **`CuratorCommentaryView`** — displays published commentary (bold italic blockquote). Works.
- **`CuratorEditorView`** — draft/publish editor with Supabase upsert. Works.
- **`CuratorService`** — fetches published (all users) or all (curator) commentary from Supabase. Has `upsert()` method. Works.
- **`curator_commentary` table** — Supabase table with `stairway_id`, `curator_id`, `commentary`, `is_published`. Exists with RLS policies.
- **"Promote Notes" button** in `CuratorEditorView` — copies `notesText` into the draft. Works.
- **"Promote to Commentary" button** in notes section header — triggers fetch of curator editor data. Exists but doesn't actually navigate to/show the editor.

### What Needs to Change

**1. Fix the "Promote to Commentary" flow in the notes section.**

Currently the button in `notesSection` fetches curator data but doesn't do anything visible. The `CuratorEditorView` is rendered separately in the `StairwayDetail` body (or will be in the bottom sheet after the expand/collapse spec is implemented). The promote button needs to:

- Scroll to or reveal the `CuratorEditorView` section
- Pre-fill the editor with the current notes text
- Give visual feedback that the notes have been copied to the editor

**Recommended approach:** Add a `@State private var showCuratorEditor: Bool = false` flag. The "Promote to Commentary" button sets `showCuratorEditor = true` AND sets a `promotedNotesText` value. The `CuratorEditorView` section is gated on `showCuratorEditor || (authManager.isCurator && curatorModeActive && service.commentary != nil)` — i.e., it shows either when the user explicitly promotes notes or when existing commentary exists to edit. The `promotedNotesText` is passed to the editor to pre-fill.

Actually, the simpler approach: the `CuratorEditorView` already has a "Promote Notes" button that copies `notesText` into the draft. The issue is just that the editor section isn't always visible. Make the `CuratorEditorView` always visible in the expanded sheet for curators in curator mode (it already is in `StairwayDetail`, just needs to carry over to the new bottom sheet per the expand/collapse spec). Then the "Promote to Commentary" button in the notes section can simply scroll to the editor section.

**2. Ensure commentary displays prominently in the expanded detail.**

In the expand/collapse spec, `CuratorCommentaryView` should be the FIRST item in the expanded content section, above "My Notes". This is already the case in the current `StairwayDetail` layout. Just ensure it carries over.

**3. Commentary styling.**

The current `CuratorCommentaryView` styling is good: opening quotation mark in forest green, italic medium-weight text, gray background, rounded corners. No changes needed to the styling.

**4. Notes section interaction with commentary.**

When a note has been promoted to commentary, the note itself remains in "My Notes" (it's a separate data store — local WalkRecord vs. Supabase curator_commentary). This is fine. The note is Oscar's personal record; the commentary is the published version. They can diverge.

## 3. Business Rules

- Personal notes are stored locally (WalkRecord.notes, CloudKit sync)
- Curator commentary is stored in Supabase (curator_commentary table)
- Only users with `is_curator = true` in `user_profiles` AND `curatorModeActive` AppStorage flag can see/use the editor
- Published commentary is visible to ALL authenticated users
- One commentary per stairway (UNIQUE constraint on stairway_id)
- Promoting notes to commentary copies the text; editing one does not affect the other
- Commentary can be published, unpublished (draft), or deleted

## 4. Data Model / Schema Changes

None. All tables and models already exist.

## 5. UI / Interface

**Commentary display (all users, expanded state):**
- Position: first item in expanded detail content, above "My Notes"
- Style: large forest-green opening quotation mark, bold italic subheadline text, gray background, rounded corners
- Hidden when no published commentary exists

**Notes section (all users, expanded state):**
- "My Notes" header with "Promote to Commentary" button (curator mode only, when notes exist)
- Add Note button when no notes → tap to open editor → Save / Cancel
- Display saved note text when notes exist → tap to edit

**Curator editor (curator mode only, expanded state):**
- Below notes section
- Text editor for commentary draft
- "Promote Notes" button (copies current notes into draft)
- "Save Draft" and "Publish" / "Unpublish" buttons
- Draft/Published status indicator

## 6. Integration Points

- Supabase `curator_commentary` table (read for all users, write for curators)
- `CuratorService.fetchPublished()` — called for non-curators
- `CuratorService.fetchForEditor()` — called for curators in curator mode
- `CuratorService.upsert()` — save/publish commentary
- Local `WalkRecord.notes` — personal notes (separate from commentary)

## 7. Constraints

- Curator editor must only be visible to users with `isCurator && curatorModeActive`
- Commentary text should not be empty when published (enforced in CuratorEditorView already)
- The promote flow should feel lightweight — tap, review, publish — not a multi-step wizard
- This spec depends on the expand/collapse detail spec for the bottom sheet layout

## 8. Acceptance Criteria

- [ ] Published curator commentary appears as a prominent blockquote at the top of the expanded detail
- [ ] Commentary is bold, italic, with a forest-green quotation mark
- [ ] Commentary is visible to all authenticated users (not just curators)
- [ ] "My Notes" section has Add Note / Save / Cancel flow that persists correctly
- [ ] "Promote to Commentary" button appears in notes header when curator mode is active and notes exist
- [ ] Tapping "Promote to Commentary" pre-fills the curator editor with the current note text
- [ ] Curator editor allows Save Draft and Publish/Unpublish
- [ ] Published commentary appears immediately for all users after publishing
- [ ] Notes and commentary are independent — editing one does not affect the other
- [ ] Curator editor is hidden when curator mode is off or user is not a curator
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — integrate commentary display, notes section, and curator editor into the expanded sheet (after expand/collapse spec)
- `ios/SFStairways/Views/Detail/CuratorCommentaryView.swift` — no changes expected (styling is correct)
- `ios/SFStairways/Views/Detail/CuratorEditorView.swift` — minor: ensure `notesText` pre-fill works when triggered from promote button
- `ios/SFStairways/Services/CuratorService.swift` — no changes expected

## Dependency

This spec should be implemented AFTER `SPEC_expand-collapse-detail.md`, since the expanded bottom sheet is where all this content lives.
