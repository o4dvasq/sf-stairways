# iOS App Reference — sf-stairways

_For use as Chat context when designing specs. Last verified against code: 2026-03-26 (post visual refresh v2)._

**Purpose:** This document describes what is actually built and running in the iOS app. Upload this to Desktop Chat before designing any new feature so specs target the real codebase, not a stale or imagined one.

---

## Platform & Stack

- Swift / SwiftUI / iOS 17+
- MapKit (not Mapbox, not Leaflet)
- SwiftData with CloudKit sync (container: `iCloud.com.o4dvasq.sfstairways`)
- No third-party packages. No CocoaPods, no SPM dependencies. Everything is native Apple APIs + bundled JSON.
- No build tooling beyond Xcode. No Vite, no npm, no CI/CD pipeline.
- Deployed by building in Xcode and running on device. No TestFlight yet.

---

## File Map (iOS source only)

```
ios/SFStairways/
├── SFStairwaysApp.swift              ← App entry point, CloudKit container init
├── Models/
│   ├── Stairway.swift                ← Codable value type (from bundled JSON)
│   ├── WalkRecord.swift              ← SwiftData @Model (syncs to CloudKit)
│   ├── WalkPhoto.swift               ← SwiftData @Model, external storage for images
│   └── StairwayStore.swift           ← @Observable, loads catalog, search/filter helpers
├── Views/
│   ├── ContentView.swift             ← Root TabView (Map / List / Progress)
│   ├── SplashView.swift              ← Launch splash (1.5s, amber background)
│   ├── Map/
│   │   ├── MapTab.swift              ← Primary map view, filters, Around Me, search trigger
│   │   ├── TeardropPin.swift         ← Custom teardrop Shape + StairwayPin view
│   │   ├── StairwayAnnotation.swift  ← Applies state logic to StairwayPin per stairway
│   │   ├── StairwayBottomSheet.swift ← Pin-tap detail card with action buttons
│   │   ├── SearchPanel.swift         ← Full-screen search (Name/Street/Neighborhood tabs)
│   │   └── AroundMeManager.swift     ← @Observable, neighborhood detection + dimming
│   ├── List/
│   │   ├── ListTab.swift             ← Grouped stairway list with search + filter
│   │   └── StairwayRow.swift         ← Row component (name, stats, walked indicator)
│   ├── Detail/
│   │   ├── StairwayDetail.swift      ← Full detail: photos, notes, walk toggle, stats
│   │   └── PhotoViewer.swift         ← Full-screen photo viewer with delete
│   ├── Progress/
│   │   └── ProgressTab.swift         ← Completion ring, stats, neighborhood breakdown
│   └── Components/
│       └── ToastView.swift           ← Auto-dismissing toast + .toast() modifier
├── Services/
│   ├── LocationManager.swift         ← CLLocationManager wrapper
│   ├── PhotoService.swift            ← PhotoPicker + CameraPicker (UIKit bridges)
│   ├── SyncStatusManager.swift       ← CloudKit sync state observer
│   └── SeedDataService.swift         ← First-launch data seeder from target_list.json
├── Resources/
│   ├── AppColors.swift               ← All color definitions (see Design System below)
│   ├── all_stairways.json            ← 382 stairways catalog (read-only)
│   ├── target_list.json              ← 13 seed stairways with personal walk data
│   ├── neighborhood_centroids.json   ← Avg lat/lng per neighborhood
│   └── neighborhood_adjacency.json   ← Neighborhood → neighbors lookup
└── Assets.xcassets/                  ← App icon, accent color, splash image
```

---

## Data Model

### Stairway (value type, read-only catalog)

Loaded from `all_stairways.json` at app launch into `StairwayStore`. Not persisted in SwiftData.

| Field | Type | Notes |
|-------|------|-------|
| id | String | Unique slug, e.g. "vulcan-stairway" |
| name | String | Display name |
| neighborhood | String | One of ~53 SF neighborhood names |
| lat | Double? | Latitude (nil = no coordinate, skipped on map) |
| lng | Double? | Longitude |
| heightFt | Double? | Height in feet |
| closed | Bool | Whether stairway is currently closed |
| geocodeSource | String? | "page" or "nominatim" |
| sourceURL | String? | sfstairways.com link |

