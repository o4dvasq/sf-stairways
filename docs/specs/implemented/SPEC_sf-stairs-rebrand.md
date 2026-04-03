SPEC: SF Stairs Public Rebrand | Project: sf-stairways | Date: 2026-04-03 | Status: Ready for implementation

## 1. Objective

Change the public-facing app name from "SF Stairways" to "SF Stairs" to avoid confusion with sfstairways.com (an existing third-party website we link to as a data source). Internal code identifiers, Xcode project name, bundle ID, and CloudKit container remain unchanged.

## 2. Scope

All user-visible text, share content, and web pages. NOT internal identifiers or code.

## 3. Business Rules

- "SF Stairs" is the public brand name going forward
- sfstairways.app remains our domain (no change)
- sfstairways.com is the external reference site we link to (no change)
- Tagline changes from "Climb every stairway in San Francisco" to "Climb every stair in San Francisco"
- The Xcode project, bundle ID (`com.o4dvasq.SFStairways`), CloudKit container (`iCloud.com.o4dvasq.sfstairways`), Swift module name, folder names all stay as-is

## 4. Data Model / Schema Changes

None.

## 5. UI / Interface

### iOS App Changes

| Location | Current | New |
|---|---|---|
| ShareCardView.swift line 146 | `"SF Stairways"` | `"SF Stairs"` |
| ShareCardView.swift line 116 | `"Climb every stairway in San Francisco"` | `"Climb every stair in San Francisco"` |
| StairwayBottomSheet.swift line 222 | `"Climb every stairway in SF — sfstairways.app"` | `"Climb every stair in SF — sfstairways.app"` |
| Splash image (baked into PNG) | "SF Stairways" + "Climb every stairway..." | "SF Stairs" + "Climb every stair..." — **CoWork will re-render this image** |

Note: The App Store display name (set in Xcode under TARGETS > General > Display Name or in App Store Connect) should also be "SF Stairs" for the public listing.

### Landing Page (index.html)

| Line | Current | New |
|---|---|---|
| `<title>` (line 6) | `SF Stairways — Climb every stairway in San Francisco` | `SF Stairs — Climb every stair in San Francisco` |
| og:title (line 9) | `SF Stairways — Climb every stairway in San Francisco` | `SF Stairs — Climb every stair in San Francisco` |
| twitter:title (line 15) | `SF Stairways — Climb every stairway in San Francisco` | `SF Stairs — Climb every stair in San Francisco` |
| Hero `<h1>` (line 369) | `SF Stairways` | `SF Stairs` |
| Tagline (line 370) | `Climb every stairway in San Francisco` | `Climb every stair in San Francisco` |
| Footer (line 496) | `SF Stairways © 2026` | `SF Stairs © 2026` |

### Privacy Page (privacy.html)

All instances of "SF Stairways" in privacy.html should become "SF Stairs". This includes:
- Page title, og tags, twitter tags
- Nav logo text
- Body text references (multiple paragraphs)
- Footer

### NOT Changed

- `SFStairways/` folder name
- `SFStairways.xcodeproj`
- Bundle ID `com.o4dvasq.SFStairways`
- CloudKit container `iCloud.com.o4dvasq.sfstairways`
- Swift struct/class names (StairwayStore, StairwayBottomSheet, etc.)
- Internal docs (CLAUDE.md, ARCHITECTURE.md, etc.) — these are developer-facing, not user-facing
- The sfstairways.com link text ("View on sfstairways.com") since that IS the external site's name
- README.md — developer-facing, optional to update

## 6. Integration Points

- App Store Connect: Display name should be set to "SF Stairs" before TestFlight submission
- The splash image PNG needs to be re-rendered by CoWork with "SF Stairs" text (will be done separately)

## 7. Constraints

- Do a simple find-and-replace for user-facing strings only
- Be careful NOT to change code identifiers, CloudKit references, or bundle IDs

## 8. Acceptance Criteria

- [ ] Share card shows "SF Stairs" and "Climb every stair in San Francisco"
- [ ] Share text from bottom sheet says "Climb every stair in SF"
- [ ] index.html title, og tags, h1, tagline, footer all say "SF Stairs"
- [ ] privacy.html all references updated to "SF Stairs"
- [ ] No code identifiers, bundle IDs, or CloudKit references were changed
- [ ] sfstairways.com link text unchanged (it's the external site name)
- [ ] App builds and runs without errors

## 9. Files Likely Touched

- `ios/SFStairways/Views/ShareCardView.swift` — 2 string changes
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` — 1 string change
- `index.html` — ~6 string changes
- `privacy.html` — ~12 string changes
