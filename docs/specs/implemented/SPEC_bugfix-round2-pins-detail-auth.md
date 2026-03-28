SPEC: Bug Fixes Round 2 — Circles for Pins, Curator Section Gating, Auth Debug | Project: sf-stairways | Date: 2026-03-27 | Status: Ready for implementation

## 1. Objective

Three bugs found during on-device testing 2026-03-27 (post-round-1 fixes):

- **A. Map pins still not rendering correctly.** Abandon teardrop shape entirely. Switch to simple colored circles: gray (unsaved), orange (saved), green (walked).
- **B. Detail page shows editable "Stairway Info" fields (stair count, height, description) to all users on all walked stairways.** This section should only appear for curators in curator mode. Regular users should see public catalog data (height) as read-only in the stats row, which already works.
- **C. Sign in with Apple still not completing.** The code fix from round 1 was applied correctly (SettingsView passes credential to `handleAppleAuthorization`), but sign-in still fails. Likely a Supabase or entitlement configuration issue, not a code bug.

## 2. Scope

Bugs A and B are code changes. Bug C is a diagnostic/configuration task.

### Bug A: Replace Teardrop Pins with Colored Circles

**Current state:** `TeardropShape` inside `StairwayPin` still renders poorly in MapKit's `Annotation` container despite size increases and shadow changes.

**Fix:** Replace the entire `StairwayPin.body` to use `Circle()` instead of `TeardropShape()`.

In `TeardropPin.swift`, replace `StairwayPin.body` with:

```swift
var body: some View {
    Circle()
        .fill(fillColor)
        .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
        .frame(width: pinSize, height: pinSize)
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        .opacity(opacity)
        .animation(.spring(response: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.25), value: isDimmed)
}
```

Replace `pinWidth` and `pinHeight` with a single `pinSize` computed property:

```swift
private var pinSize: CGFloat {
    if isSelected { return 24 }
    switch state {
    case .unsaved: return 12
    case .saved: return 16
    case .walked: return 16
    }
}
```

Replace `fillColor` with state-based colors:

```swift
private var fillColor: Color {
    if isClosed { return Color.unwalkedSlate }
    if isSelected {
        switch state {
        case .unsaved: return Color(white: 0.7)  // lighter gray when selected
        case .saved: return Color.brandOrangeDark
        case .walked: return Color.walkedGreenDark
        }
    }
    switch state {
    case .unsaved: return Color(white: 0.55)      // medium gray
    case .saved: return Color.brandOrange
    case .walked: return Color.walkedGreen
    }
}
```

Remove `pinWidth` and `pinHeight` computed properties (replaced by `pinSize`).

Keep `TeardropShape` and `StairShape` structs in the file for future use. Do not delete them.

**Files:** `ios/SFStairways/Views/Map/TeardropPin.swift`

### Bug B: Gate Curator Section on Curator Mode

**Current state:** In `StairwayDetail.swift`, `curatorSection` (lines 346-412) is gated only on `if isWalked`. This means every walked stairway shows editable text fields for stair count, height, and description to all users. The user sees "Add stair count", "Add height", "Add description..." prompts, which looks like the app is asking them to manually enter data.

**What should happen:** The `statsRow` already correctly displays public catalog data (`stairway.heightFt`) with curator overrides taking precedence when they exist. That's the intended read-only experience. The editable "Stairway Info" section with TextFields should only appear for curators actively in curator mode.

**Fix:** Change the gate on `curatorSection` from `if isWalked` to `if isWalked && authManager.isCurator && curatorModeActive`.

In `StairwayDetail.swift`, change:

```swift
// Current (line ~347):
if isWalked {
```

to:

```swift
if isWalked && authManager.isCurator && curatorModeActive {
```

No other changes needed. The `statsRow` already shows height from the public catalog and verified overrides with the checkmark badge when they exist.

**Files:** `ios/SFStairways/Views/Detail/StairwayDetail.swift`

