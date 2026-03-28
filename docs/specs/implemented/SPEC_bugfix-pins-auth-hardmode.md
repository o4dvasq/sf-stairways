SPEC: Bug Fixes — Map Pins, Sign in with Apple, Hard Mode Toggle | Project: sf-stairways | Date: 2026-03-27 | Status: Ready for implementation

## 1. Objective

Fix three interrelated bugs discovered during on-device testing on 2026-03-27:

- Map pins render as tiny hollow-looking markers instead of solid orange teardrops
- Sign in with Apple completes OS-level authentication but never signs the user into the app
- Hard Mode toggle is permanently disabled (gray, untappable) because auth never succeeds

Bug #2 is the root cause of bug #3. Bug #1 is independent.

## 2. Scope

Bug fixes only. No new features, no schema changes, no new files.

### Bug A: Map Pin Rendering

**Symptoms:** Pins on the dark map appear as tiny orange chevrons/arrows with white or hollow centers instead of solid filled teardrop shapes. After 10+ attempts to fix, pins still don't render as intended.

**Root cause hypothesis:** The custom `TeardropShape` + `StairwayPin` view rendered inside MapKit's `Annotation` container may not be sizing or rendering correctly. The white shadow (`.shadow(color: .white.opacity(0.3), radius: 3, y: 0)`) on a dark map background can create a washed-out/hollow appearance. The unsaved pin size (30x38pt) may also be too small to read as a teardrop at typical zoom levels.

**Fix approach — try in this order, stop when pins render correctly:**

1. **Increase minimum pin size.** Change unsaved pins from 30x38 to 36x45 (same as current saved size). Change saved pins from 36x45 to 40x50. Selected pins from 42x53 to 48x60. This makes the teardrop shape legible.

2. **Remove the white shadow.** Delete `.shadow(color: .white.opacity(0.3), radius: 3, y: 0)` from `StairwayPin.body`. Keep only the black drop shadow. The white glow on a dark map makes pins look hollow.

3. **Add a thin dark stroke around the teardrop.** After `.fill(fillColor)`, add `.overlay(TeardropShape().stroke(Color.black.opacity(0.4), lineWidth: 1))` to give the pin a defined edge.

4. **If teardrops still don't render correctly in MapKit's Annotation container, fall back to simple filled circles.** Replace `TeardropShape().fill(fillColor)` with `Circle().fill(fillColor)` at sizes 14pt (unsaved), 16pt (saved/walked), 20pt (selected). Simple circles are guaranteed to render correctly in MapKit annotations. Keep `TeardropShape` in the file for future use.

**Files:** `ios/SFStairways/Views/Map/TeardropPin.swift`

### Bug B: Sign in with Apple

**Symptoms:** User taps Sign in with Apple button → Apple auth sheet appears → user authenticates with Face ID → sheet dismisses → app still shows "signed out" state. No error visible to user.

**Root cause:** In `SettingsView.swift` lines 78-83, the `SignInWithAppleButton` SwiftUI view has an `onCompletion` handler that **ignores the authorization result** (parameter is `_`) and instead calls `authManager.signInWithApple()`, which creates a second, separate `ASAuthorizationController` request. The credential from the first (successful) request is discarded. The second request either fails silently or presents a redundant auth prompt.

**Fix:** The `onCompletion` handler receives a `Result<ASAuthorization, Error>`. Extract the `ASAuthorizationAppleIDCredential` and its identity token from the success case, then pass the token directly to Supabase's `signInWithIdToken`. Do NOT call `authManager.signInWithApple()` from the completion handler.

Specifically, replace the `SignInWithAppleButton` block in `SettingsView.signedOutView` with:

```swift
SignInWithAppleButton(.signIn) { request in
    request.requestedScopes = [.fullName, .email]
} onCompletion: { result in
    switch result {
    case .success(let authorization):
        authManager.handleAppleAuthorization(authorization)
    case .failure(let error):
        print("[SettingsView] Sign in with Apple failed: \(error)")
    }
}
```

