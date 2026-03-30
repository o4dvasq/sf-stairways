SPEC: Increase Neighborhood Color Saturation | Project: sf-stairways | Date: 2026-03-30 | Status: Ready for implementation

## 1. Objective

Increase the visual prominence of neighborhood polygon overlays on the map. The current coloring is too subtle to be useful as a visual reference. Neighborhoods should be clearly distinguishable at a glance while still letting the underlying map detail show through.

## 2. Scope

- Increase fill and stroke opacity for neighborhood polygons on the main map
- Increase color saturation of the neighborhood palette itself
- Adjust both light mode and dark mode values
- Touch the NeighborhoodDetail view if its polygon rendering also needs updating

## 3. Business Rules

- Neighborhoods should be visually obvious without obscuring map streets, labels, or stairway pins.
- Adjacent neighborhoods should remain distinguishable from each other (the 12-color palette already handles this via round-robin assignment).
- "Around Me" dimming behavior is preserved. Non-highlighted neighborhoods still dim when Around Me is active, but the dimmed opacity can also be revisited if the new baseline makes the contrast too stark.

## 4. Data Model / Schema Changes

None.

## 5. UI / Interface

### MapTab.swift — Neighborhood polygon rendering

**Current opacity values:**

| State | Fill Opacity | Stroke Opacity |
|-------|-------------|----------------|
| Normal (Light) | 0.17 | 0.30 |
| Normal (Dark) | 0.11 | 0.22 |
| Dimmed (Light) | 0.03 | 0.05 |
| Dimmed (Dark) | 0.03 | 0.05 |

**New opacity values (suggested starting point, adjust by eye):**

| State | Fill Opacity | Stroke Opacity |
|-------|-------------|----------------|
| Normal (Light) | 0.30 | 0.50 |
| Normal (Dark) | 0.20 | 0.40 |
| Dimmed (Light) | 0.05 | 0.10 |
| Dimmed (Dark) | 0.05 | 0.10 |

### NeighborhoodStore.swift — Color palette

The current palette uses pastel/muted RGB values with components in the 0.64-0.96 range. Shift the palette toward more saturated colors. Reduce the high channel values and increase contrast between the dominant and recessive channels.

**Current example (Soft rose):** `(0.96, 0.76, 0.76)` — very pastel
**Target direction:** `(0.92, 0.55, 0.55)` — noticeably more saturated

Apply a similar shift across all 12 colors. Keep them in the same hue families so the visual identity is preserved, just more vivid. Avoid fully saturated primary colors; aim for "clearly colored" rather than "neon."

### NeighborhoodDetail.swift — Detail view polygon

Current values are fill 0.20 / stroke 0.50. These may be fine as-is or may need a bump to match the new baseline. Evaluate after updating the map values.

## 6. Integration Points

None.

## 7. Constraints

- This is a visual tuning change. The suggested values above are a starting point. Use the Simulator to evaluate and adjust until neighborhoods are clearly visible but not overwhelming.
- Test in both light and dark mode.
- Test with Around Me active to verify the dimming contrast still works.
- Test at various zoom levels (zoomed out citywide vs. zoomed into a single neighborhood).

## 8. Acceptance Criteria

- [ ] Neighborhood polygons are clearly visible and distinguishable on the map at default zoom
- [ ] Colors are noticeably more saturated than the current pastel palette
- [ ] Map streets, labels, and stairway pins remain readable through the overlays
- [ ] Dark mode rendering looks good (not washed out, not overpowering)
- [ ] Around Me dimming still provides clear visual contrast between highlighted and non-highlighted neighborhoods
- [ ] NeighborhoodDetail view polygon rendering is consistent with the new style
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/MapTab.swift` — fill and stroke opacity values
- `ios/SFStairways/Models/NeighborhoodStore.swift` — color palette RGB values
- `ios/SFStairways/Views/Neighborhood/NeighborhoodDetail.swift` — detail view polygon opacity (if needed)