### Bug C: Sign in with Apple — Diagnostic Steps

The code path is now correct (credential flows from `SignInWithAppleButton` → `handleAppleAuthorization` → Supabase `signInWithIdToken`). If sign-in still fails silently, the issue is configuration.

**Diagnostic steps (in order):**

1. **Add visible error feedback.** In `AuthManager.handleAppleAuthorization`, change the catch block to surface the error to the user, not just print it:

```swift
// In handleAppleAuthorization, replace the catch block:
} catch {
    print("[AuthManager] Supabase sign-in failed: \(error)")
    // Surface error for debugging — remove after diagnosis
    await MainActor.run {
        self.signInError = error.localizedDescription
    }
}
```

Add a published property to AuthManager:

```swift
var signInError: String? = nil
```

And in `SettingsView.signedOutView`, add below the SignInWithAppleButton:

```swift
if let error = authManager.signInError {
    Text(error)
        .font(.caption)
        .foregroundStyle(.red)
        .padding(.top, 4)
}
```

2. **Check Supabase Apple provider configuration.** In Supabase Dashboard → Authentication → Providers → Apple: ensure the provider is enabled and the Service ID / bundle ID matches `com.o4dvasq.SFStairways`.

3. **Check Supabase.plist credentials.** Verify `Config/Supabase.plist` contains the correct `supabaseURL` and `supabaseAnonKey` for the project.

4. **Check entitlements.** The Sign in with Apple entitlement must be present in both:
   - `SFStairways.entitlements` file (already there)
   - Xcode target → Signing & Capabilities (manual step — verify in Xcode)

5. **Check Apple Developer Console.** The App ID must have "Sign in with Apple" capability enabled. The Service ID (if using one) must list the Supabase callback URL.

**Files:** `ios/SFStairways/Services/AuthManager.swift`, `ios/SFStairways/Views/Settings/SettingsView.swift`

## 3. Business Rules

- Unsaved stairways: gray circle on map
- Saved stairways: orange circle on map (slightly larger)
- Walked stairways: green circle on map (same size as saved)
- Selected stairway: larger circle in darker variant of its color
- Curator editing fields only visible to curators with curator mode active

## 4. Data Model / Schema Changes

None. Only adding one optional `signInError: String?` property to `AuthManager` for debug visibility.

## 5. UI / Interface

- Map: simple colored circles instead of teardrops
- Detail: "Stairway Info" editor section hidden for non-curators; `statsRow` continues to show public data for everyone
- Settings: error text shown below Sign in with Apple button when auth fails

## 6. Integration Points

- Supabase auth (Apple provider) — configuration verification needed
- MapKit `Annotation` — switching to `Circle()` for reliable rendering

## 7. Constraints

- Do not delete `TeardropShape` or `StairShape` — keep for future use
- Pin colors must use existing `AppColors` definitions where possible
- The `signInError` display is temporary for debugging; can be removed once auth is working

## 8. Acceptance Criteria

- [ ] Map shows gray circles for unsaved, orange for saved, green for walked stairways
- [ ] Selected stairway shows a larger circle in a darker shade of its state color
- [ ] Circles render cleanly on the dark map at all zoom levels
- [ ] "Stairway Info" editor section (stair count, height, description TextFields) does NOT appear on the detail page for non-curator users
- [ ] `statsRow` on detail page still shows public `heightFt` from catalog data for all users
- [ ] If Sign in with Apple fails, the error message is displayed below the button
- [ ] Supabase Apple provider config has been verified
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/TeardropPin.swift` — replace teardrop with circles, new color scheme
- `ios/SFStairways/Views/Detail/StairwayDetail.swift` — gate curatorSection on curator mode
- `ios/SFStairways/Services/AuthManager.swift` — add `signInError` property, surface errors
- `ios/SFStairways/Views/Settings/SettingsView.swift` — display sign-in error text