Add a new public method to `AuthManager`:

```swift
func handleAppleAuthorization(_ authorization: ASAuthorization) {
    guard
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
        let tokenData = credential.identityToken,
        let tokenString = String(data: tokenData, encoding: .utf8)
    else {
        print("[AuthManager] Sign in with Apple: missing identity token")
        return
    }

    Task {
        do {
            let session = try await SupabaseManager.shared.client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: tokenString)
            )
            await MainActor.run { self.session = session }
            await loadProfile()
        } catch {
            print("[AuthManager] Supabase sign-in failed: \(error)")
        }
    }
}
```

The existing `signInWithApple()` method (which creates its own ASAuthorizationController) can remain for now but is no longer called from the UI. Consider marking it as deprecated or removing it in a follow-up cleanup.

**Files:** `ios/SFStairways/Views/Settings/SettingsView.swift`, `ios/SFStairways/Services/AuthManager.swift`

### Bug C: Hard Mode Toggle Disabled

**Symptoms:** Hard Mode toggle is shifted left, gray, and untappable.

**Root cause:** `SettingsView.walkingSection` has `.disabled(!authManager.isAuthenticated)`. Since Sign in with Apple is broken (Bug B), `isAuthenticated` is always `false`, so the toggle is permanently disabled.

**Fix:** This resolves automatically when Bug B is fixed. No code change needed for this bug specifically.

**Verification:** After fixing Bug B, sign in successfully, then confirm the Hard Mode toggle becomes tappable and persists its state.

## 3. Business Rules

None changed. These are bug fixes restoring intended behavior.

## 4. Data Model / Schema Changes

None.

## 5. UI / Interface

- Pins should render as solid, clearly visible orange teardrops (or circles as fallback) on the dark map
- Sign in with Apple should complete the full flow: OS auth → Supabase session → UI updates to signed-in state
- Hard Mode toggle should be enabled when signed in

## 6. Integration Points

- Supabase auth: `signInWithIdToken` with Apple provider (already configured)
- MapKit `Annotation` container rendering of custom SwiftUI views

## 7. Constraints

- iOS 17+ only
- Must not change any data models or add new files
- Pin fix should be tested on-device (simulator MapKit rendering can differ)
- Auth fix requires valid Supabase project URL and anon key in `Config/Supabase.plist`

## 8. Acceptance Criteria

- [ ] Map pins render as solid, filled, clearly visible orange shapes (teardrop or circle) on the dark map at all zoom levels
- [ ] No white/hollow appearance on pins
- [ ] Sign in with Apple completes successfully: user authenticates → app shows signed-in state with email
- [ ] Hard Mode toggle is enabled and tappable after signing in
- [ ] Hard Mode toggle persists state correctly (UserDefaults + Supabase sync)
- [ ] No regressions in map interaction (tap to select, bottom sheet, filters)
- [ ] Feedback loop prompt has been run

## 9. Files Likely Touched

- `ios/SFStairways/Views/Map/TeardropPin.swift` — pin sizing, shadow removal, optional circle fallback
- `ios/SFStairways/Views/Settings/SettingsView.swift` — fix `onCompletion` handler
- `ios/SFStairways/Services/AuthManager.swift` — add `handleAppleAuthorization(_:)` method

## Note on CKErrorDomain 2

The CloudKit sync error (CKErrorDomain 2 = not authenticated) is a separate issue from Sign in with Apple / Supabase auth. CloudKit auth is tied to the user's iCloud account on the device, not Supabase. This error likely requires:

1. Verify the iCloud container identifier in Xcode matches the CloudKit Dashboard
2. Add Background Modes → Remote Notifications capability in Xcode (documented as a known manual step in PROJECT_STATE.md)
3. Ensure the user is signed into iCloud on the device

This is out of scope for this spec but should be addressed in a separate investigation.