### WalkRecord (SwiftData @Model, syncs to CloudKit)

This is the **only write path** in the app. All user state flows through WalkRecord.

| Field | Type | Notes |
|-------|------|-------|
| stairwayID | String | References Stairway.id |
| walked | Bool | false = Saved, true = Walked |
| dateWalked | Date? | When the walk happened |
| notes | String? | User notes |
| createdAt | Date | Auto-set |
| updatedAt | Date | Auto-set on changes |
| photos | [WalkPhoto]? | @Relationship, cascade delete |

### WalkPhoto (SwiftData @Model)

| Field | Type | Notes |
|-------|------|-------|
| imageData | Data? | @Attribute(.externalStorage) — full resolution |
| thumbnailData | Data? | @Attribute(.externalStorage) — max 300px, JPEG 0.7 |
| caption | String? | |
| takenAt | Date | |
| walkRecord | WalkRecord? | Back-reference |

### Three-State Model

Every stairway exists in exactly one state, derived from WalkRecord:

| State | Condition | Meaning |
|-------|-----------|---------|
| **Unsaved** | No WalkRecord exists | Default; user hasn't interacted |
| **Saved** | WalkRecord exists, `walked == false` | Bookmarked for future visit |
| **Walked** | WalkRecord exists, `walked == true` | User has visited |

State transitions: Unsaved → Saved (tap Save), Saved → Walked (tap Mark Walked), Walked → Saved (tap Unmark), Saved → Unsaved (tap Remove), Unsaved → Walked (tap Mark Walked directly), Walked → Unsaved (tap Remove).

---

## Current UI Layout

### Tab Structure

Three tabs via `ContentView` TabView: **Map** (map icon), **List** (list icon), **Progress** (chart icon). Tab tint: `forestGreen`.

### Map Tab (MapTab.swift)

```
┌─────────────────────────────────┐
│  [status bar / Dynamic Island]  │
│  ┌───────────────────────────┐  │
│  │ SF STAIRWAYS      🔍  ◎  │  │  ← white top bar: amber logo + search circle + Around Me circle
│  └───────────────────────────┘  │
│  [All] [Saved] [Walked] [Nearby]│  ← filter pills below top bar, overlaying map
│                                 │
│         APPLE MAPS              │
│      (MapKit, dark appearance)  │
│                                 │
│   🟠  🟡  🟠                   │  ← amber=unsaved, light green=saved
│      🟢     🟠                 │     green=walked
│                                 │
│   [You're in Noe Valley]        │  ← neighborhood chip (Around Me)
│                                 │
│  [home indicator safe area]     │
└─────────────────────────────────┘
```

