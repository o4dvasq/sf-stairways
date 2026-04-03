# Architecture Decisions — sf-stairways

## Tag pill colors: persisted colorIndex on model, shared palette in AppColors
**Date:** 2026-04-03

**`colorIndex: Int` persisted on `StairwayTag`, not computed at render time.** The alternative — deriving a color from the tag's string ID or name (e.g. `abs(name.hash) % 12`) — would give stable colors without a new property. But it couples the color to the slug/name and makes reassignment impossible. Persisting the index on the model is the correct SwiftData pattern: the color is a data attribute, not a view concern.

**Default value of `0` (rose) for existing tags — no migration script.** SwiftData lightweight migration handles adding a property with a default value. Existing tags will all appear rose initially; the spec notes this is acceptable since users likely have few custom tags. A one-time migration to randomize existing tags was considered and rejected — it adds complexity and the problem self-heals when users next open the TagEditorSheet (they can see the pill color before assigning).

**Warm yellow and lemon darkened ~15% in the palette definition.** Rather than computing a brightness-adjusted variant at render time, the darkened values are baked directly into `tagPalette`. This keeps the rendering code simple (just index lookup, no Color manipulation), and the adjustment is a one-time design decision — not something that needs to be dynamically recalculated.

**`Color.tagPalette` defined in `AppColors.swift`, not pulled from `NeighborhoodStore`.** The spec considered reusing `NeighborhoodStore`'s palette directly, but that would couple the tag system to the neighborhood system at the type level. Duplicating (or re-defining) the 12 colors in `AppColors` keeps the two concerns independent. The colors happen to be the same visual palette, but their purpose and ownership are different.

**Active state in `TagFilterSheet` shown via white stroke overlay, not color change.** The fill color is the tag's identity — changing it on selection would break the color-as-identity contract. A white `Capsule()` stroke at 0.6 opacity reads clearly against any of the 12 palette colors while preserving the tag's color identity.

## Mark Walked celebration: animation-via-withAnimation, symbolEffect, surfaceWalked token
**Date:** 2026-04-02

**`withAnimation` wrapping `modelContext.save()` to drive SwiftData-triggered view animations.** `@Query` delivers updates synchronously on the main thread when `modelContext.save()` is called. Wrapping the save in `withAnimation(.easeInOut(duration: 0.4))` places that update inside an animation transaction, which the `.animation(_, value: isWalked)` modifiers pick up. This is the correct pattern for animating SwiftData state changes — calling `withAnimation` on the save site, not at the observation site.

