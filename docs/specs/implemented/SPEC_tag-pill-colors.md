SPEC: Tag Pill Colors | Project: sf-stairways | Date: 2026-04-03 | Status: Ready for implementation

## 1. Objective

Replace the thin green outline + green text tag pills with filled, colorful pills using the same color palette as the neighborhood map overlays. Each tag gets a randomly assigned color at creation time, persisted so it stays consistent. Pill text is white.

## 2. Scope

- Add a `colorIndex` property to StairwayTag model
- Assign random color index at tag creation
- Update tag pill rendering everywhere (StairwayBottomSheet, TagEditorSheet, TagFilterSheet, SearchPanel)

## 3. Business Rules

- Each tag gets a color assigned once at creation (random index into the 12-color palette)
- Color is stable (persisted on the model, not computed)
- White text on colored background for all tag pills
- The "+ Add Tag" button keeps its current dashed outline style (does not get a fill color)

## 4. Data Model / Schema Changes

Add to `StairwayTag`:
```swift
var colorIndex: Int = 0
```

Default value of `0` handles migration of existing tags. Existing tags will all start as rose (palette index 0). To make them varied, the migration or a one-time seed task could randomize existing tags' `colorIndex` values. But this is optional since users likely have few tags.

## 5. UI / Interface

### Tag Pill (new style)
- Background: filled with `tagPalette[tag.colorIndex % tagPalette.count]`
- Text: white, `.subheadline`, `.fontWeight(.medium)`
- Shape: Capsule (same as current)
- Padding: `.horizontal(12)`, `.vertical(6)` (same as current)
- No border/stroke

### Tag Palette
Reuse the same 12 colors from NeighborhoodStore, but define them as a shared constant (or duplicate them in AppColors) so tags don't need a dependency on NeighborhoodStore:

```swift
// In AppColors.swift or a new TagColors constant
static let tagPalette: [Color] = [
    Color(red: 0.92, green: 0.55, blue: 0.55),  // rose
    Color(red: 0.52, green: 0.75, blue: 0.92),  // sky blue
    Color(red: 0.55, green: 0.90, blue: 0.55),  // mint green
    Color(red: 0.92, green: 0.85, blue: 0.38),  // warm yellow
    Color(red: 0.72, green: 0.52, blue: 0.92),  // lavender
    Color(red: 0.92, green: 0.62, blue: 0.42),  // peach
    Color(red: 0.38, green: 0.88, blue: 0.80),  // aqua
    Color(red: 0.85, green: 0.48, blue: 0.76),  // pink-purple
    Color(red: 0.48, green: 0.85, blue: 0.48),  // sage
    Color(red: 0.92, green: 0.58, blue: 0.32),  // apricot
    Color(red: 0.45, green: 0.65, blue: 0.92),  // cornflower
    Color(red: 0.88, green: 0.88, blue: 0.35),  // lemon
]
```

### Color Assignment at Creation
In `TagEditorSheet.createTag()` and `SeedDataService` (for preset tags):
```swift
let tag = StairwayTag(id: id, name: name, isPreset: false)
tag.colorIndex = Int.random(in: 0..<12)
```

For preset tags during seed, assign sequential colors so they look varied out of the box.

## 6. Integration Points

None.

## 7. Constraints

- iOS 17+ / SwiftData
- Adding a new property to a SwiftData model with a default value is a lightweight migration (no manual migration needed)
- Some palette colors (warm yellow, lemon) may need slightly darkened variants for sufficient contrast with white text. If so, darken by ~15% for the tag pill version.

## 8. Acceptance Criteria

- [ ] Tag pills show filled background color with white text
- [ ] Each tag has a stable color that doesn't change between sessions
- [ ] New tags get a randomly assigned color from the 12-color palette
- [ ] Preset tags get varied colors (not all the same)
- [ ] Tag pills render correctly in: StairwayBottomSheet, TagEditorSheet, TagFilterSheet, SearchPanel
- [ ] "+ Add Tag" button retains its dashed outline style
- [ ] White text is legible on all 12 palette colors (darken yellow/lemon if needed)

## 9. Files Likely Touched

- `ios/SFStairways/Models/StairwayTag.swift` — add `colorIndex: Int` property
- `ios/SFStairways/Resources/AppColors.swift` — add `tagPalette` array
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — update tag pill rendering
- `ios/SFStairways/Views/Components/TagEditorSheet.swift` — update pill rendering + assign color on creation
- `ios/SFStairways/Views/Map/TagFilterSheet.swift` — update pill rendering
- `ios/SFStairways/Views/Map/SearchPanel.swift` — update pill rendering if tags shown there
- `ios/SFStairways/Services/SeedDataService.swift` — assign sequential colors to preset tags
