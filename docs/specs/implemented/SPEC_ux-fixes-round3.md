SPEC: UX Fixes Round 3 — Green Readability, Notes Bug, Progress Enhancements, Stats Card, Search Tab, Map Label Cleanup | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

---

## 1. Objective

Fix several UX issues observed during real-world use: unreadable green text on dark backgrounds, a notes persistence bug where unsaved text bleeds between stairways, improvements to the Progress (Stats) tab neighborhood section, the Stats card layout on the map, promoting search from a tiny floating circle to a proper tab bar item, and cleaning up the overwhelming map annotation labels from the Urban Hiker data import.

## 2. Scope

Seven changes:

**A. Green text readability** — Replace the dark `forestGreen` color with a brighter green that reads well on dark gray backgrounds. Audit every usage.

**B. Notes persistence bug** — Unsaved note text should not auto-save or carry over when navigating between stairways. If the user doesn't explicitly save, discard.

**C. Collapsible neighborhoods in Progress tab** — Neighborhood rows become collapsible disclosure groups, default to collapsed, and expand to show individual walks (name, steps, date).

**D. Stats card orange bar** — The "Stats" label should sit inside the orange bar, and the bar should be sized to fit that text (not a 4pt stripe).

**E. Search as a tab bar item** — Replace the floating 32x32 magnifying glass circle on the map with a proper tab bar item in the main TabView.

**F. Tab label rename** — Change "Progress" to "Stats" (missed during Remove Saved implementation).

**G. Map annotation label cleanup** — Truncate long stairway names for map display and hide labels entirely until zoomed to neighborhood level.

## 3. Business Rules

### A. Green Text Readability