**White top bar:** Pinned below Dynamic Island safe area. Left: "SF Stairways" text logo in amber (#D4882B). Right: two circular icon buttons (32pt diameter, light gray background) for search (magnifying glass) and Around Me (location.fill). Around Me button fills with amber when active. Subtle bottom shadow.

**Filter pills:** Directly below top bar, overlaying the map. Pills: All / Saved / Walked / Nearby. Active = `brandAmber` (#D4882B) fill + white text. Inactive = dark (#333333) + white text. Radio behavior (one at a time). "Nearby" uses 1500m radius from current location.

**Around Me:** Circle button in top bar triggers `AroundMeManager`: nearest-centroid neighborhood detection, highlight current + adjacent neighborhoods, dim all other pins to 30% opacity. Shows neighborhood chip on map. Toggles off on second tap.

**Search:** Circle button in top bar opens `SearchPanel` as `.fullScreenCover`. No bottom search bar.

**Dark map:** `.preferredColorScheme(.dark)` scoped to the Map view only. Dark/charcoal basemap from MapKit standard dark style.

**Map controls:** User location button, compass, scale ruler.

### Pin Design (TeardropPin.swift)

Custom `TeardropShape` (SwiftUI Path): circle bulb on top, triangle taper to point on bottom. All three states use the same "stairs" SF Symbol (unified stair icon).

| State | Size | Color | Icon | Opacity |
|-------|------|-------|------|---------|
| Unsaved | 24×30pt | `brandAmber` (#D4882B) | "stairs" SF Symbol (white) | 0.5 |
| Saved | 28×35pt | `pinSaved` (#81C784) | "stairs" SF Symbol (white) | 1.0 |
| Walked | 28×35pt | `walkedGreen` (#4CAF50) | "stairs" SF Symbol (white) | 1.0 |
| Selected | 34×42pt | darker variant of current state | "stairs" SF Symbol (white) | 1.0 + shadow |
| Dimmed | same as state | same as state | same as state | 0.3 |
| Closed | same as state | `unwalkedSlate` | same as state | 0.4 |

Icon size = 38% of pin width. Icons are SF Symbols, not custom paths.

### Bottom Sheet (StairwayBottomSheet.swift)

Opens on pin tap. Presentation detents: `.height(340)` and `.medium`. Shows drag indicator.

Content: stairway name (title2, bold), neighborhood + distance, state indicator (colored circle with icon), action buttons, "View Details" link.

| State | Indicator | Actions | Detail button color |
|-------|-----------|---------|-------------------|
| Unsaved | (none) | Save (amber), Mark Walked (green) | forestGreen |
| Saved | Amber bookmark in circle | Unsave (gray), Mark Walked (green) | brandAmber |
| Walked | Green checkmark in circle | Unmark Walk (amber), Remove (gray) | walkedGreen |

### Search Panel (SearchPanel.swift)

Full-screen cover, slides up. Three tabs: **Name** / **Street** / **Neighborhood**. Active tab = `forestGreen`.

Search is live substring matching (case-insensitive). Name and Street tabs both search stairway names (street info is embedded in names). Neighborhood tab shows grouped results with stairway counts.

Each result row: stairway name + neighborhood + distance (meters if <1km, km otherwise). Tap dismisses panel, flies map to location, selects pin.

### List Tab (ListTab.swift)

Searchable grouped list organized by neighborhood (alphabetical). Filter chips: All / Walked / Saved. Navigation to `StairwayDetail` on row tap.

Row component (`StairwayRow`): stairway name, height stat, closed badge (red strikethrough), photo count badge, walked indicator (checkmark or circle outline).

### Detail View (StairwayDetail.swift)

Photo carousel (220px height, TabView with page style), stats row (feet / photos), walk toggle card (green background if walked, gray if not), date picker for walk date, editable notes field (min 80px), 3-column photo grid. Toolbar camera menu: "Take Photo" / "Choose from Library".

### Progress Tab (ProgressTab.swift)

Compact ring + summary (height climbed, neighborhood count), neighborhood card grid sorted by completion %, collapsible undiscovered section. Sync status cloud icon in toolbar.

### Toast (ToastView.swift)

Auto-dismissing pill at bottom (100px padding). Black background at 75% opacity. 3-second default duration. Used for Around Me errors and location denial messages.

---

## Design System (AppColors.swift)

All colors are defined as `Color` extensions in `AppColors.swift`.

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `brandAmber` | #D4882B | 212, 136, 43 | Unsaved pins, top bar logo, filter pill active, Around Me active, Save/Unmark buttons |
| `brandAmberDark` | #B5721F | 181, 114, 31 | Selected unsaved pin |
| `pinSaved` | #81C784 | 129, 199, 132 | Saved pins |
| `pinSavedDark` | #66BB6A | 102, 187, 106 | Selected saved pin |
| `walkedGreen` | #4CAF50 | 76, 175, 80 | Walked pins, walked indicators, Mark Walked buttons |
| `walkedGreenDark` | #388E3C | 56, 142, 60 | Selected walked pin |
| `forestGreen` | #2D5F3F | 45, 95, 63 | Tab tint, search tab active, detail button (unsaved) |
| `accentAmber` | #E8A838 | 232, 168, 56 | Splash screen background |
| `walkedGreenDim` | #78B47D | 120, 180, 125 | Informational use |
| `actionGreen` | #4CAF50 | 76, 175, 80 | CTA buttons (same value as walkedGreen) |
| `unwalkedSlate` | #789094 | 120, 144, 156 | Closed stairway override |
| `closedRed` | #B0706F | 176, 112, 111 | Closed stairway badge text |
| `pillActive` | #D4882B | 212, 136, 43 | Filter pill active (same as brandAmber) |
| `pillInactive` | #333333 | 51, 51, 51 | Filter pill inactive background |
| `topBarBackground` | #FFFFFF | 255, 255, 255 | White top bar |
| `topBarText` | #1A1A1A | 26, 26, 26 | Top bar text color |

Note: `brandOrange`/`brandOrangeDark` were removed in the v2 visual refresh and replaced by `brandAmber`/`brandAmberDark`.

---

## Neighborhood System

**53 neighborhood names** in the stairway data (from sfstairways.com scraper). These do NOT match the DataSF "Analysis Neighborhoods" dataset (37 names). The app uses its own neighborhood vocabulary derived from the scraped data.

**Centroid detection:** `AroundMeManager` loads `neighborhood_centroids.json` (average lat/lng of all stairways in each neighborhood). User's current neighborhood = nearest centroid within 5km. This is simpler and more accurate for this dataset than polygon point-in-polygon.

**Adjacency:** Pre-computed in `neighborhood_adjacency.json` by `scripts/build_neighborhood_adjacency.py`. Two neighborhoods are adjacent if their centroids are within 2.5km. "Around Me" highlights current + adjacent neighborhoods.

---

## Data Flow

```
all_stairways.json ──► StairwayStore (@Observable)
                            │
                            ├──► MapTab (pins, filters)
                            ├──► ListTab (grouped list)
                            ├──► SearchPanel (search results)
                            └──► ProgressTab (stats)

neighborhood_centroids.json ─┐
                              ├──► AroundMeManager (@Observable) ──► pin dimming
neighborhood_adjacency.json ──┘

SwiftData (WalkRecord, WalkPhoto) ◄──► CloudKit sync
    │
    ├──► MapTab (@Query for walk records)
    ├──► ListTab (@Query)
    ├──► StairwayDetail (@Query + mutations)
    └──► ProgressTab (@Query for stats)
```

`StairwayStore` = read-only catalog. `WalkRecord` = all user mutations.

---

## Technology Constraints (for spec writers)

When designing new features, these are hard constraints:

1. **MapKit, not Mapbox.** Free, already integrated, no token management. See DECISIONS.md.
2. **SwiftData + CloudKit, not localStorage.** User state syncs across devices. No browser storage.
3. **No build pipeline.** No Vite, no webpack, no npm. Xcode builds the app. Bundled JSON for static data.
4. **No third-party packages.** Everything is native Apple frameworks. Adding a dependency requires justification.
5. **No server.** The app is fully client-side. Bundled JSON for catalog, SwiftData for user data. Supabase backend is a future workstream (separate spec exists but not implemented).
6. **53 neighborhood names from scraper, not DataSF's 37.** Any neighborhood feature must use the app's own vocabulary.
7. **Centroid-based detection, not polygon.** No GeoJSON polygons bundled. Neighborhood detection = nearest centroid lookup.
8. **Web app is deprecated.** All new features target iOS only.
9. **SF Symbols for icons, not custom SVG.** All pin states use the "stairs" SF Symbol (unified). Custom icon paths are possible via SwiftUI Path but SF Symbols are the current pattern.
10. **Single user.** No auth, no user accounts, no multi-user features yet. That's a separate future workstream.

---

## Spec Checklist for Chat

Before finalizing any spec in Desktop Chat, verify:

- [ ] Platform is iOS (Swift/SwiftUI), not web
- [ ] Map references use MapKit, not Mapbox or Leaflet
- [ ] Persistence uses SwiftData/WalkRecord, not localStorage or Supabase
- [ ] Colors reference actual AppColors tokens (see table above), not invented hex values
- [ ] Pin design matches current TeardropPin (sizes, icon approach, state model)
- [ ] Neighborhoods use the 53-name scraper vocabulary, not DataSF
- [ ] No new third-party dependencies unless justified
- [ ] No server-side requirements
- [ ] Files Likely Touched references actual Swift files in the file map above
- [ ] UI layout matches actual current layout (white top bar with circle buttons, no bottom bar, dark map, amber/green pin palette)
- [ ] Existing behavior that isn't changing is described as "unchanged" rather than re-specified
