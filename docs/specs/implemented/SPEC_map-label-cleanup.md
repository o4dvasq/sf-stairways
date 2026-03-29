SPEC: Map Annotation Label Cleanup — Truncate Names + Hide at Wide Zoom | Project: sf-stairways | Date: 2026-03-29 | Status: Ready for implementation

---

## 1. Objective

The Urban Hiker data import brought in 766 stairways with names that are really full descriptions/directions (e.g., "Medical Center Way, No. 134, behind the clinics at UCSF, with stairs up to Johnstone Drive and the Historic Trail through Sutro Forest."). 967 of 1,144 total stairway names exceed 4 words. These overwhelm the map with dense, overlapping text labels at any zoom level. Fix by truncating display names and hiding labels until zoomed to neighborhood level.

## 2. Scope

Two changes:

**A. Truncate display names for map annotations** — Add a computed property that caps names at 4 words for map pin labels only.

**B. Hide annotation labels at wide zoom** — Only show pin text labels when zoomed to neighborhood level or closer.

## 3. Business Rules

### A. Truncate Display Names

- Add a computed property `displayName` to the `Stairway` model (or as an extension) that intelligently truncates the name:
  - If the name is 4 words or fewer, use it as-is.
  - If the name is longer than 4 words, take the first 4 words. If the last word ends with a comma, period, or semicolon, strip that trailing punctuation.
  - Do NOT add an ellipsis — just use the truncated text cleanly.
- Use `displayName` for map annotation labels ONLY. The full `name` continues to be used everywhere else: detail sheet, list view, search results, progress tab.
- Examples of truncation:
  - "Pemberton Place at Crown Terrace" (4 words) → unchanged
  - "Key at Jennings." (3 words) → unchanged
  - "Blake/Geary & Euclid, into Laurel Hill Playground. In Laurel Heights." → "Blake/Geary & Euclid into"
  - "Medical Center Way, No. 134, behind the clinics at UCSF..." → "Medical Center Way No"
  - "Buena Vista Park interior. Closest entrance is..." → "Buena Vista Park interior"
  - "Quesada/Newhall & 3rd St. (Between Upper and Lower Quesada)..." → "Quesada/Newhall & 3rd"

### B. Hide Labels at Wide Zoom

- Map annotations should only show the text label when zoomed in to approximately neighborhood level or closer.
- `mapSpan` is already tracked as `@State` in `MapTab`. Use it as the threshold:
  - When `mapSpan > 0.02` (roughly wider than a neighborhood): hide the annotation label text. Show only the pin/teardrop marker with no text.
  - When `mapSpan <= 0.02` (neighborhood zoom or closer): show the pin with the `displayName` label.
- The current code uses `Annotation(stairway.name, coordinate:, anchor:)` where the first parameter is the label. To control visibility:
  - Pass `""` (empty string) as the label when zoomed out.
  - Pass `stairway.displayName` when zoomed in.
  - Alternatively, conditionally set: `let label = mapSpan <= 0.02 ? stairway.displayName : ""`
- This dramatically reduces visual noise at city-wide zoom and makes the map usable.

## 4. Data Model / Schema Changes

None. `displayName` is a computed property, not persisted.

## 5. UI / Interface

### Map at city-wide zoom (current default):
Pins visible, no text labels. Clean, scannable map.

### Map at neighborhood zoom (after pinch-to-zoom or Around Me):
Pins visible with short 4-word-max labels. Readable, not cluttered.

### All other views (detail, list, search, progress):
Full stairway name shown as before. No change.

## 6. Integration Points

- The `Annotation` label in `MapTab.swift` ForEach loop needs to read `mapSpan` to conditionally show/hide text.
- `mapSpan` is already updated via `.onMapCameraChange`. No new state tracking needed.

## 7. Constraints

- The `displayName` truncation must handle edge cases: names with punctuation, abbreviations like "St." or "No.", and names that are already short.
- The zoom threshold (0.02) may need tuning in testing. It should roughly correspond to seeing one neighborhood comfortably on screen.
- Performance: the conditional label string is evaluated per-pin during render. This is lightweight (string comparison + property access) and should not cause performance issues.

## 8. Acceptance Criteria

- [ ] Names longer than 4 words are truncated to 4 words on map pin labels
- [ ] Trailing punctuation (comma, period, semicolon) stripped from truncated last word
- [ ] Full names still appear in detail sheet, list view, search results, and progress tab
- [ ] At city-wide zoom (mapSpan > 0.02), no text labels shown on pins — only markers
- [ ] At neighborhood zoom (mapSpan <= 0.02), truncated display names appear on pins
- [ ] Map is visually clean and readable at all zoom levels
- [ ] No regressions in pin tap behavior, selection, or bottom sheet display
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

**Modified files:**
- `ios/SFStairways/Models/Stairway.swift` — add `displayName` computed property
- `ios/SFStairways/Views/Map/MapTab.swift` — change Annotation label to use conditional displayName based on mapSpan