- `forestGreen` (currently RGB 45/95/63, hex #2D5F3F) is too dark to read on dark material backgrounds and dark gray cards. Replace with a brighter green.
- Suggested replacement: RGB 80/200/120 (hex #50C878, "emerald green") or similar — must pass WCAG AA contrast against both `systemGray6` dark mode (~#1C1C1E) and `.ultraThinMaterial` dark backgrounds.
- `walkedGreen` (#4CAF50) is acceptable for badges, progress bars, and icons. No change needed there.
- Every usage of `forestGreen` in the iOS Views directory should be updated to the new color. Rename the color to `brightGreen` or keep `forestGreen` and just change the RGB values (implementer's choice, but changing the values in AppColors.swift is simplest).
- The tab bar tint in ContentView also uses `forestGreen` — update it too.

### B. Notes Persistence Bug

Current behavior:
- `StairwayBottomSheet` has `@State private var notesText: String = ""`
- On `.onAppear`, it sets `notesText = walkRecord?.notes ?? ""`
- On `.onDisappear`, if `editingNotes` is true, it calls `saveNotes()` — this auto-saves whatever is in the text field

Problem: If the user opens a stairway, starts typing a note but doesn't tap Save, then dismisses the sheet and opens a different stairway, one of two things happens: (1) the note auto-saves to the wrong stairway via `onDisappear`, or (2) the state carries over and shows on the next stairway.

Fix:
- Remove the `if editingNotes { saveNotes() }` from `.onDisappear`. Unsaved notes should be discarded on dismiss.
- On `.onAppear` (or when the stairway binding changes), always reset `notesText` to `walkRecord?.notes ?? ""` and reset `editingNotes` to `false`.
- The explicit "Save" button tap remains the only way to persist notes.

### C. Collapsible Neighborhoods in Progress Tab

Current: flat list of neighborhood rows with name, walked/total count, and a progress bar.

New behavior:
- Each neighborhood is a `DisclosureGroup` that defaults to **collapsed**.
- Collapsed state: shows neighborhood name, walked/total count, and progress bar (same as current).
- Expanded state: below the progress bar, show a list of individual walks in that neighborhood. Each walk row shows:
  - Stairway name
  - Step count (from the WalkRecord or StairwayOverride, whichever is available; show "—" if neither)
  - Date walked (formatted as "Mar 9" style)
  - Do NOT show elevation
- Sort walks within each neighborhood by date walked (most recent first).
- Only show stairways that have been walked (i.e., have a WalkRecord with walked=true).

### D. Stats Card Orange Bar

Current: `Color.brandAmber.frame(height: 4)` as a thin stripe, with "Stats" text below it in a secondary caption.

New layout:
- The orange bar should contain the "Stats" text inside it, white text on brandAmber background.
- Bar height should be sized to fit the text comfortably (roughly 24-28pt including vertical padding).
- Remove the separate `Text("Stats")` line below the bar.
- The stat values (stairway count, height, steps) remain below the bar in the existing style.

Suggested implementation:
```swift
// Replace the Color.brandAmber.frame(height: 4) and the Text("Stats") lines with:
Text("Stats")
    .font(.caption2)
    .fontWeight(.semibold)
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 4)
    .background(Color.brandAmber)
```

### E. Search as Tab Bar Item

Current: a floating 32x32 translucent circle on the map's bottom-right overlay, sitting on top of the Stats card.

New: search should be a full tab bar item alongside Map, List, and Stats.

Changes:
- In `ContentView.swift`, add a Search tab to the TabView:
  - Icon: `magnifyingglass`
  - Label: "Search"
  - Tag: 3 (after Stats at tag 2)
  - Content: `SearchPanel` adapted for tab usage (remove the dismiss button/logic since it's now a persistent tab, not a fullScreenCover)
- Remove the floating search button overlay from `MapTab.swift` (the `.overlay(alignment: .bottomTrailing)` block with the magnifyingglass button).
- Remove the `showSearch` state and `.fullScreenCover` from `MapTab.swift`.
- When a search result is selected, switch to the Map tab (tag 0) and fly to the stairway. This requires either:
  - A shared selection binding or callback passed through the TabView, OR
  - A lightweight coordinator/notification that MapTab observes
- The SearchPanel's `onSelectStairway` and `onSelectNeighborhood` callbacks should trigger the tab switch + map navigation.

### F. Tab Label Rename

- In `ContentView.swift`, change the ProgressTab's tab label from `Text("Progress")` to `Text("Stats")`.

### G. Map Annotation Label Cleanup

The Urban Hiker data import brought in 766 stairways with names that are really descriptions/directions (e.g., "Medical Center Way, No. 134, behind the clinics at UCSF, with stairs up to Johnstone Drive and the Historic Trail through Sutro Forest."). 967 of 1,144 total names exceed 4 words. These overwhelm the map with dense, overlapping text at any zoom level.

Two changes:

**G1. Truncate display names for map annotations**
- Add a computed property `displayName` to the `Stairway` model (or as an extension) that intelligently truncates the name:
  - If the name is 4 words or fewer, use it as-is.
  - If the name is longer than 4 words, take the first 4 words. If the 4th word ends with a comma or period, strip that trailing punctuation.
  - Do NOT add an ellipsis — just use the truncated text.
- Use `displayName` for map annotation labels only. The full `name` continues to be used in the detail sheet, list view, search results, and progress tab.
- Examples:
  - "Pemberton Place at Crown Terrace" (4 words) → "Pemberton Place at Crown Terrace" (unchanged)
  - "Blake/Geary & Euclid, into Laurel Hill Playground. In Laurel Heights." → "Blake/Geary & Euclid into"
  - "Medical Center Way, No. 134, behind the clinics at UCSF..." → "Medical Center Way No"
  - "Buena Vista Park interior. Closest entrance is..." → "Buena Vista Park interior"

**G2. Hide annotation labels at wide zoom levels**
- Map annotations should only show the text label (the `displayName`) when zoomed in to approximately neighborhood level or closer.
- Use `mapSpan` (already tracked in MapTab state) as the threshold. When `mapSpan > 0.02` (roughly wider than a neighborhood), hide the annotation label text and show only the pin/teardrop marker.
- When `mapSpan <= 0.02`, show the pin with the `displayName` label.
- This dramatically reduces visual clutter at city-wide zoom.
- The current `Annotation(stairway.name, coordinate:)` call uses the name as the built-in label. To control visibility, switch to using `Annotation("", coordinate:)` when zoomed out (empty string hides the label), or conditionally set the label string based on mapSpan.

## 4. Data Model / Schema Changes

None. The `displayName` is a computed property, not a persisted field.

## 5. UI / Interface

### Tab bar (updated order):
Map | List | Stats | Search

### ProgressCard on map:
Orange bar with white "Stats" text inside it, followed by stat values below.

### Progress (Stats) tab neighborhoods:
Collapsed disclosure groups showing neighborhood + progress bar. Tap to expand and see individual walk rows.

### StairwayBottomSheet notes:
No auto-save on dismiss. Only the Save button persists notes.

## 6. Integration Points

- `SearchPanel.swift` needs adaptation to work both as a fullScreenCover (current) and as a tab. The simplest approach: keep SearchPanel as-is but add a `isTabMode: Bool` parameter that hides the dismiss button when true.
- The stairway/neighborhood selection from SearchPanel needs to communicate to MapTab across tabs. Consider using a shared `@Observable` coordinator or `NotificationCenter`.

## 7. Constraints

- The new green color must be visually readable on dark backgrounds. Test in dark mode.
- Search tab should feel native — same tab bar styling as the other three tabs.
- Neighborhood disclosure groups should animate smoothly.
- Notes discard behavior should be intuitive — if someone accidentally dismisses, they lose unsaved text. This is the expected mobile pattern.

## 8. Acceptance Criteria

### Green readability
- [ ] `forestGreen` color updated to a brighter value that reads clearly on dark gray backgrounds
- [ ] All usages in iOS Views updated (grep for `forestGreen` should show the new color)
- [ ] Tab bar tint updated

### Notes bug
- [ ] Type a note on stairway A, dismiss without saving, open stairway B — no note text carries over
- [ ] Type a note on stairway A, dismiss without saving, reopen stairway A — note text is gone (not auto-saved)
- [ ] Tap Save, dismiss, reopen — note persists correctly

### Collapsible neighborhoods
- [ ] Neighborhoods default to collapsed
- [ ] Expanding shows individual walks with name, steps, date
- [ ] No elevation shown in walk rows
- [ ] Walks sorted by date (most recent first)

### Stats card
- [ ] "Stats" text is inside the orange bar with white text
- [ ] Orange bar is tall enough to comfortably fit the text
- [ ] No duplicate "Stats" label below the bar

### Search tab
- [ ] Search appears as the 4th tab in the tab bar with magnifyingglass icon
- [ ] Floating search circle removed from map
- [ ] Selecting a search result switches to Map tab and navigates to the stairway
- [ ] Search tab works correctly when switching back and forth

### Tab rename
- [ ] Tab label reads "Stats" not "Progress"

### General
- [ ] No regressions in existing functionality
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

**Modified files:**
- `ios/SFStairways/Resources/AppColors.swift` — update forestGreen RGB values
- `ios/SFStairways/Views/ContentView.swift` — add Search tab, rename Progress to Stats
- `ios/SFStairways/Views/Map/MapTab.swift` — remove floating search button + fullScreenCover, fix ProgressCard
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — remove auto-save on disappear, reset notes state
- `ios/SFStairways/Views/Progress/ProgressTab.swift` — collapsible neighborhoods with walk details
- `ios/SFStairways/Views/Map/SearchPanel.swift` — add isTabMode parameter, adapt for tab usage

**Possibly new files:**
- A shared navigation coordinator (e.g., `ios/SFStairways/Services/NavigationCoordinator.swift`) for cross-tab communication