**Background color on the ScrollView, not `.presentationBackground()`.** `.presentationBackground()` is not animatable (it's a view preference). Applying `.background(color.ignoresSafeArea())` directly to the ScrollView gives the same full-sheet visual result and supports smooth animation via `.animation(_, value: isWalked)`. The grab handle pill area (a few pixels at the top) may remain system-colored, but it's imperceptible in practice.

**`.symbolEffect(.bounce, value: isWalked)` for checkmark animation.** iOS 17's symbol effects are the idiomatic way to animate SF Symbols. The bounce fires when `isWalked` changes to true (the symbol just appeared, so the effect plays on insertion). On unmark, the symbol disappears via transition so no reverse bounce occurs. No manual scale state needed.

**`surfaceWalked` as an AppColors token, not an inline literal.** Adding `#F0FAF1` / dark forest tint as a named token keeps the color system consistent and makes it easy to tune across the app. The dark mode value (`28/46/30` RGB) is a very dark green tint — subtle enough to be legible but clearly different from the system background.

## Neighborhood rewards: derived badge state, static fact JSON, no persistence
**Date:** 2026-04-02

**Badge state is derived, not stored.** A neighborhood is "complete" when walked stairway count equals total stairway count. This is already computed in `ProgressTab` and `NeighborhoodDetail` — no new SwiftData model, no migration, no CloudKit schema changes needed. The badge is a presentation layer concern only.

**Static JSON for fact content.** `neighborhood_facts.json` is a bundle resource with 28 manually-curated facts (18 neighborhood-specific, 10 global). The hybrid approach the spec considered — dynamic computed facts vs. static trivia — was resolved by noting that the most interesting facts are historical and architectural, not derivable from the stairway catalog. Computed facts like "N of M in this neighborhood" are already shown by the progress bar, so nuggets should add new information, not restate what's already visible.

**Day-of-year seed for global rotation.** The global fact in `ProgressTab` rotates daily using `Calendar.current.ordinality(of: .day, in: .year, for: Date())` as a seed into the global facts array. This is stable within a session (no flash/change on redraw), changes every day, and requires no persistent state. A `@State` variable or `@AppStorage` counter would add complexity for no benefit.

**Map polygon treatment: color swap, not overlay.** Completed neighborhoods replace the neighborhood's assigned color with `Color.walkedGreen` entirely, rather than adding a separate overlay layer. This is simpler (one ForEach, no Z-stacking), avoids color mixing artifacts, and makes the "done" state visually unambiguous. The 35%/65% fill/stroke opacities for completed neighborhoods are slightly higher than the base 30%/50% to ensure the green reads clearly without dominating the map.

## Hard Mode: UserDefaults-only, Supabase sync removed
**Date:** 2026-04-02

**Hard Mode was never a social or cloud-dependent feature.** The original implementation synced the `hardModeEnabled` preference to `user_profiles.hard_mode_enabled` in Supabase and blocked the toggle behind auth. This added friction with no benefit — the setting is a personal preference, not something other users or the server needs to know. It also silently failed for signed-out users (toggle was grayed out).

**UserDefaults is the correct store.** Preferences that gate local app behavior (`hardModeEnabled`) belong in `UserDefaults`, not a remote database. The proximity check at mark time is entirely local — `LocationManager.isWithinRadius`. Syncing a boolean that only affects one device to a server was over-engineering.

**`loadProfile()` no longer overwrites the local preference.** Previously, signing in would clobber the user's current Hard Mode state with whatever was in Supabase. This meant a user who had Hard Mode on, signed in, and found the preference reset had no explanation. Removing that overwrite makes the preference stable across auth state changes.

**Verified count in Progress tab rewards without shaming.** Showing a "N verified" count only when `verifiedCount > 0` means Hard Mode users see a quiet acknowledgment of precision walks. Users who never use Hard Mode see nothing different. "0 verified" would be confusing or punitive for the latter group.

## Share card redesign: brand-on-photo approach, neighborhood progress as hook
**Date:** 2026-04-02

The share card redesign prioritises making every card look intentional and branded, even when the photo is mediocre.

**Amber frame as brand signal, not decoration.** A 16pt `brandAmber` border around the inset photo creates a deliberate framing that reads as "this came from an app" rather than a raw screenshot. The same amber tone is used across the app (pins, badge, header), so it communicates the brand without extra copy.

**Logo overlay on photo rather than a separate logo strip.** Instead of allocating vertical space for a header logo row, the `StairShape` + "SF Stairways" text sits directly on the photo at top-left behind a semi-transparent dark pill. This follows Strava's card convention: brand marks the image, not a separate panel. The dark pill at 42% opacity is legible on both dark and light photos without evaluating the photo contents.

**Neighborhood progress as the shareable hook.** The "N of M in [Neighborhood]" element turns a personal photo share into a mission update — "I'm working through Bernal Heights." Without it the card communicates only "I went somewhere." With it, it communicates commitment and progress, which is why someone would actually share.

**Per-stairway `StairwayStore` instance in `StairwayBottomSheet`.** The neighborhood count computation requires `StairwayStore.stairways(in:)`. Rather than passing the store down through call sites or adding it to the environment, `StairwayBottomSheet` creates its own `@State private var store = StairwayStore()` — consistent with the pattern used by `ListTab`, `ProgressTab`, and others. Instantiating multiple stores is cheap (reads a ~50KB JSON file once).

**No-photo layout promotes stairway name to the orange content area.** When there's no photo, the orange/amber section has nothing to show. Moving the stairway name and neighborhood into that area (white text on orange) gives the card a headline-poster feel and keeps the bottom panel consistent and compact across both variants.

## Share card: ImageRenderer + UIActivityViewController, no direct social posting
**Date:** 2026-04-02

Share cards are generated entirely on-device via SwiftUI `ImageRenderer` at 3× scale (360×640pt → 1080×1920px, 9:16 for Instagram Stories). No backend, no image uploads, no network requests.

**`UIActivityViewController` over `ShareLink`.** SwiftUI's `ShareLink` doesn't cleanly support sharing both a `UIImage` and a plain string in a single item array — it's designed for `Transferable` types. Wrapping `UIActivityViewController` gives full control over `activityItems` and lets us pass image + text together so apps like Messages receive both.

**Photo source: first local `WalkPhoto` only.** Remote Supabase photos require async loading and could delay card generation. The spec says "fall back to no-photo variant rather than blocking." Using the first local `WalkPhoto.imageData` (synchronously available from SwiftData external storage) achieves instant card generation. In practice, most walks with photos will have at least one local photo.

**Card color uses light-mode `brandOrange` value (`#D4724E`) rather than spec's `#E8602C`.** The spec cited a hex that doesn't match the app's established color tokens. The actual `brandOrange` (light mode: `#D4724E`) is what users see in the running app, so the card matches the app rather than an abstract spec color.

## Landing page replaces deprecated web app at repo root
**Date:** 2026-04-02

The Leaflet-based web app (`index.html`) was moved to `legacy/index.html` and replaced with a static marketing landing page targeting TestFlight beta signups.

**Single HTML file per page, no JS.** The landing page and privacy policy are pure HTML + inline CSS. No framework, no bundler, no JavaScript (not even scroll polyfills). Google Fonts CDN is the only external dependency. This keeps load time minimal for the primary audience: iPhone users tapping a shared link.

**Instrument Serif + DM Sans typography.** Per spec, system-default fonts (Inter, Roboto, system-ui) were explicitly excluded. Instrument Serif (display/headlines) + DM Sans (body) give the page a distinctive editorial feel that matches the app's warm aesthetic.

**TestFlight CTA is a placeholder.** The "Join the Beta" button links to `https://testflight.apple.com/join/PLACEHOLDER`. Oscar will update this manually once the TestFlight public link is live — no code change needed.

**Hero image served from Unsplash CDN.** Using an external CDN URL keeps the repo lean (no binary assets committed). Oscar will replace with original SF stairway photography at a later date.

**Privacy policy required for external TestFlight.** Apple requires a reachable privacy policy URL for external TestFlight distribution. `privacy.html` accurately reflects the app's data practices: local SwiftData, iCloud CloudKit sync, optional Supabase auth token, no analytics, no server-side photo storage.

## Remove step-count tracking entirely
**Date:** 2026-03-31

Step counts (both HealthKit-sourced and curator-entered) were removed from all models, views, and services. Steps proved unreliable and redundant — height (feet climbed) is the only meaningful physical metric. If a stairway has no height data, the count will be measured manually and height calculated outside the app.

`WalkRecord.stepCount` and `StairwayOverride.verifiedStepCount` were removed from the SwiftData models. CloudKit handles schema evolution gracefully — existing records with the fields are simply ignored. No migration needed. The `step_count` field remains in the static JSON data files (untouched) but the app no longer reads it.

## Remove HealthKit and active walk recording entirely
**Date:** 2026-03-30

The app dropped all HealthKit integration and the "Start Walk / End Walk" active session flow. The app is a stairway exploration tracker, not a fitness logger — walk data enrichment (elevation) will happen after the fact via curator override fields on the Mac admin dashboard.

**WalkRecord schema fields retained.** `elevationGain`, `walkStartTime`, `walkEndTime` remain as nullable SwiftData properties. Removing SwiftData properties that exist in CloudKit causes migration failures on devices that have already synced data. Existing values (from past active walks) are preserved and visible in the Mac detail panel labeled "Walk Data (legacy)." No new code writes to these fields.

**"Mark Walked" is the sole logging action.** The hard mode proximity check, dateWalked stamping, and confirmation toast are fully preserved. Nothing about the manual walk flow changed.

**`PhotoSuggestionService` simplified.** The `walkStartTime`/`walkEndTime` parameters that narrowed the photo suggestion time window to the active session are gone. The service now always uses the full calendar day of `dateWalked` as the search window. This is correct behavior: manual walks don't have a precise time, so a full-day window is the right default.

**Data hygiene "Missing HealthKit Data" category removed.** This check flagged walked stairways with no stepCount or elevationGain. Since HealthKit no longer populates these fields, the category would flag every stairway — it was noise.

## Progress tab: neighborhood cards as hero content, StairwayStore as data source
**Date:** 2026-03-29

The Progress tab now centers neighborhoods as the primary progress unit rather than global percentage. Key decisions:

**StairwayStore (not NeighborhoodStore) drives card data.** The card grid is computed by grouping `store.stairways` by `stairway.neighborhood` — the same string field used everywhere else in the app. `NeighborhoodStore` is in the environment (used by `NeighborhoodDetail` for GeoJSON polygon lookups) but is not used to drive the card list. This avoids a dependency on GeoJSON name alignment and ensures cards only show neighborhoods that actually have stairways in the catalog.

**String as NavigationLink value.** `NavigationLink(value: card.name)` with `.navigationDestination(for: String.self)` keeps the Progress tab's NavigationStack self-contained. `NeighborhoodDetail` receives a `neighborhoodName: String` and resolves everything internally — no model objects need to cross the navigation boundary.

**StatCard deleted.** The 2x2 stat grid (height, steps, neighborhoods, walk days) was removed. Steps was unreliable (HealthKit issues); walk days wasn't earning its space. Height and neighborhood count are now in the compact summary alongside the ring. StatCard was only used within ProgressTab, so it was deleted outright rather than kept as dead code.

## HealthKit: check-first before re-requesting auth, retry on nil results
**Date:** 2026-03-29

`fetchWalkStats` now calls `isAuthorized()` first and only calls `requestAuthorization` if not yet granted. Re-requesting authorization when already granted can throw in certain states (background execution, HealthKit store temporarily unavailable) — this caused the silent nil return that was masking successful walks.

A 2-second post-walk delay (up from 1s) and a single retry after another 2s handle the common case where HealthKit needs extra time to flush pedometer data after motion stops. The retry adds up to 4s total latency in the failure case, which is acceptable for an end-of-walk flow.

`fetchWalkStats` now returns `(steps: Int?, elevationFeet: Double?, error: String?)`. The caller (`endWalkSession`) shows the specific error string in the toast rather than a generic "could not read Health data" message. This gives actionable feedback: authorization failure → Settings guidance; no data → "try a longer walk."

## NeighborhoodDetail: label-tap instead of polygon-tap, mixed sheet/push navigation
**Date:** 2026-03-29

**Polygon tap fallback.** SwiftUI's `@MapContentBuilder` doesn't support distinguishing polygon area taps from pin annotation taps reliably — adding a `.onTapGesture` to the Map view intercepts all taps before annotations receive them, breaking pin behavior. The spec anticipated this and provides an explicit fallback: polygon overlays are visual-only, and neighborhood centroid label `Annotation` views are the tap target. This is the approach implemented.

**Mixed navigation: sheet vs. push.** `NeighborhoodDetail` is presented differently depending on the entry point. From MapTab (no NavigationStack in scope) and StairwayBottomSheet (already inside a sheet), it's wrapped in a new `NavigationStack` and presented as a sheet. From ListTab and SearchPanel (both have NavigationStacks), it's pushed via `NavigationLink(value:)` with a `navigationDestination(for: String.self)` on the containing list. This avoids making the map view context a NavigationStack (which would conflict with the tab bar) while still getting push semantics where appropriate.

**Neighborhood name as String identity.** `NeighborhoodDetail` receives a `neighborhoodName: String` and resolves everything internally via `NeighborhoodStore` + `StairwayStore`. This avoids threading the full `Neighborhood` model across unrelated views and keeps entry points simple.

**SearchPanel neighborhood behavior change.** The Neighborhood tab in Search previously called `onSelectNeighborhood(group.name)`, which switched to the Map tab and flew to the neighborhood. This is now replaced with `NavigationLink(value:)` → push `NeighborhoodDetail` directly, which has its own embedded map. The `onSelectNeighborhood` callback is still wired in `ContentView` for `coordinator.pendingNeighborhood` but is no longer called from the Neighborhood results tab.

## SF 311 Neighborhoods over DataSF Analysis Neighborhoods
**Date:** 2026-03-29

`sf_neighborhoods.geojson` now contains the SF 311 Neighborhoods dataset (117 polygons, property key `name`) rather than the DataSF Analysis Neighborhoods dataset (41 polygons, property key `nhood`).

**Why 311, not Analysis.** The Analysis dataset merges locally-recognized neighborhoods into large census-tract groupings — Forest Hill disappears into "West of Twin Peaks," Eureka Valley into "Castro/Upper Market," Clarendon Heights into "Twin Peaks." Residents don't identify with those merged names. The 311 dataset (defined in 2006 by the Mayor's Office of Neighborhood Services) preserves the granular names SF residents actually use, giving the app real neighborhood-level identity: 68 distinct neighborhoods with stairways vs. 34 before.

**Migration approach.** 367 of 382 stairways were re-assigned via point-in-polygon against the new boundaries (0 centroid fallbacks — perfect coverage). The 15 stairways with null coordinates were manually assigned by stairway ID based on street intersections. The old `NO_COORDS_MAPPING` dict (by old neighborhood name) was replaced by `NO_COORDS_MANUAL` (by stairway ID) for precision. Color palette expanded from 8 → 12 pastel colors to reduce adjacent-neighborhood color collisions across the larger set.

## NeighborhoodStore: GeoJSON-backed, computed at startup, injected via environment
**Date:** 2026-03-29

Neighborhood data (centroids, adjacency, polygon lookup) is now computed at app startup from a bundled `sf_neighborhoods.geojson` rather than loaded from two pre-computed static JSON files (`neighborhood_centroids.json`, `neighborhood_adjacency.json`).

