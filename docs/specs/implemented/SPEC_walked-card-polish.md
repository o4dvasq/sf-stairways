SPEC: Walked Card Polish | Project: sf-stairways | Date: 2026-04-03 | Status: Ready for implementation

## 1. Objective

Polish the walked card green banner (implemented in SPEC_walked-card-redesign) based on user feedback. Several details need adjustment.

## 2. Scope

StairwayBottomSheet.swift and PhotoCarousel.swift only.

## 3. Business Rules

The walked banner should show all key info at a glance without needing to scroll or tap anything.

## 4. Data Model / Schema Changes

None.

## 5. UI / Interface

### Changes to Green Banner

Current banner shows:
- Stairway name (white, bold)
- Neighborhood name
- Checkmark

**Add to banner:**
- After neighborhood name, on the same line: `" · X of Y walked"` (e.g., "Ashbury Heights · 2 of 10 walked")
- Below the neighborhood line: date walked in white, `.caption` size (e.g., "April 3, 2026"). Use `date.formatted(date: .long, time: .omitted)`.

### Remove pencil / edit date icon

The pencil icon button (currently in the icons row below the banner, calls `editingDate = true`) should be removed entirely. The date is now displayed in the banner and does not need to be editable. Remove the `editingDate` state var and the associated DatePicker if it exists.

Current code around line 453-459:
```swift
Button {
    editingDate = true
} label: {
    Image(systemName: "pencil")
        .font(.system(size: 16))
        .foregroundStyle(.secondary)
}
```
Delete this button.

### Remove "Photos" heading

In `PhotoCarousel.swift` (line ~20), there is still a `Text("Photos")` heading. Remove it. The photo carousel content and "Add a photo" button should remain, just without the section heading. Check NeighborhoodDetail.swift line ~113 as well for the same heading, remove it there too.

## 6. Integration Points

None.

## 7. Constraints

iOS 17+.

## 8. Acceptance Criteria

- [ ] Green banner shows neighborhood + "X of Y walked" on same line (e.g., "Ashbury Heights · 2 of 10 walked")
- [ ] Date walked appears in banner below the neighborhood line, white, caption size
- [ ] Pencil / edit date icon is removed
- [ ] "Photos" heading removed from StairwayBottomSheet (PhotoCarousel.swift)
- [ ] "Photos" heading removed from NeighborhoodDetail.swift
- [ ] `editingDate` state variable and any associated DatePicker removed

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — update banner content, remove pencil button, remove editingDate
- `ios/SFStairways/Views/Detail/PhotoCarousel.swift` — remove "Photos" heading
- `ios/SFStairways/Views/Neighborhood/NeighborhoodDetail.swift` — remove "Photos" heading
