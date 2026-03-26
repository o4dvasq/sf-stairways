SPEC: Map Pin Visibility Fix | Project: sf-stairways | Date: 2026-03-26 | Status: Ready for implementation

---

## 1. Objective

Map pins are nearly invisible on the dark map. Fix pin sizing, colors, icon rendering, and stair icon direction so pins are bold, immediately recognizable, and the 3-step stair icon inside each pin is clearly visible at all zoom levels.

## 2. Problem (from screenshot)

- Pins are 24-28pt wide — far too small on the dark map
- The stair icon inside is 38% of pin width (~9pt) — microscopic and invisible
- The SF Symbol `"stairs"` renders as 5 descending steps — wrong icon entirely
- On the dark map, the faint amber/green pins with tiny icons look like artifacts, not interactive elements
- Unsaved pins use `opacity(0.5)` which makes them nearly invisible on the dark background
- You can barely tell where stairways are, let alone distinguish unsaved/saved/walked states

## 3. Fix

### 3a. Replace SF Symbol with Custom 3-Step Stair Shape

**CRITICAL:** Do NOT use `Image(systemName: "stairs")`. It renders as 5 descending steps, which is wrong.

Create a custom SwiftUI `Shape` that draws exactly 3 ascending steps (left-to-right, going UP to the right). This must match the app icon stair silhouette — the same proportions as `AppIcon_v7.png`.

Add this to `TeardropPin.swift` (or a new `StairIcon.swift` file):

```swift
/// 3-step ascending stair silhouette — matches the app icon.
/// Steps ascend from bottom-left to top-right.
struct StairShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let stepW = w / 3.0
        let stepH = h / 3.0

        // Start at bottom-left
        path.move(to: CGPoint(x: 0, y: h))

        // Step 1: up one, right one
        path.addLine(to: CGPoint(x: 0, y: h - stepH))
        path.addLine(to: CGPoint(x: stepW, y: h - stepH))

        // Step 2: up one, right one
        path.addLine(to: CGPoint(x: stepW, y: h - 2 * stepH))
        path.addLine(to: CGPoint(x: 2 * stepW, y: h - 2 * stepH))

        // Step 3: up one, right one
        path.addLine(to: CGPoint(x: 2 * stepW, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))

        // Close: down the right side, across bottom
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()

        return path
    }
}
```

Then in `StairwayPin.body`, replace:
```swift
Image(systemName: "stairs")
    .font(.system(size: iconSize, weight: .bold))
    .foregroundStyle(.white)
    .frame(width: pinWidth, height: pinWidth)
```

With:
```swift
StairShape()
    .fill(.white)
    .frame(width: iconSize, height: iconSize)
    .frame(width: pinWidth, height: pinWidth)
```

The stair shape is solid white, centered in the pin bulb. It should be clearly readable at the new pin sizes.

### 3b. Pin Sizes — Make them 2x bigger

In `TeardropPin.swift`, update the size properties:

**Current:**
```swift
private var pinWidth: CGFloat {
    if isSelected { return 34 }
    return state == .unsaved ? 24 : 28
}
private var pinHeight: CGFloat {
    if isSelected { return 42 }
    return state == .unsaved ? 30 : 35
}
private var iconSize: CGFloat { pinWidth * 0.38 }
```

**New:**
```swift
private var pinWidth: CGFloat {
    if isSelected { return 52 }
    return state == .unsaved ? 38 : 44
}
private var pinHeight: CGFloat {
    if isSelected { return 65 }
    return state == .unsaved ? 48 : 55
}
private var iconSize: CGFloat { pinWidth * 0.42 }
```

### 3c. Pin Colors — Solid and bold, no 50% opacity on unsaved

**Current unsaved fill:** `Color.brandAmber.opacity(0.5)` — this is why unsaved pins are nearly invisible on the dark map.

**New unsaved fill:** `Color.brandAmber` (full opacity). Differentiate from saved/walked by hue alone, NOT transparency. Transparency on a dark map = invisible.

Update in `TeardropPin.swift`:
```swift
private var fillColor: Color {
    if isClosed { return Color.unwalkedSlate }
    switch state {
    case .unsaved:
        return isSelected ? Color.brandAmberDark : Color.brandAmber
    case .saved:
        return isSelected ? Color.pinSavedDark : Color.pinSaved
    case .walked:
        return isSelected ? Color.walkedGreenDark : Color.walkedGreen
    }
}
```

### 3d. Shadow — Stronger on dark map

Current shadow: `.shadow(color: .black.opacity(0.2), radius: 2, y: 1)` — invisible on dark background.

New shadow: Add a subtle light glow for contrast:
```swift
.shadow(color: .white.opacity(0.3), radius: 3, y: 0)
.shadow(color: .black.opacity(0.3), radius: 2, y: 2)
```

## 4. Scope

- `ios/SFStairways/Views/Map/TeardropPin.swift` — sizes, colors, shadow, replace SF Symbol with custom StairShape
- No other files need changes (StairwayAnnotation.swift just passes through to StairwayPin)

## 5. Design Reference

The stair icon inside each pin must match the app icon (`ios/SFStairways/Resources/AppIcon_v7.png`):
- Exactly 3 steps (not 5)
- Ascending from bottom-left to top-right (climbing UP, not descending)
- Solid filled shape (not outlined)
- White fill on colored pin background

## 6. Acceptance Criteria

- [ ] Stair icon inside pins is a custom 3-step ascending shape, NOT the SF Symbol `"stairs"`
- [ ] Steps go UP from left to right (ascending/climbing direction)
- [ ] Stair icon matches the app icon silhouette proportions
- [ ] Pins are clearly visible on the dark map at city-wide zoom level
- [ ] 3-step stair icon is legible inside each pin
- [ ] Three states (unsaved/saved/walked) are visually distinct without relying on transparency
- [ ] Selected pin is noticeably larger than unselected
- [ ] Pins don't overlap excessively at medium zoom levels (if 2x is too big, scale back to 1.7x)
- [ ] Closed stairways are still visually dimmed relative to open ones
- [ ] Feedback loop prompt has been run

## 7. Files Likely Touched

- `ios/SFStairways/Views/Map/TeardropPin.swift` — pin sizes, fill colors (remove 0.5 opacity), icon size, shadow, custom StairShape, replace SF Symbol usage
