# SPEC: Hard Mode Simplification
**Project:** sf-stairways | **Date:** 2026-04-02 | **Status:** Ready for Implementation

---

## 1. Objective

Decouple Hard Mode from Supabase authentication so it works for all users without requiring Sign in with Apple. Remove the Supabase sync for this setting. Add a verified walk count to the Progress tab stats. No changes to the "Mark Anyway" override flow or map pin visuals.

---

## 2. Scope

**In scope:**
- Remove auth requirement from the Hard Mode toggle in Settings
- Remove Supabase sync of the Hard Mode preference
- Store Hard Mode preference in UserDefaults only
- Add verified walk count to the Progress tab summary stats
- Clean up deprecated per-stairway `hardMode` field references in comments

**Out of scope:**
- Changing the proximity check radius (stays at 150m)
- Changing the "Mark Anyway" override alert (stays as-is)
- Adding unverified badges to map pins (intentionally not doing this)
- Removing Sign in with Apple or Supabase from the app entirely (those serve other future purposes)
- Removing `hardModeAtCompletion` from WalkRecord (keep for data lineage)

---

## 3. Business Rules

1. **Hard Mode works without authentication.** The toggle in Settings is always enabled, regardless of whether the user is signed in. No gate, no disabled state, no "sign in to enable" messaging.

2. **UserDefaults is the only storage.** The `hardModeEnabled` preference is read from and written to `UserDefaults` with the existing key `"hardModeEnabled"`. No Supabase sync. No server round-trip.

3. **The "Mark Anyway" flow is unchanged.** When Hard Mode is enabled and the user is out of range, the alert still appears offering "Mark Anyway." Tapping it logs the walk with `proximityVerified = false`. This is intentionally generous, not punitive.

4. **Map pins do not distinguish verified vs. unverified.** Green = walked. That's it. The map is the celebration surface. No amber badges, no visual penalties for unverified walks.

5. **Unverified badge stays in detail views.** The amber `xmark.seal.fill` badge in `StairwayBottomSheet` and `StairwayRow` for `proximityVerified == false` walks remains. This is quiet, informational, not punitive.

6. **Progress tab shows verified count.** The stats summary in `ProgressTab` adds a verified walk count alongside the existing walked count. Format suggestion: "8 walked, 5 verified" or "8 walked (5 verified)" in the secondary text line. Keep it compact. This rewards Hard Mode users without shaming anyone who doesn't use it.

7. **Only show verified count if user has any verified walks.** If no walks have `proximityVerified == true`, don't show the verified stat at all. Don't show "0 verified" to someone who has never used Hard Mode.

---

## 4. Data Model / Schema Changes

None. All existing WalkRecord fields (`hardMode`, `proximityVerified`, `hardModeAtCompletion`) are retained as-is in the SwiftData schema. CloudKit compatibility is preserved. The only change is that the Supabase `user_profiles.hard_mode_enabled` field is no longer read or written by the app for this feature.

---

## 5. UI / Interface

### Settings > Walking Section

**Current behavior:** Hard Mode toggle is disabled (grayed out) when the user is not authenticated. The toggle shows a lock icon and description text.

**New behavior:** Hard Mode toggle is always enabled. Remove the `.disabled(!authManager.isAuthenticated)` modifier. The lock icon and description text ("Require proximity (150m) to mark stairways as walked") remain unchanged. The toggle still reads from and writes to `authManager.hardModeEnabled`, which now only touches UserDefaults.

### Progress Tab Stats Summary

**Current behavior:** The stats summary next to the progress ring shows walked count, percentage, total height, and neighborhood count.

**New behavior:** Add a verified count to the secondary text line. Only display if the user has at least one walk with `proximityVerified == true`.

Example rendering (secondary text line):
- User has verified walks: "42% · 1,230 ft · 12 neighborhoods · 5 verified"
- User has no verified walks: "42% · 1,230 ft · 12 neighborhoods" (unchanged)

The exact formatting and placement is implementation discretion. Keep it compact. It should not disrupt the existing layout or require a new line.

### Everything Else: Unchanged

- Mark Walked button behavior: unchanged
- attemptMarkWalked() proximity check flow: unchanged
- "Mark Anyway" alert: unchanged
- Map pin colors: unchanged (green = walked, amber = unsaved, no unverified distinction)
- StairwayBottomSheet unverified badge: unchanged
- StairwayRow unverified badge: unchanged
- 150m radius: unchanged

---

## 6. Integration Points

- **AuthManager.swift** — remove `syncHardModeToSupabase()` calls. Remove the Supabase profile load that overwrites the local Hard Mode preference. Keep `hardModeEnabled` property and `setHardMode()` method, but they now only interact with UserDefaults.
- **SettingsView.swift** — remove `.disabled(!authManager.isAuthenticated)` from the Hard Mode toggle.
- **ProgressTab.swift** — add a `@Query` for WalkRecord where `proximityVerified == true` to get the verified count. Display in the stats summary.

---

## 7. Constraints

- Do not remove `hardMode`, `proximityVerified`, or `hardModeAtCompletion` from the WalkRecord SwiftData model. Removing SwiftData properties that exist in CloudKit causes migration failures on devices that have already synced data.
- Do not remove the `UserProfile` struct or Supabase client code. Those serve other future purposes beyond Hard Mode.
- The `syncHardModeToSupabase()` function and the Hard Mode portion of `loadProfile()` should be removed (not just commented out). Dead code that calls Supabase for a feature that no longer uses it is confusing for future spec writers.

---

## 8. Acceptance Criteria

- [ ] Hard Mode toggle is enabled in Settings regardless of auth state (works when signed out)
- [ ] Toggling Hard Mode does not trigger any Supabase network call
- [ ] Hard Mode preference persists across app restarts via UserDefaults
- [ ] "Mark Walked" on a Hard Mode stairway within 150m sets `proximityVerified = true`
- [ ] "Mark Walked" on a Hard Mode stairway out of range shows the "Mark Anyway" alert
- [ ] "Mark Anyway" sets `proximityVerified = false`
- [ ] Map pins show green for all walked stairways (no unverified distinction)
- [ ] Unverified badge (amber xmark.seal.fill) still appears in StairwayBottomSheet and StairwayRow
- [ ] Progress tab shows verified count when user has verified walks
- [ ] Progress tab does not show verified count when user has zero verified walks
- [ ] No Supabase calls related to Hard Mode preference (verify in console logs)
- [ ] Feedback loop prompt has been run

---

## 9. Files Likely Touched

- `ios/SFStairways/Services/AuthManager.swift` — remove `syncHardModeToSupabase()`, remove Hard Mode portion of `loadProfile()`, keep `hardModeEnabled` and `setHardMode()` as UserDefaults-only
- `ios/SFStairways/Views/Settings/SettingsView.swift` — remove `.disabled(!authManager.isAuthenticated)` from the Hard Mode toggle
- `ios/SFStairways/Views/Progress/ProgressTab.swift` — add verified walk count to stats summary (query WalkRecord where `proximityVerified == true`)
