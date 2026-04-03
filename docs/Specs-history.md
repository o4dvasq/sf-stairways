# Specs History

| Description | Implemented | Spec File |
|---|---|---|
| Walked card: green banner, remove section headings, icons row below | 2026-04-03 | SPEC_walked-card-redesign.md |
| Fix celebration animation: celebrationTrigger, Mark Anyway delay | 2026-04-03 | SPEC_celebration-bug.md |
| Tag pills: filled color palette, white text, random color per tag | 2026-04-03 | SPEC_tag-pill-colors.md |
| Public app rename: SF Stairways → SF Stairs across iOS + web | 2026-04-03 | SPEC_sf-stairs-rebrand.md |
| Splash image swap to branded PNG; old assets removed | 2026-04-03 | SPEC_splash-image-update.md |
| Share card logo overlay moved to bottom-left for crop safety | 2026-04-03 | SPEC_share-card-crop-safe.md |
| Progress count bugfix + neighborhoods visited in map card | 2026-04-02 | SPEC_progress-count-bugfix.md |
| Mark Walked: haptic, green sheet tint, progress line, bounce animation | 2026-04-02 | SPEC_mark-walked-celebration.md |
| Neighborhood badges (completion seal) + discovery nuggets (facts per hood + daily global) | 2026-04-02 | SPEC_neighborhood-rewards.md |
| Hard Mode: UserDefaults-only, remove Supabase sync, verified count in Progress | 2026-04-02 | SPEC_hard-mode-simplification.md |
| Share card redesign: amber frame, logo overlay, neighborhood progress | 2026-04-02 | SPEC_share-card-redesign.md |
| Share card: 1080×1920 portrait image + native share sheet | 2026-04-02 | SPEC_share-card.md |
| Landing page + privacy policy; TestFlight CTA | 2026-04-02 | SPEC_landing-page.md |
| iOS tag editor sheet + post-photo mark-walked prompt | 2026-04-01 | SPEC_ios-tag-editor-photo-walked.md |
| Tag checklist popover; macOS table column reordering | 2026-03-31 | SPEC_macos-tag-popover-and-table-ux.md |
| Remove step count from all models, views, and services | 2026-03-31 | SPEC_remove-steps-tracking.md |
| Increase polygon fill/stroke opacity; saturate 12-color palette | 2026-03-30 | SPEC_neighborhood-color-saturation.md |
| Remove HealthKit, active walk recording, Start Walk button | 2026-03-30 | SPEC_remove-healthkit-walk-recording.md |
| Progress tab: compact ring, neighborhood card grid, undiscovered section | 2026-03-29 | SPEC_neighborhood-progress-reframe.md |
| Polygon overlays, centroid labels, NeighborhoodDetail view, 4 nav entry points | 2026-03-29 | SPEC_neighborhood-map-and-detail.md |
| Replace DataSF with SF 311 GeoJSON; 117 hoods, 68 active, re-migrate 382 stairways | 2026-03-29 | SPEC_neighborhood-311-migration.md |
| Neighborhood model, GeoJSON, migration 53→41 hoods, NeighborhoodStore | 2026-03-29 10:00 | SPEC_neighborhood-foundation.md |
| HealthKit retry+error, no duplicate mark button, photo badges, iCloud error msg | 2026-03-29 | SPEC_ux-fixes-round4.md |
| HealthKit logging + delay; toast on nil; "no data" steps; iCloud troubleshoot | 2026-03-29 | SPEC_healthkit-stats-and-sync-diagnosis.md |
| iOS admin app: field catalog tool, stairway deletion, overrides, tags | 2026-03-29 | SPEC_ios-admin-app.md |
| Light mode, warm terracotta palette, Rounded typography, orange ring | 2026-03-29 | SPEC_visual-refresh-phase-1.md |
| iOS admin app: stairway browser, delete, overrides, tags | 2026-03-29 | SPEC_ios-admin-app.md |
| Map pin labels: 4-word truncation, hide at wide zoom | 2026-03-29 | SPEC_map-label-cleanup.md |
| Green readability, notes bug fix, collapsible neighborhoods, Search tab | 2026-03-29 | SPEC_ux-fixes-round3.md |
| Attribution links on detail screens; iOS + macOS acknowledgements section | 2026-03-29 | SPEC_attribution-and-acknowledgements.md |
| macOS tag CRUD, table sorting nil-last, sidebar tag filter, iOS read-only, app icon | 2026-03-29 | SPEC_macos-tag-management.md |
| Import 762 Urban Hiker SF stairways; 4 coord fills; 8 new neighborhoods | 2026-03-29 | SPEC_urban-hiker-data-enrichment.md |
| Add photos from Mac; drag-drop; inline notes editing; macOS thumbnails | 2026-03-29 | SPEC_macos-photo-add.md |
| Remove retroactive HealthKit pull; clear bad step/elevation data | 2026-03-29 | SPEC_healthkit-data-cleanup.md |
| macOS admin dashboard: browser, detail, hygiene, bulk ops | 2026-03-29 | SPEC_admin-dashboard-design.md |
| Photo upload logging, auth check, failed vs pending badge | 2026-03-29 | SPEC_photo-sync-fix.md |
| Stats/Progress label swap; search button bottom-right; sheet cleanup | 2026-03-29 | SPEC_map-launch-and-cleanup.md |
| Remove launch zoom; ProgressCard label; HealthKit entitlement | 2026-03-28 | SPEC_map-launch-and-cleanup.md |
| HealthKit walk stats visibility, diagnostics, retroactive pull | 2026-03-28 | SPEC_healthkit-walk-stats-display.md |
| Remove Saved concept; search bottom-right; settings left; Stats tab | 2026-03-28 | SPEC_remove-saved-and-layout-tweaks.md |
| Camera button in active walk banner; WalkRecord created on start | 2026-03-28 | SPEC_camera-during-active-walk.md |
| Tags: model, editor sheet, map filter, search tab, CloudKit sync | 2026-03-28 | SPEC_stairway-tags-v1.md |
| Hard Mode confirmation prompt; amber badge for unverified walks | 2026-03-28 | SPEC_hard-mode-confirmation-prompt.md |
| Active walk mode: timer, HealthKit steps/elevation, end/cancel flow | 2026-03-28 | SPEC_active-walk-mode.md |
| Suggested photos from walk day; PHAsset dedup, dismiss, add actions | 2026-03-28 | SPEC_photo-time-window-suggestions.md |
| Save camera captures to system camera roll via PHPhotoLibrary | 2026-03-28 | SPEC_photo-camera-roll-fix.md |
| Fix local photos invisible; add is_public to upload; merge remote+local | 2026-03-28 | SPEC_photo-persistence-fix.md |
| Launch zoom to nearest stairway after splash dismisses | 2026-03-28 | SPEC_launch-zoom-nearest.md |
| Map pin tap targets 44pt min; zoom-responsive scale 1x–2x | 2026-03-28 | SPEC_map-pin-ux.md |
| Promote notes to commentary: reorder layout, trigger pre-fill, scroll | 2026-03-28 | SPEC_curator-notes-to-commentary.md |
| Expandable bottom sheet replaces two-view map flow, deletes StairwayDetail | 2026-03-28 16:00 | SPEC_expand-collapse-detail.md |
| UI overhaul: amber accent, top bar redesign, splash fix, pin colors | 2026-03-27 | SPEC_ui-overhaul-auth-db.md |
| Round 2 bug fixes: circle pins, curator gate, auth error | 2026-03-27 | SPEC_bugfix-round2-pins-detail-auth.md |
| Bug fixes: map pins, Sign in with Apple, Hard Mode toggle | 2026-03-27 | SPEC_bugfix-pins-auth-hardmode.md |
| Curator social layer: commentary, photo carousel, likes, user-level Hard Mode | 2026-03-27 | SPEC_curator-social-layer.md |
| Supabase iOS integration: SDK, AuthManager, Sign in with Apple, SettingsView | 2026-03-27 | SPEC_supabase-ios-integration.md |
| Curator data layer: StairwayOverride model, verified stats with badge | 2026-03-27 | SPEC_curator-data.md |
| UI Improvements v2: slimmer nav bar, icon-free pins, ProgressCard width fix, detail mini-map, Save button | 2026-03-27 | SPEC_ui-improvements-v2.md |
| Hard Mode: proximity-verified walks with unverified badge | 2026-03-26 | SPEC_hard-mode.md |
| Nav bar & Progress card header (brandOrange unified) | 2026-03-26 | SPEC_nav-pin-progress-visual.md |
| Pin visibility fix: StairShape, 2x sizes, full opacity | 2026-03-26 | SPEC_pin-visibility-fix.md |
| Map visual refresh v2: amber pins, dark map, top bar, unified stair icon | 2026-03-26 | SPEC_map-visual-refresh-v2.md |
