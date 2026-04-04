SPEC: Domain Update (sfstairways.app to new domain) | Project: sf-stairways | Date: 2026-04-03 | Status: BLOCKED — waiting for Oscar to confirm new domain

## 1. Objective

Update all references to sfstairways.app once Oscar secures the new domain (likely sfstairs.app). The rebrand changed "SF Stairways" to "SF Stairs" in user-facing text, but the domain references still say sfstairways.app.

## 2. Scope

All domain references in the app and landing pages.

## 3. Known Locations

Once the new domain is confirmed, update:

### iOS App
- `ios/SFStairways/Views/ShareCardView.swift` line 119: `"sfstairways.app"` — the domain shown on the share card
- `ios/SFStairways/Views/Map/StairwayBottomSheet.swift` line 254: `"Climb every stair in SF — sfstairways.app"` — the share sheet text

### Landing Pages
- `index.html` line 12: og:url `https://sfstairways.app`
- `privacy.html`: any canonical URL references
- GitHub Pages custom domain setting
- CNAME file (if used by GitHub Pages)

### External (Oscar manual action)
- Squarespace DNS: A records and CNAME need to point new domain
- GitHub Pages: custom domain setting in repo settings
- App Store Connect: marketing URL and support URL fields

## Status

Blocked until Oscar confirms the new domain name and completes DNS setup. This spec will be updated with the actual domain once known.