**Why GeoJSON instead of pre-computed JSONs.** The pre-computed files were one-off outputs from a Python script and would go stale whenever the neighborhood boundaries changed. Computing centroids and adjacency from the GeoJSON polygons at startup eliminates the separate build step, removes two files from the bundle, and makes the data flow transparent: source of truth is the GeoJSON, everything else is derived.

**Why in-memory struct, not SwiftData.** Neighborhood boundary polygons are read-only reference data, not user data — they never change at runtime and don't need to sync via CloudKit. SwiftData is reserved for user-generated state (WalkRecord, StairwayOverride, etc.). An in-memory `@Observable` class (`NeighborhoodStore`) loaded at startup is the right layer.

**Why pass store at call site, not at init.** `AroundMeManager` is a `@State` property initialized before `@Environment` is accessible. Rather than a lazy init pattern or optional unwrapping, the store is passed as a parameter to `activate(location:store:)`. This keeps `AroundMeManager` init-time simple and makes the dependency explicit at the call site.

**Adjacency algorithm: grid-bucketed shared vertices.** Two neighborhoods are adjacent if any vertex of one polygon falls within ~100m of any vertex of another. Vertices are snapped to a `0.001°` grid (~90m at SF latitude); any grid cell shared by 2+ neighborhoods marks those neighborhoods as adjacent. This is O(n·v) where v is total vertex count and is fast enough for 41 neighborhoods at startup.

## DataSF Analysis Neighborhoods: migration from 53 scraped names
**Date:** 2026-03-29

`all_stairways.json` was migrated from 53 hand-scraped neighborhood names (inconsistent, not geometry-backed) to 41 official DataSF Analysis Neighborhood names. Migration algorithm: point-in-polygon (ray casting) for 367 stairways with coordinates; manual name mapping for 15 stairways without coordinates. Result: 34 DataSF neighborhoods with at least one stairway; 7 have none (e.g. Golden Gate Park, Presidio, Treasure Island).

**Why DataSF Analysis Neighborhoods, not SF Planning neighborhoods or others.** Analysis Neighborhoods are the standard city-wide statistical unit used in official SF data products. They have stable names, public GeoJSON, and match what residents recognize. The SF Chronicle data team maintains a mirror that was used for the download.

## StairwayDeletion: soft delete via CloudKit-synced model
**Date:** 2026-03-29

Deleting a stairway from the field hides it across all devices by inserting a `StairwayDeletion` SwiftData record rather than modifying the bundled JSON (which is read-only at runtime). The `StairwayStore.stairways` computed property filters out any stairway whose ID appears in `deletedIDs`.

**Why not hard delete from JSON.** `all_stairways.json` is a bundled resource — it cannot be modified at runtime. Even if it could, changes wouldn't sync across devices. The soft-delete model syncs instantly via the shared CloudKit container, affecting all three targets simultaneously.

**Why a dedicated model, not a flag on StairwayOverride.** `StairwayOverride` models corrections (step count, height, description). Deletion is a lifecycle concept, not a data correction — mixing them would complicate the StairwayOverride schema and make restore operations ambiguous. An independent model with `@Attribute(.unique)` on `stairwayID` ensures no duplicate deletion records.

**Why views call applyDeletions in onAppear + onChange.** `StairwayStore` is an `@Observable` non-SwiftData class that doesn't automatically react to `@Query` changes. Views that own a `@Query private var deletions: [StairwayDeletion]` call `store.applyDeletions(deletions.map(\.stairwayID))` in `.onAppear` and `.onChange(of: deletions)` to keep the exclusion set in sync.

## Visual refresh: UIColor dynamicProvider for adaptive color tokens
**Date:** 2026-03-29

Adaptive light/dark colors for the new surface and brand tokens are defined in `AppColors.swift` using `Color(UIColor { traits in ... })` — UIKit's dynamic provider closure. This runs at render time so colors update automatically when the system color scheme changes.

**Why not asset catalog.** Asset catalog adaptive colors require Xcode's GUI editor and ship as `.xcassets` — not editable via code alone. Dynamic provider achieves the same at-render-time resolution with zero asset catalog overhead, keeping all color definitions in one Swift file.

**Why not SwiftUI environment.** `Color` static properties (`Color.surfaceBackground`) need to be usable everywhere — in `ShapeStyle` expressions, as `background()` modifiers, etc. Environment-based adaptive values require a `View` body, which breaks the static-property access pattern used throughout the app.

**`#if canImport(UIKit)` guard.** AppColors.swift is compiled into the macOS target too. UIKit is not available on macOS (AppKit is used instead). The guard keeps the file compilable on both platforms; macOS uses non-adaptive Color literals for the tokens.

## Visual refresh: Rounded typography via UINavigationBarAppearance
**Date:** 2026-03-29

SF Pro Rounded is applied to navigation bar large titles and inline titles via `UINavigationBarAppearance` in ContentView's `.onAppear`. This is global state that affects all nav bars in the app, which is the intended outcome (consistent Rounded headings everywhere).

In SwiftUI view bodies, `.font(.system(.body, design: .rounded))` applies Rounded directly. Navigation titles require the UIKit appearance API — there is no SwiftUI modifier for nav bar title font. `UIFont(descriptor:withDesign:.rounded)` is used with a size of 0, which preserves Dynamic Type scaling.

## HealthKit authorization status: statusForAuthorizationRequest as proxy
**Date:** 2026-03-28

HealthKit does not expose read authorization status for read-only types — `authorizationStatus(for:)` always returns `.sharingDenied` for read-only types (iOS privacy protection). There is no direct API equivalent of "did the user say yes to Health read access?"

