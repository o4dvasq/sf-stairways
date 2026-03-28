SPEC: UI Overhaul + Auth DB Setup | Project: sf-stairways | Date: 2026-03-27 | Status: Ready for implementation

## 1. Objective

Two categories of work:

**A. Supabase database setup** — the `user_profiles` table and triggers don't exist yet, causing "Database error saving new user" on Sign in with Apple. Run the schema.

**B. UI overhaul** — unified color scheme, new top bar layout, splash screen fix, pin color update.

## 2. Scope

### A. Supabase Database — Manual Step (NOT a code change)

**Symptom:** Sign in with Apple now reaches Supabase successfully (Apple provider enabled, JWT secret configured), but fails with "Database error saving new user."

**Root cause:** The `on_auth_user_created` trigger in `supabase/schema.sql` attempts to INSERT into `user_profiles`, but the table doesn't exist because the schema has never been run.

**Fix:** Oscar must run `supabase/schema.sql` in the Supabase Dashboard → SQL Editor → New Query → paste contents → Run. This creates all tables, triggers, indexes, and RLS policies.

**This is a manual step. Claude Code cannot do this.** Oscar: open your Supabase dashboard, go to SQL Editor, paste the contents of `supabase/schema.sql`, and execute it. After that, Sign in with Apple should work end-to-end.

### B1. Unified Color Scheme — Amber as Default Accent

The app's default accent color changes from `brandOrange` (#E8602C) to `brandAmber` (#D4882B). This amber is currently used for the active "All" filter pill and becomes the unified color for:

- **Top bar background** on the Map tab
- **Progress card header** background on the Map tab
- **"All" filter pill** active state (already amber, no change)
- **Unsaved/all stairway pins** on the map

`brandOrange` (#E8602C) is retained in `AppColors.swift` but is no longer the primary UI accent. It can be used for CTAs or emphasis where needed.

**Color changes in `AppColors.swift`:**

```swift
// Change this line:
static let topBarBackground = Color.brandOrange  // old
// To:
static let topBarBackground = Color.brandAmber    // new — unified amber accent
```

**Pin color changes in `TeardropPin.swift` (`StairwayPin.fillColor`):**

| State | Current | New |
|-------|---------|-----|
| Unsaved (default) | `Color(white: 0.55)` (gray) | `Color.brandAmber` (#D4882B) |
| Unsaved (selected) | `Color(white: 0.7)` | `Color.brandAmberDark` (#B5721F) |
| Saved (default) | `Color.brandOrange` | `Color.pinSaved` (#81C784 — light green) |
| Saved (selected) | `Color.brandOrangeDark` | `Color.pinSavedDark` (#66BB6A) |
| Walked (default) | `Color.walkedGreen` (#4CAF50) | `Color.walkedGreen` (#4CAF50 — no change, already bright) |
| Walked (selected) | `Color.walkedGreenDark` | `Color.walkedGreenDark` (no change) |

**Progress card header** in `MapTab.swift` (`ProgressCard`):

```swift
// Change:
.background(Color.brandOrange)
// To:
.background(Color.brandAmber)
```

**Files:** `AppColors.swift`, `TeardropPin.swift`, `MapTab.swift`

### B2. Top Bar Redesign — Settings Gear + Stairs Icon

Move the settings gear icon from the Progress tab toolbar into the Map tab's orange (now amber) top bar. Add a stairs icon in the center of the top bar.

**Current top bar** (in `MapTab.topBar`): search icon + location icon on the right.

**New top bar layout:**

```
[                    🪜 (stairs icon, center)              ⚙️ (gear)  🔍  📍 ]
```

- **Center:** A stairway/stairs icon. Use the app's `StairShape` rendered small (e.g., 18x18) in white, or use SF Symbol `"figure.stairs"` (available iOS 17+). This is decorative/branding, not tappable.
- **Right side (trailing):** Settings gear button (opens SettingsView sheet) + existing search button + existing location button.

**In `MapTab.swift`, modify `topBar`:**

1. Add `@State private var showSettings = false` to MapTab
2. Add the gear button to the trailing HStack (before search and location buttons)
3. Add center stairs icon using `figure.stairs` SF Symbol or the custom `StairShape`
4. Add `.sheet(isPresented: $showSettings) { SettingsView() }` to the MapTab body

**In `ProgressTab.swift`:** Remove the settings gear button from the toolbar. Keep the sync status icon. The settings gear now lives in the Map tab top bar only.

**Files:** `MapTab.swift`, `ProgressTab.swift`

### B3. Splash Screen Fix + Longer Duration

**Current state:** `SplashView` references `Image("splash_image")` but no `splash_image` asset exists in `Assets.xcassets`. Result: just a flat amber screen.

**Fix option 1 (preferred):** Replace the missing image reference with the app's `StairShape` rendered large and centered, in white, on the amber background. This matches the app icon motif and requires no external asset.

```swift
struct SplashView: View {
    var body: some View {
        ZStack {
            Color.brandAmber  // unified accent color
                .ignoresSafeArea()

            StairShape()
                .fill(Color.white)
                .frame(width: 120, height: 120)
        }
    }
}
```

**Fix option 2 (if Oscar adds an image later):** Keep the `Image("splash_image")` code but add a fallback. For now, use option 1.

**Longer splash duration:** In `SFStairwaysApp.swift`, change the delay from 1.5 seconds to 2.5 seconds:

```swift
// Change:
DispatchQueue.main.asyncAfter(deadline: .now() + 1.5)
// To:
DispatchQueue.main.asyncAfter(deadline: .now() + 2.5)
```

**Also update the splash background color** to use `brandAmber` instead of the hardcoded amber RGB (they're the same value, but use the named color for consistency).

**Files:** `SplashView.swift`, `SFStairwaysApp.swift`

## 3. Business Rules

- Amber (#D4882B) is the app's primary accent color
- Unsaved stairways show as amber pins (matching the app accent)
- Saved stairways show as light green pins
- Walked stairways show as bright green pins
- Settings is accessible from the Map tab top bar (not Progress tab)

## 4. Data Model / Schema Changes

Run `supabase/schema.sql` in Supabase Dashboard (manual step, not a code change). Creates: `user_profiles`, `stairway_catalog`, `walk_records`, `walk_photos`, `curator_commentary`, `photo_likes`, plus triggers, indexes, and RLS policies.

## 5. UI / Interface

- Top bar: amber background, stairs icon centered, gear + search + location icons trailing
- Splash: amber background with white StairShape centered, 2.5s duration
- Map pins: amber (unsaved), light green (saved), bright green (walked)
- Progress card header: amber background
- Filter pill "All": already amber, no change

## 6. Integration Points

- Supabase: schema must be run before Sign in with Apple will work
- The `StairShape` from `TeardropPin.swift` is reused in the splash screen

## 7. Constraints

- iOS 17+ (SF Symbol `figure.stairs` available)
- No new asset files needed (splash uses code-rendered StairShape)
- `brandOrange` stays defined in AppColors but is demoted from primary accent role
- The Supabase schema run is a one-time manual step

## 8. Acceptance Criteria

- [ ] `supabase/schema.sql` has been run in Supabase Dashboard (Oscar manual step)
- [ ] Sign in with Apple completes successfully after schema is run
- [ ] Top bar is amber, with stairs icon centered and gear/search/location trailing
- [ ] Settings sheet opens from gear icon in Map tab top bar
- [ ] Settings gear is removed from Progress tab toolbar
- [ ] Splash screen shows white StairShape on amber background for 2.5 seconds
- [ ] Unsaved pins are amber circles on the map
- [ ] Saved pins are light green circles
- [ ] Walked pins are bright green circles
- [ ] Progress card header is amber
- [ ] No regressions in map interaction, filtering, or bottom sheet
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Resources/AppColors.swift` — change `topBarBackground` to `brandAmber`
- `ios/SFStairways/Views/Map/TeardropPin.swift` — update `fillColor` for all pin states
- `ios/SFStairways/Views/Map/MapTab.swift` — redesign `topBar`, add settings sheet, update ProgressCard header color
- `ios/SFStairways/Views/Progress/ProgressTab.swift` — remove settings gear from toolbar
- `ios/SFStairways/Views/SplashView.swift` — replace broken image with StairShape, use brandAmber
- `ios/SFStairways/SFStairwaysApp.swift` — increase splash duration to 2.5s