**Chosen proxy: `statusForAuthorizationRequest(toShare:read:)`.** This async method returns `.unnecessary` once the authorization prompt has fired (regardless of the user's choice) and `.shouldRequest` before it has. We use `.unnecessary` as the "HealthKit connected" signal in the Settings view: it means the user has been asked and made a decision (step and elevation queries will run; whether they return data depends on what the user allowed, not on the status enum). If the user has never been asked (`.shouldRequest`), we show "Not Authorized" and a "Request Permission" button.

**Why not attempt a test query.** Running a real HealthKit query at Settings-view-open time just to check authorization adds latency and potentially background activity. The `statusForAuthorizationRequest` call is fast, async, and semantically correct for our purpose.

**`requestAuthorization()` as a public method.** The existing private `requestAuthorization(store:types:)` was exposed via a new public static `requestAuthorization()` for use from the Settings "Request Permission" button. If already determined, it completes instantly with no dialog — so tapping the button after prior denial opens nothing (expected behavior; directing users to iOS Settings > Health is the correct path for re-authorization but is not implemented, as it's an edge case for a personal app).

## Hard Mode: confirmation prompt over button disabling
**Date:** 2026-03-28

The original Hard Mode spec disabled the Mark Walked button when the user was >150m from the stairway. This was punitive UX — users with Hard Mode on couldn't log a walk at all from a distance, even if they genuinely walked it and just forgot to log it in time.

**Confirmation prompt approach.** Mark Walked is now always enabled. When Hard Mode is ON and the user is >150m away, tapping fires a `.alert("Mark as walked?")` with a "Mark Anyway" path that logs with `proximityVerified = false`. Within 150m, it marks immediately with `proximityVerified = true`. Hard Mode OFF marks with `proximityVerified = nil` (no Hard Mode context).

**Start Walk remains proximity-gated.** Unlike Mark Walked, Start Walk implies you are physically beginning a session at the stairway. The gate was preserved there via a renamed `isStartWalkDisabled` property (same logic, different name). Active Walk Mode completion always sets `proximityVerified = true` — starting a session is proof of presence.

**`xmark.seal.fill` badge, not `exclamationmark.triangle.fill`.** The triangle felt harsh for a soft signal ("you logged this from a distance"). The seal shape matches the `checkmark.seal.fill` verified badge exactly in shape and size, just amber+xmark instead of green+checkmark. Same visual vocabulary — unverified is the inverse of verified, not an error.

## Stairway Tags: TagAssignment as independent model, FlowLayout for pill grids
**Date:** 2026-03-28

Tags are stored as two independent SwiftData models (`StairwayTag` + `TagAssignment`) rather than as an array field on `WalkRecord` or `Stairway`.

**Why independent of WalkRecord.** Tags are an annotation on a *place*, not a *walk event*. A stairway can be tagged before it's ever walked, and tags should survive if a walk record is deleted or reset. Keying by `stairwayID` (same pattern as `StairwayOverride`) gives tags a lifecycle independent of walk state — no cascading deletes, no ordering ambiguity.

**Why not embed tags on Stairway.** `Stairway` is a value type loaded from a bundled JSON file — it's read-only catalog data. Mutable user annotations must live in SwiftData, not in the static catalog.

**Slug-based IDs.** Tag IDs are lowercase slugs derived from the name (spaces → hyphens, non-alphanumeric stripped). This makes preset tags human-readable in the data store, avoids UUID collision with user-created tags that happen to have the same name as a preset (they'll share the same ID and thus the same `StairwayTag` row), and is stable across devices because CloudKit delivers the same `id` string.

**FlowLayout via SwiftUI Layout protocol.** A custom `FlowLayout: Layout` wraps pill buttons into rows, respecting variable pill widths. `LazyVGrid(.adaptive(minimum:))` was rejected because it makes all cells the same width — pill widths should be content-driven. The `Layout` implementation is ~30 lines and works on iOS 16+ (app targets iOS 17+). It's defined in `TagEditorSheet.swift` and used by both the editor sheet and the filter sheet.

**Single-select tag filter on the map.** The spec allows exactly one active tag filter at a time for the map. Multi-select AND logic would quickly produce empty result sets (most tags have a handful of assignments), making the feature feel broken. Single-select keeps the mental model simple: "show me stairways with this tag." The AND with the state filter is already one level of compounding; adding multi-tag AND on top would create a combinatorially empty UI with no good recovery path.

**State-filter drop on zero AND results, not a user-configurable OR.** When the AND of state + tag yields zero, the app silently drops the state filter and shows all tagged stairways, with a toast explaining what happened. An OR mode was rejected because it would require a different filter paradigm (radio buttons → checkboxes → OR/AND toggle) and significantly complicate the UI. The drop behavior is transparent and self-explaining via the toast.

## Photo persistence: PhotoSource enum + local-first display with upload dedup
**Date:** 2026-03-28

Two independent bugs caused photos to be invisible in the carousel. Fixed together.

**Bug A — local photos never displayed.** `PhotoCarousel` only received `[SupabasePhoto]`. Local `WalkPhoto` objects in SwiftData were never consulted. Fix: introduced `PhotoSource` enum (`case remote(SupabasePhoto) / case local(WalkPhoto)`), `StairwayBottomSheet` now computes `mergedPhotos: [PhotoSource]` by combining `photoLikeService.sortedPhotos` + `walkRecord.photoArray`, sorted by `createdAt` descending. `PhotoCarousel` accepts `[PhotoSource]` and switches on case for both thumbnail rendering and full-screen viewing.

**Bug B — uploaded photos invisible.** `PhotoInsert` in `PhotoLikeService` omitted `is_public`, which the database defaults to `false`. `fetchPhotos` filters `.eq("is_public", true)`. Fix: added `is_public: Bool` to `PhotoInsert` and sets it to `true` on every upload.

**Dedup strategy: delete local on upload success.** After a successful Supabase upload, the local `WalkPhoto` is deleted from SwiftData. The `SupabasePhoto` returned by the upload is already in `photoLikeService.photos`, so `mergedPhotos` transitions from `[.local(p)]` to `[.remote(p)]` automatically. If upload fails, the local copy persists as offline fallback. This is simpler than date-matching for dedup and avoids keeping stale local copies indefinitely.

**Local badge instead of like overlay.** Local-only photos show a `icloud.slash` icon (bottom-left) in place of the like/count overlay. Like interactions are Supabase-only — local photos have no server-side ID to track likes against.

## Launch zoom to nearest stairway: time-based splash guard over binding
**Date:** 2026-03-28

On first location fix after launch, `MapTab` zooms to the nearest stairway at `latDelta 0.01`. The zoom must not fire while the splash is still visible (splash dismisses at ~2.9s: 2.5s delay + 0.4s fade).

**Time-based guard chosen over `showSplash` binding.** `showSplash` lives in `SFStairwaysApp` — threading it down through `ContentView` → `MapTab` would add a parameter to both intermediate views for a one-time concern. Instead, `MapTab` records `launchTime: Date = .now` and computes `delay = max(0, launchTime + 3.1 - now)` when location first arrives. If the location comes in before splash ends, the zoom is deferred by the remaining window; if it arrives late, delay is 0 and the zoom fires immediately. No coupling to app-level state required.

**`hasZoomedToNearest` set before the async dispatch, not after.** The flag is set to `true` synchronously in the `.onChange` handler, before the `DispatchQueue.main.asyncAfter` closure runs. This prevents a second location update (arriving in the small delay window) from scheduling a second zoom.

## Map pin tap targets and zoom-responsive scaling
**Date:** 2026-03-28

**Tap targets via contentShape, not padding.** The tap gesture lives on `StairwayAnnotation` in `MapTab`. The cleanest way to expand the hit area without changing MapKit annotation layout is to wrap the visual circle in an outer frame of `max(44, pinSize)` and apply `.contentShape(Rectangle())` at that outer frame. Using `.padding()` + `.contentShape(Circle())` was rejected because a circular content shape at 44pt on a 12pt pin leaves the corners dead — a rectangular content shape fills the minimum 44×44pt area uniformly and matches Apple HIG intent.

**Scale factor via lerp, not discrete steps.** Pin size was mapped continuously from 1.0 (city view, `latitudeDelta >= 0.05`) to 2.0 (street level, `latitudeDelta <= 0.005`) using linear interpolation. Discrete size breakpoints (e.g., small/medium/large) would produce visible pops on pinch-zoom. The lerp is a one-line clamp + ratio — trivial to compute on every camera change.

**`.onMapCameraChange(frequency: .continuous)` over `.onEnd`.** Continuous firing gives smooth scale transitions during pinch. The scale computation is a clamp + multiply — no meaningful CPU cost at this granularity. `.onEnd` would cause pins to snap size only after the gesture finishes, which reads as a layout jump.

## Curator promote flow: triggerPromote binding over direct scroll
**Date:** 2026-03-28

The "Promote to Commentary" button in the notes section needed to pre-fill the `CuratorEditorView` with the current note text. Two options considered:

**Option A:** Pass a `promotedNotesText` state down and have the editor load it on appear. Problem: the editor already uses `.onAppear` to load existing Supabase commentary, and competing initializers create ordering ambiguity.

**Option B (chosen):** `@Binding var triggerPromote: Bool` on `CuratorEditorView`. The parent sets it to `true`; the editor's `.onChange` copies `notesText → draftText` and resets the flag to `false`. This is a minimal one-shot signal — no stored value to clean up, no state ambiguity, and compatible with the existing `onAppear` + `onChange(of: service.commentary)` loading logic.

The editor also moved below the notes section (was above). With `ScrollViewReader`, tapping "Promote" scrolls the view down to the editor anchor, making the pre-fill immediately visible.

## Expandable bottom sheet replaces two-view map flow
**Date:** 2026-03-28

The previous map flow used two views: `StairwayBottomSheet` (compact, at `.height(390)`) with a NavigationLink that pushed `StairwayDetail` into a NavigationStack. `StairwayDetail` had its own mini-map at the top — which was redundant since the stairway pin is already visible on the map behind the sheet.

The new design consolidates everything into a single `StairwayBottomSheet` with two sheet detents (`.height(390)` and `.large`). The map itself is the "detail map" — it's always visible behind the collapsed sheet. The expanded sheet (dragged to `.large`) reveals notes, photos, commentary, and curator tools.

**Why self-contained rather than callback-based.** The old bottom sheet received `walkRecord`, `override`, and four action callbacks from `MapTab`. This meant MapTab owned all write logic and the sheet was stateless. The new sheet adds `@Query` and `@Environment(\.modelContext)` directly, owns all write logic, and uses `@Environment(\.dismiss)` to self-dismiss on remove. This removes the callback coupling entirely and lets `ListTab` use the same sheet with zero extra wiring.

**Why the same sheet for ListTab.** `ListTab` previously had a `NavigationLink → StairwayDetail`. Replacing it with `Button → selectedStairway → .sheet(item:)` using `StairwayBottomSheet` means there is now exactly one detail surface in the app. Future changes to detail UI need to happen in one place only.

**`StairwayDetail.swift` deleted.** All content was absorbed into `StairwayBottomSheet`. The mini-map (the only unique element) was intentionally dropped — it was redundant with the map tab itself.

## Map pins: circles replace teardrops; three-state color system restored
**Date:** 2026-03-27

`TeardropShape` inside `StairwayPin` rendered poorly in MapKit's `Annotation` container at small sizes — the rounded top of the teardrop lost definition against the dark map, and the point was clipped. After two rounds of size/shadow tuning, the teardrop was abandoned entirely. `Circle()` is reliable, renders crisply at all sizes, and needs no custom `Shape` path.

Three-state colors were restored (they had been collapsed to solid orange in a prior session): gray `Color(white: 0.55)` for unsaved, `brandOrange` for saved, `walkedGreen` for walked. Selected state uses a darker variant and expands to 24pt. The rationale for collapsing to solid orange (state visible in detail, not map) was valid, but the circles are small enough (12–16pt) that color is the primary legibility signal at map scale — state differentiation is worth the three-color palette at this size.

`TeardropShape` and `StairShape` are kept in `TeardropPin.swift` for future use.

## Curator section gated on curator role, not just walked state
**Date:** 2026-03-27

The "Stairway Info" editor in `StairwayDetail` (stair count, height, description TextFields) was gated only on `isWalked`. This caused every walked stairway to show editable fields with "Add stair count" / "Add height" / "Add description..." prompts to all users — it looked like the app was asking users to manually enter catalog data.

The fix is a single condition change: `if isWalked` → `if isWalked && authManager.isCurator && curatorModeActive`. The `statsRow` already correctly shows public catalog data (`Stairway.heightFt`) and override data with a verified badge for all users — that path is unchanged.

## Auth error surfacing: signInError for Sign in with Apple debugging
**Date:** 2026-03-27

Sign in with Apple was failing silently — the catch block in `handleAppleAuthorization` only printed to the console, giving no visible feedback on device. Added `signInError: String?` as a published property on `AuthManager`. The catch block sets it to `error.localizedDescription`; `SettingsView` renders it in red below the sign-in button.

This is a temporary debug instrument. Once Sign in with Apple is confirmed working (Supabase provider config verified, sign-in completes successfully), remove the `signInError` display from `SettingsView` and clear the property after successful sign-in.

## Sign in with Apple: use SwiftUI button credential directly, no second ASAuthorizationController
**Date:** 2026-03-27

`SignInWithAppleButton` (SwiftUI) delivers the `ASAuthorization` credential in its `onCompletion` handler. The original implementation discarded this credential (`_ in`) and called `authManager.signInWithApple()`, which created a second `ASAuthorizationController` — the second request silently failed or was ignored, leaving the user perpetually signed out.

The fix is to handle the credential where it's delivered: extract the identity token from the `ASAuthorizationAppleIDCredential` in `onCompletion` and pass it directly to `AuthManager.handleAppleAuthorization(_:)`. No second controller is needed. The existing `ASAuthorizationControllerDelegate` implementation is kept for the fallback path but is no longer the primary flow.

## Map pins: remove white shadow, add dark stroke, increase minimum sizes
**Date:** 2026-03-27

White shadow (`.shadow(color: .white.opacity(0.3), radius: 3, y: 0)`) was added in a prior session to give pins visual "lift" on a dark map. In practice it created a hollow/washed-out appearance — the white halo overwhelmed the orange fill at small pin sizes. Removed.

A thin dark stroke (`.stroke(Color.black.opacity(0.4), lineWidth: 1)`) was added instead — this defines the pin edge against the dark map without washing out the fill color.

Pin sizes increased: unsaved 36×45pt, saved/walked 40×50pt, selected 48×60pt (from 30×38 / 36×45 / 42×53). At the previous sizes the teardrop shape was too small to read as a teardrop at typical map zoom levels.

## Web app deprecated in favor of iOS-only
**Date:** 2026-03-25

The web app (`index.html`) was a prototype that proved out the concept: interactive map of SF stairways with walk logging. Now that the iOS app has feature parity and native advantages (camera, GPS, CloudKit sync, offline), maintaining two codebases for one user provides no value. The iOS app is the sole platform going forward. `index.html` remains in the repo for reference but receives no further development.

## Three-state stairway model (Unsaved / Saved / Walked) replaces target list
**Date:** 2026-03-25

The original "target list" was a static JSON file with 13 pre-selected stairways. This was a bootstrapping mechanism, not a real feature. The three-state model makes saving dynamic: users discover stairways on the map and bookmark them for later. The existing `WalkRecord` model already supports this — a record with `walked = false` is the "Saved" state. No schema change needed. This also lays the groundwork for future gamification (progress tracking, completion percentages, streaks) without requiring another data model change.

## MapKit over Mapbox for iOS
**Date:** 2026-03-25

The original web-focused spec proposed Mapbox GL JS. For iOS, MapKit is the right choice: it's free with no usage limits, already integrated, handles pin annotations natively, and integrates with Core Location. Mapbox iOS SDK would add a CocoaPod/SPM dependency, a token management requirement, and usage-based billing, all for capabilities MapKit already provides.

## Pre-computed neighborhood adjacency over runtime polygon intersection
**Date:** 2026-03-25

The "Around Me" feature needs to know which SF neighborhoods border the user's current neighborhood. Computing polygon intersections at runtime (the Turf.js approach from the web spec) is unnecessary overhead on a mobile device. Instead, a Python build script pre-computes the adjacency map once and bundles it as static JSON. The app does a simple dictionary lookup at runtime. Simpler, faster, no geometry library needed in Swift.

## Centroid-based neighborhood detection over GeoJSON point-in-polygon
**Date:** 2026-03-25

The spec originally called for DataSF neighborhood polygons and point-in-polygon lookup to determine the user's current neighborhood. The DataSF "Analysis Neighborhoods" dataset (37 neighborhoods) does not match the stairway data's 53 neighborhood names (sourced from sfstairways.com scraper). Rather than maintain a mapping between two neighborhood schemas, we use nearest-centroid detection: the centroid of each neighborhood is computed from its stairways' coordinates, and the user's neighborhood is the one with the nearest centroid. This is more accurate for this specific dataset, requires no external polygon data, and the Python build script generates `neighborhood_centroids.json` from `all_stairways.json` directly.

## Single-file HTML app (no build step)
**Date:** 2026-03-22 [retroactive]

The entire app lives in `index.html` — HTML, CSS, and JS in one file. No bundler, no npm, no dependencies to install. This keeps local dev trivially simple (`python3 -m http.server 8080`) and GitHub Pages deployment instant (just push). The app is small enough that a single file is easy to navigate, and there's no team coordination overhead to justify a build pipeline.

## Leaflet.js over Google Maps
**Date:** 2026-03-22 [retroactive]

Leaflet is free with no API key required, which eliminates key management and billing risk for a personal project. OpenStreetMap tiles are sufficient for stairway navigation. Google Maps would add complexity (billing account, key restrictions) without any meaningful benefit at this scale.

## GitHub Contents API for persistence (no backend)
**Date:** 2026-03-22 [retroactive]

Walk data is written directly from the browser to `data/target_list.json` using the GitHub REST API. The user stores a Personal Access Token in `localStorage`. This gives us durable, version-controlled persistence with zero infrastructure. No server, no database, no hosting costs. The tradeoff is that the GitHub PAT needs repo write scope and is per-device, but for a single-user personal app this is fine.

## Cloudinary for photo storage (free tier, unsigned uploads)
**Date:** 2026-03-22 [retroactive]

Photos are uploaded directly from the browser to Cloudinary using an unsigned upload preset — no API secret needed in the app. Cloudinary's free tier (25 GB storage, 25 GB bandwidth/month) is more than sufficient for a personal stairway photo collection. The Cloudinary URL is written back to `target_list.json` via the existing GitHub API flow.

## Multi-user backend: Supabase
**Date:** 2026-03-23

Supabase (PostgreSQL + Auth + Storage) chosen over CloudKit public database and Firebase for the multi-user App Store version. CloudKit public DB was rejected because it requires users to be signed into iCloud (drops off potential users), has no real access control layer, and has no path for server-side logic. Firebase was rejected due to Google ecosystem lock-in and unpredictable per-read pricing. Supabase provides Row Level Security for per-user data isolation, Sign in with Apple support, S3-compatible photo storage, and a free tier that covers 0–100 users at zero cost. PostgreSQL means no vendor lock-in. See `docs/ARCHITECTURE_MULTI_USER.md` for full rationale and schema.

## Multi-user auth: Sign in with Apple via Supabase
**Date:** 2026-03-23

Sign in with Apple is the primary auth method, required by App Store guideline 4.8 whenever a third-party login is offered. Supabase handles the Apple identity token validation server-side — the iOS app sends the token from ASAuthorizationAppleIDButton and Supabase returns a session JWT. Email/password login is available as a fallback. The app works in local-only mode before sign-in; sign-in is optional, not a hard gate on first launch.

## Multi-user photo storage: Supabase Storage → Cloudflare R2
**Date:** 2026-03-23

Photos are stored in Supabase Storage (S3-compatible, included in free tier) for the initial launch. Migration trigger to Cloudflare R2 is set at ~1K users or when monthly storage costs exceed $10. R2 has zero egress fees, which is the critical advantage for a photo-heavy app at scale. The storage path structure (`photos/{user_id}/{walk_record_id}/{photo_id}.jpg`) is the same in both backends — migration is a bucket URL swap, not a schema change.

## CloudKit sync guard: record count check over UserDefaults-only
**Date:** 2026-03-23

`SeedDataService.seedIfNeeded` previously used only a `UserDefaults` flag to prevent re-seeding. The flag is device-local, so on a fresh install or reinstall the app would re-seed even if CloudKit was about to deliver existing records from another device. Changed to check `fetchCount(FetchDescriptor<WalkRecord>())` first — if any records exist (from any source), seeding is skipped. UserDefaults flag is kept as a secondary guard for the case where records were intentionally deleted. The count check handles CloudKit delivery timing; the UserDefaults flag handles deliberate deletion.

## SyncStatusManager: NSPersistentCloudKitContainer notifications with SwiftData
**Date:** 2026-03-23

SwiftData with CloudKit still posts `NSPersistentCloudKitContainer.eventChangedNotification` via its underlying CoreData stack. `SyncStatusManager` listens to these notifications and exposes state (`unknown`, `syncing`, `synced(Date)`, `unavailable`, `error`) as `@Observable`. The manager is created in `SFStairwaysApp.init()` and injected via `.environment()` so any view can read it without prop drilling. The sync indicator lives in the Progress tab toolbar — natural home for system status in a single-user app.

## Data scraping approach (sfstairways.com + Nominatim fallback)
**Date:** 2026-03-22 [retroactive]

`scripts/scrape_stairways.py` is a one-time script that builds `data/all_stairways.json`. It first attempts to extract lat/lng from each stairway's page on sfstairways.com (Google Maps embeds, JS variables, JSON-LD). If that fails, it falls back to Nominatim geocoding. Records with no coordinates get `lat: null, lng: null` and are silently skipped by the app. The result is committed to the repo — no live scraping at runtime.

## Map Visual Refresh v2: amber palette, unified stair icon, top bar, dark map
**Date:** 2026-03-26

Four related visual decisions bundled in one session:

**Amber replaces orange for pins.** The original saved-pin color (#E8602C orange) was too warm/harsh against the map. Warm amber (#D4882B) reads more like a "destination" marker and meshes better with the yellow-to-brown app icon gradient. `brandOrange`/`brandOrangeDark` removed from AppColors; `brandAmber`/`brandAmberDark` replace them everywhere.

**Light green (#81C784) for saved, green (#4CAF50) for walked.** Differentiating saved vs. walked visually was the goal of the three-state model, but the original palette (orange saved, green walked) reads as a traffic-light signal (bad vs. good) rather than a progress continuum. Light green saved → full green walked communicates "on the way there" more naturally.

**Unified stair icon on all three pin states.** The original design showed no icon for unsaved, a stair icon for saved, and a checkmark for walked. The checkmark was borrowed from task-manager conventions that don't apply here — this is a discovery app, not a to-do list. The stair icon is the brand mark; showing it on every pin reinforces identity and makes all states visually consistent. The 50% opacity on unsaved pins already signals "not engaged" without needing to remove the icon entirely.

**White top bar replaces bottom search bar.** Bottom-anchored search bars are native on iOS but they compete with the home indicator and feel like a navigation bar in the wrong place. Moving search + Around Me to a top bar frees the bottom of the screen for the detail sheet, which slides up from below. The white top bar also provides natural contrast against the dark map — the design reads as layers (dark base → white controls → map content).

**Dark map via `.preferredColorScheme(.dark)` scoped to the Map view.** Applied directly to the `Map` SwiftUI view so only the map renders in dark mode — the rest of the UI (sheets, search panel, list tab) is unaffected. MapKit's standard dark basemap (charcoal/slate streets on near-black) is accepted as-is per the spec constraint that no custom tile overlay be introduced.

## Nav bar redesign: brandOrange unified color, progress card header
**Date:** 2026-03-26

`brandOrange` (#E8602C) is now the single orange token for all non-splash UI. The top nav bar moved from white to `brandOrange` — white-on-orange is a cleaner brand statement than the previous amber title on white, and removes the drop shadow that was needed to lift a white bar off a dark map. Button circles changed from `.systemGray5` to `Color.white.opacity(0.2)` (subtle on orange, consistent with active-state contrast).

The floating progress card gained a `brandOrange` header bar ("Progress" in white). The card previously had no label, relying on icon-free stats to identify themselves. A labeled header at 4pt vertical padding adds just enough context without bloating the card.

`accentAmber` (#E8A838) is reserved for splash screen only; it will be reintroduced for unverified badges in the Hard Mode spec.

## Hard Mode: per-stairway proximity-gated walk verification
**Date:** 2026-03-26

Hard Mode is an opt-in per-stairway feature that gates the Mark Walked action on the user being within 150m of the stairway. This was designed as purely client-side (no server verification, no CLRegion geofencing) to keep it lightweight and offline-capable.

**Why per-stairway rather than global.** A global Hard Mode toggle would be disruptive — enabling it would suddenly disable Mark Walked for all stairways and could create a poor experience if the user is away from home. Per-stairway allows selective enforcement on stairways the user specifically wants to verify in-person.

**Why proximity is checked at render time, not via geofence events.** CLRegion geofencing adds background entitlements, battery impact, and region limit (20 regions). For a 150m check on a stairway the user is actively viewing, render-time evaluation against `LocationManager.currentLocation` (updated every 50m) is sufficient and introduces no background activity.

**`proximityVerified: Bool?` instead of `Bool`.** The three-value semantics — nil (Hard Mode never enabled), false (pre-existing unverified walk), true (verified in-person) — carry historical meaning that a plain Bool would collapse. `nil` means "Hard Mode was never involved"; `false` means "Hard Mode was retroactively applied to an existing walk." Callers distinguish these with `showUnverifiedBadge` (requires `hardMode && walked && proximityVerified == false`), not by inspecting the raw value directly.

**Unverified badge uses `accentAmber` (#E8A838), distinct from `brandAmber` (#D4882B).** The badge needs to read on top of a green walked pin. Using the same amber as unsaved pins would create confusion ("is this an unsaved pin?"). `accentAmber` was already defined for the splash screen and is visually distinct at 12pt.

## UI Improvements v2: slimmer nav bar, icon-free pins, detail mini-map, Save action
**Date:** 2026-03-27

**Nav bar icon instead of text.** "SF Stairways" text was removed and replaced with a centered white `StairShape` icon (26×26pt) in the orange top bar. The text added no information the user doesn't already know from the app icon. The stair silhouette reinforces brand identity and keeps the bar uncluttered. Bar height reduced (10→6pt vertical padding) to give more map real estate.

**Icon removed from pins.** The `StairShape` icon inside the pin bulb was removed. At the reduced pin sizes the icon was visually noisy without providing meaningful state information — state is already communicated by pin color (amber / light green / green). Solid teardrop shapes are simpler and cleaner at small sizes.

**ProgressCard width corrected.** The orange "Progress" title bar was expanding to full screen width because the outer `VStack` had no width constraint and the header `HStack` contained a `Spacer`. Fixed by moving `frame(width: 120)` to the outer `VStack` so both the header and content rows are constrained to 120pt.

**StairwayDetail: mini-map replaces photo carousel.** The photo carousel at the top of the detail screen was a placeholder (showed "No photos yet" for most stairways). A non-interactive `Map` showing the stairway's location is more immediately useful — the user can orient themselves before navigating. Map is `allowsHitTesting(false)` to prevent accidental gestures in a scroll context. Falls back to a grey placeholder for the small number of stairways without coordinates.

**Save button added to StairwayDetail toolbar.** The only way to save a stairway was via the map bottom sheet. The detail screen (reached via the list) had no save action. A "Save" button now appears in the toolbar when `walkRecord == nil`, creating a `WalkRecord(walked: false)` on tap. Disappears once the record exists.

## StairwayOverride: independent model, not a WalkRecord extension
**Date:** 2026-03-27

The curator data (verified step count, height, description) is stored in a separate `StairwayOverride` model keyed by `stairwayID`, not as fields on `WalkRecord`. Two reasons:

**Different ownership semantics.** `WalkRecord` is personal walk data — when did I walk it, what did I note. `StairwayOverride` is authoritative stairway facts that exist independently of any particular walk. If Oscar re-walks a stairway and creates a new `WalkRecord`, the verified stairway facts shouldn't be attached to either walk specifically.

**Override persistence on unmark.** The spec requires that verified data survives if a walk is unmarked. If the override were embedded in `WalkRecord`, the delete-record path would need special logic to preserve it. As an independent model, unmarking a walk simply hides the curator section — the override record is untouched.

The constraint is enforced in app logic (find-or-create by `stairwayID`) rather than a database unique constraint, since CloudKit doesn't support unique constraints on SwiftData models.

## Solid orange pins: drop three-state color differentiation
**Date:** 2026-03-27

All map pins now use `brandOrange` (#E8602C) regardless of state (unsaved / saved / walked). The three-state color system (amber / light green / green) was dropped.

**Why.** The three colors added visual complexity without clearly communicating actionable information at a glance. Users don't need to know at map scale whether a stairway is "saved" vs "walked" — they navigate to individual stairways and the detail/bottom-sheet tells them the state. The uniform orange palette is simpler, consistent with the app's brand color, and eliminates the need to remember color meanings.

State information is still fully preserved in the data model and surfaces in the detail view, bottom sheet, and list tab. Selected pins use `brandOrangeDark` (#BF4A1F). Closed stairways retain `unwalkedSlate` for functional distinction.

The stair icon was also removed from the MapTab nav bar in this same session — the orange bar is now plain, consistent with the icon-free pin design.

## Supabase iOS integration: AuthManager as @Observable NSObject
**Date:** 2026-03-27

`AuthManager` is an `@Observable final class` that also subclasses `NSObject`. The `NSObject` inheritance is required to conform to `ASAuthorizationControllerDelegate` and `ASAuthorizationControllerPresentationContextProviding` — both are ObjC protocols that require `NSObject`. `@Observable` and `NSObject` are compatible; the observation machinery is implemented via property-wrapper expansion, not class hierarchy.

**Session restore on init rather than via `.task` modifier.** Session restoration is triggered from `AuthManager.init()` via a detached `Task`. This avoids the view-lifecycle coupling of `.task {}` — `AuthManager` is created in `SFStairwaysApp.init()` alongside `SyncStatusManager`, so the Keychain check begins immediately, before any view appears. `isLoading = true` during the async check prevents the UI from flashing a "not signed in" state before the session is confirmed.

**Auth state changes subscribed via `authStateChanges` async stream.** Supabase SDK exposes `supabase.auth.authStateChanges` as an `AsyncStream` of `(AuthChangeEvent, Session?)` pairs. This handles token refresh, sign-out from another device, and session expiry automatically without polling. The stream subscription runs in a retained `Task` stored on `AuthManager` and is cancelled in `deinit`.

**`SettingsView` is a sheet, not a tab.** Auth settings are placed behind a gear icon in the ProgressTab toolbar rather than as a fourth tab. A tab implies a primary feature; settings are secondary. The iCloud sync status was previously only in a sheet triggered by the cloud icon — the gear icon brings the two system-level concerns (iCloud + Supabase auth) together in one place and cleans up the toolbar.

## Pin Visibility Fix: custom StairShape, 2x sizes, full opacity unsaved
**Date:** 2026-03-26

**Custom `StairShape` over SF Symbol `"stairs"`.** The SF Symbol `"stairs"` renders as 5 descending steps — the wrong count and the wrong direction. A custom SwiftUI `Shape` (added to `TeardropPin.swift`) draws exactly 3 ascending steps (left-to-right, climbing up), matching the app icon silhouette. The shape is a solid-fill path: no stroke, no scaling ambiguity, crisp at any pin size.

**Pin sizes doubled.** The original 24–34pt range was too small on a dark map where there is no white background to provide contrast. New range: 38pt (unsaved), 44pt (saved/walked), 52pt (selected). Icon ratio bumped from 38% to 42% of pin width. At these sizes the stair icon is legible even at city-wide zoom.

**Full opacity on unsaved pins.** `Color.brandAmber.opacity(0.5)` on unsaved pins was nearly invisible on the dark map — transparency that reads as "de-emphasized" on white reads as "ghost" on dark. States are now differentiated by hue only (amber / light green / green), not transparency. Transparency is reserved for the `isDimmed` and `isClosed` states via the `opacity` modifier on the outer container.

**Shadow updated for dark backgrounds.** Single dark shadow (`radius: 2, opacity: 0.2`) was invisible on a dark map. Replaced with a two-layer shadow: white glow (radius 3, opacity 0.3) for lift, plus black drop (radius 2, opacity 0.3, y: 2) for depth.

## Saved concept removed: two-state model (Unsaved / Walked)
**Date:** 2026-03-28

The three-state model (Unsaved / Saved / Walked) was introduced to let users bookmark stairways for later. In practice the "Saved" state added complexity — a separate filter pill, Save/Unsave buttons in the action row, a bookmark badge in the bottom sheet, and a `WalkRecord(walked: false)` record that had to survive walk deletion — without providing meaningful value for a solo user who primarily discovers stairways by walking them.

**Collapsed to two states.** Every stairway is either Unsaved (no WalkRecord) or Walked (WalkRecord.walked == true). The Saved intermediate state is gone. `StairwayAnnotation` now returns `.unsaved` for any record where `walked == false`. Action buttons for an unwalked stairway are "Start Walk" + "Mark Walked" (no Save). For a walked stairway, "Not Walked" calls `removeRecord()` directly — it no longer just sets `walked = false`, which would have recreated the old Saved state.

**One-time migration.** `SeedDataService.cleanUnwalkedRecordsIfNeeded` (key: `com.sfstairways.hasCleanedUnwalked`) deletes any existing `WalkRecord` where `walked == false` on first launch. Called from `SFStairwaysApp` alongside the other seed calls. Walked records are untouched.

**"Saved" filter pills removed** from both `StairwayFilter` (MapTab) and `ListFilter` (ListTab). `savedStairwayIDs` computed properties deleted. ListTab picker narrowed to 140pt (was 200pt) for the two remaining options.

## Layout tweaks: search bottom-right, settings leading, Stats tab rename
**Date:** 2026-03-28

Three small UX changes bundled in the same spec:

**Search button to bottom-right float.** The magnifyingglass button was removed from the trailing top bar buttons and added as a 32×32 circle floating above the ProgressCard in the `.overlay(alignment: .bottomTrailing)`. This clears the top bar and puts search closer to thumb reach.

**Settings gear to leading.** The gear icon moved from the trailing HStack (where it competed with Around Me + Tag Filter) to the leading side of the top bar ZStack. The trailing side now holds only the two functional map controls: Around Me and Tag Filter.

**Progress → Stats.** The tab label and navigation title were renamed from "Progress" to "Stats" (`ContentView.swift` tab label + `ProgressTab.swift` `.navigationTitle`). "Stats" is more concise and accurately describes the content (completion metrics, neighborhood breakdown, recent walks) without implying a goal-setting workflow.

## Remove launch zoom-to-nearest: city view is the right default
**Date:** 2026-03-29

The launch zoom automatically flew the map to the nearest stairway as soon as location was obtained. The motivation was to give new users an immediate point of interest. In practice it was disorienting — the map would jump unexpectedly to a random stairway even when the user just wanted the overview. City-wide view (latDelta 0.06, centered on SF) is the correct default: it shows all 382 stairways and lets the user orient before navigating.

`hasZoomedToNearest`, `launchTime`, the `.onChange(of: locationManager.currentLocation)` handler, and `zoomToNearest(from:)` are all removed. Explicit user-triggered navigation (`flyTo`, `flyToUserLocation`, `flyToNeighborhood`) is unchanged.

## ProgressCard: amber bar replaces title text
**Date:** 2026-03-29

The ProgressCard header displayed `Text("Progress")` — the same word as the (now renamed) Stats tab just below it, creating a visual echo. Removed the text entirely. The card's purpose is self-evident from the three stat lines (stairway count, feet, steps). The amber header bar is kept as a 4pt color accent, providing visual separation between the header area and stats without requiring a label.

## HealthKit entitlement: added to .entitlements, Xcode capability required separately
**Date:** 2026-03-29

`com.apple.developer.healthkit` and `com.apple.developer.healthkit.access` added to `SFStairways.entitlements`. These keys are required for code signing but the HealthKit permission dialog also requires the HealthKit capability to be enabled in Xcode target Signing & Capabilities (which links `HealthKit.framework`). The entitlement file is in the repo; the Xcode project capability toggle is a manual step per-machine that is not tracked in the repo's pbxproj in this project's workflow.

## macOS admin dashboard: new target in existing Xcode project, shared models
**Date:** 2026-03-29

A macOS companion app was added as a second target in `SFStairways.xcodeproj` (bundle ID: `com.o4dvasq.SFStairways.mac`, source at `ios/SFStairwaysMac/`). It shares the same CloudKit container as iOS, so walk records, overrides, tags, and photos sync automatically with zero additional sync code.

**Shared models rather than duplicated.** All SwiftData model files (`Models/*.swift`, `StairwayStore`, `AppColors`) are shared between iOS and macOS via Xcode target membership — they compile for both platforms. The only model requiring changes was `WalkPhoto.swift`, which used `UIKit` for `UIImage` computed properties and `UIGraphicsImageRenderer` thumbnail generation. These are now wrapped in `#if canImport(UIKit)` / `#else` blocks so the macOS build omits them cleanly. macOS views access photo data directly (`photo.thumbnailData ?? photo.imageData` → `NSImage(data:)`) without going through the computed properties.

**No Supabase or HealthKit on macOS (MVP).** The macOS app reads HealthKit data that was synced via CloudKit from iOS WalkRecords, but does not fetch new HealthKit data (HealthKit is iOS-only). Supabase photos are excluded from the macOS MVP — only CloudKit-synced local photos are visible.

**Why macOS rather than a second iOS app or web admin.** The admin workflow (bulk tagging, curator note promotion, data hygiene review, CSV export) is inherently desktop-oriented — multi-select, sortable tables, file export panels. A native macOS app with `NavigationSplitView` + `Table` (macOS SwiftUI primitives) provides exactly this without needing to build a separate web backend or fight iOS's touch-first conventions.

**File membership is a manual Xcode step.** Adding a target to `project.pbxproj` by hand editing is error-prone and risks corrupting the project file. The correct workflow is: create the target in Xcode UI (File → New → Target), then add shared files via the File Inspector (Target Membership checkbox). This is documented in PROJECT_STATE.md Known Issues.

## HealthKit data accuracy: drop retroactive pull, restrict display to active walks
**Date:** 2026-03-29

The retroactive HealthKit pull queried steps and elevation for the entire day a stairway was walked (midnight to midnight). This produced wildly inaccurate data — a stairway walk might show 10,000+ steps because it captured every step taken that day, not the ~200 steps on the stairway itself.

**Root cause.** `retroactivelyPullHealthKitStats()` used `Calendar.startOfDay` / `Calendar.startOfDay+1day` as the query window. There was no way to narrow it further because manually logged walks have no `walkStartTime` or `walkEndTime` — those timestamps are only set by the active walk session flow.

**Fix: discard all manually logged walk HealthKit data.** The `retroactivelyPullHealthKitStats()` function is removed entirely. `statsRow` now guards `stepCount` and `elevationGain` display behind `walkStartTime != nil` — only data from timed active sessions is shown. A one-time migration (`cleanRetroactiveStatsIfNeeded`, key `com.sfstairways.hasCleanedRetroactiveStats`) clears the bad full-day values from all existing manually logged walk records.

**Active walk HealthKit remains unchanged.** `endWalkSession()` still fetches HealthKit stats using the actual session `walkStartTime`/`walkEndTime` window — this produces accurate per-stairway step count and elevation, and is unaffected by this change.

**Design rule going forward:** HealthKit data is only ever captured during active walk sessions. Manually logged walks (via "Mark as Walked") intentionally have no HealthKit stats. This is correct because there is no reliable time window to query.

## macOS photo import: NSImage + NSBitmapImageRep for thumbnail generation
**Date:** 2026-03-29

`WalkPhoto.generateThumbnail(from:)` used `UIGraphicsImageRenderer` (UIKit-only) for thumbnail generation on iOS, with a stub `#else` branch on macOS that returned the original data unchanged. This meant photos added from Mac had full-resolution thumbnails, wasting CloudKit storage.

**Fix: proper macOS thumbnail path.** The `#else` branch now uses NSImage + NSBitmapImageRep to scale the image to 300px max width and encode as JPEG at 0.7 quality — identical parameters to the iOS path. The macro was extended to `#elseif canImport(AppKit) import AppKit` so AppKit types are available in the shared model file.

**Photo import compression.** Photos added via NSOpenPanel or drag-drop are first loaded as NSImage, then re-encoded as JPEG at 0.85 quality (matching iOS PhotoService). HEIC files are converted automatically because NSImage can decode HEIC and NSBitmapImageRep re-encodes to JPEG. This happens in `importImages(from:)` before creating the WalkPhoto object.

**canRetroactivelyPullStats removal side-effect.** DataHygieneView referenced `WalkRecord.canRetroactivelyPullStats` (removed in the HealthKit cleanup spec). Fixed by replacing the ternary with `walkStartTime != nil` — which correctly identifies app-session walks vs. manually logged ones, which is exactly what the original property was testing.

## Urban Hiker SF data import: enrichment_analysis as source-of-truth, word-anchor matching for coord fills
**Date:** 2026-03-29

**Use enrichment_analysis.json rather than re-deriving matches.** A prior analysis script produced `data/enrichment_analysis.json` with `new_stairways` (762 entries), `coord_matches` (336), and `name_matches` (8) already computed. The import script reads the pre-computed `new_stairways` list directly rather than re-running the 50m haversine pass against all 1,081 UH placemarks. This keeps the import script fast and deterministic — re-running the matching pass on every import would be redundant and the analysis already encodes the matching decisions.

**762 new entries vs. 735 in spec.** The spec estimated 735 based on an earlier analysis snapshot. The final enrichment_analysis.json had 762 unmatched entries. The import uses the actual data; the ~1,117 total in the spec was correspondingly approximate.

**Word-anchor check prevents structural false positives in coord-fill matching.** SequenceMatcher gives high similarity scores to structurally similar but semantically unrelated names (e.g., "Kirkham Street to 5th Avenue" scored 0.623 against "Florida Street up to 15th Street." because both follow the same template). Added a word-anchor sanity check: the *first* significant word from our name (length ≥ 4, not a generic street suffix) must appear verbatim in the UH name. This cleanly separates genuine matches (Pemberton/Pemberton, Acme/Acme, Moraga/Moraga, Clover/Clover) from template-similar false positives — none of the false positives shared their first distinctive word with the matched UH entry.

**4 coord fills vs. 15 aspired.** Only 4 of the 15 missing-coord stairways found a reliable name match in the UH data. The remaining 11 are all `closed: true` stairways — likely demolished or inaccessible routes that don't appear in the UH active-stairways map. Filling them with speculative coordinates would be worse than leaving them null (the iOS app silently skips null-coord entries; a wrong coordinate would show a pin in the wrong location).

**Idempotency via ID pre-check.** The script generates the canonical slug ID for each UH entry before checking whether it already exists in `all_stairways.json`. If it does (from a prior `--apply` run), the entry is skipped. This means `--apply` can be run safely any number of times. The slug generation is deterministic (lowercase → strip non-alphanumeric → spaces-to-hyphens → truncate 60 chars → numeric suffix if collision) so the same UH name always produces the same ID.

**New neighborhoods assigned by bounding box after 800m centroid fallback.** Entries within 800m of any existing neighborhood centroid are assigned to that neighborhood. Entries farther than 800m are checked against 8 geographic bounding boxes (Presidio, Golden Gate Park, Lands End, Fort Mason, Marina, Embarcadero, Downtown, Alcatraz Island) in priority order. Remaining entries within 1500m of any centroid get the nearest neighborhood. Anything still unassigned gets "Unclassified" for future curator review in the macOS admin dashboard.

## macOS-only tag CRUD; iOS tags made fully read-only
**Date:** 2026-03-29

Tags are a curator-facing feature that requires deliberate action — creating, renaming, assigning, and deleting tags. Putting this UI on iOS created friction: the phone keyboard is awkward for naming tags, and the full tag lifecycle (see all tags, check assignment counts, rename across stairways, cascade-delete) maps naturally to a desktop list UI.

**iOS as display-only.** `TagEditorSheet.swift` was deleted. `StairwayBottomSheet` now shows assigned tags as read-only pills (same visual, no X button, no Add Tag control). `TagFilterSheet` is unchanged — filtering by tag on the map is a read operation and belongs on iOS. The iOS → macOS asymmetry is intentional: walk logging on iOS, curation on macOS.

**`TagManagerSheet` as the single tag admin surface.** Rather than scattering tag create/rename/delete across the detail panel and bulk ops sheet, a dedicated `TagManagerSheet` (toolbar button, `tag.fill` icon) owns the full lifecycle. Detail panel and bulk ops retain *assignment* controls (add/remove tags to/from stairways) but delegate *tag creation* to the manager sheet or to inline "Create & Assign…" fields that run the same slug ID logic.

**Cascade delete on tag removal.** Deleting a custom tag from `TagManagerSheet` immediately deletes all `TagAssignment` records with that `tagID`. This is done in the action function before deleting the `StairwayTag`, so the model context save is a single atomic operation. Confirmation alert shows the affected stairway count.

**Preset tags cannot be renamed or deleted.** The `isPreset: Bool` flag on `StairwayTag` is the guard. Preset rows in `TagManagerSheet` show only name + count — no edit/delete controls. Preset tags are created once by `SeedDataService` and are considered part of the app's vocabulary.

## Nil-last sorting via sentinel sort keys + manual comparator dispatch
**Date:** 2026-03-29

SwiftUI `Table` requires `TableColumn(value:)` to use a `KeyPath` pointing to a `Comparable` type. `Optional<Double>` and `Optional<Int>` are not `Comparable`, so optional columns (Height, Steps, Elev. Gain, Date Walked) cannot be directly used as sort keypaths. Two approaches were considered:

**Option A: NilLastDouble/NilLastInt wrapper types.** Implement `Comparable` wrappers that put `nil` last. Works for ascending, but in descending order Swift reverses the comparison — nil (represented as `.leastNormalMagnitude`) would sort to the top, not the bottom. Fixing this requires overriding descending behavior which the wrapper can't see.

**Option B (chosen): Sentinel sort keys + manual dispatch in `sortedRows`.** Non-optional `heightSortKey: Double`, `stepsSortKey: Int`, etc. are added to `StairwayRow` using `-.greatestFiniteMagnitude` / `.min` as nil sentinels. These satisfy the `TableColumn(value:)` requirement (clickable headers, sort direction arrows). `sortedRows` reads `sortOrder.first.keyPath`, matches it against known keypaths (`\StairwayRow.heightSortKey` etc.), and delegates to `nilLastSorted(_:asc:value:)` which applies nil-last logic for both directions. Non-optional columns (Name, Photos) fall through to `rows.sorted(using: sortOrder)`.

The sentinel values are never shown in the UI — they only exist so the `Table` header has a sortable column type. The actual sort is fully controlled by `nilLastSorted`.

## Neighborhood palette: saturated colors replace pastels
**Date:** 2026-03-30

The original 12-color neighborhood palette used pastel RGB values (dominant channels 0.80–0.96, recessive channels 0.64–0.76). At the overlay opacities in use (fill ~0.17, stroke ~0.30) the polygons were barely visible — pastels washed out to near-white at any transparency.

Two changes together fix this: opacity levels were raised (fill 0.30/0.20 light/dark, stroke 0.50/0.40) and the palette was shifted toward more saturated colors (dominant channels ~0.88–0.92, recessive channels ~0.32–0.55). The hue families are preserved — each color is recognizably in the same family as its pastel predecessor — so the visual identity is maintained. Fully saturated primaries were avoided; the target was "clearly colored" rather than "neon."

`NeighborhoodDetail` fill/stroke bumped to 0.30/0.60 to remain consistent with the new map baseline.
