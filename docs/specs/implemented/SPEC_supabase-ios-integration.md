SPEC: Supabase iOS Integration + Sign in with Apple | Project: sf-stairways | Date: 2026-03-27 | Status: Ready for implementation

---

## 1. Objective

Integrate the Supabase Swift SDK into the iOS app and implement Sign in with Apple authentication via Supabase. This establishes the authenticated session that all future multi-user features (walk record sync, shared photos, curator commentary) will build on. No data migration or feature rewiring in this spec; just the SDK, the auth flow, and the plumbing.

**Prerequisite:** Supabase project must be created and configured per `supabase/SETUP_GUIDE.md` (project created, schema.sql run, seed_catalog.sql run, Apple provider configured in Supabase Dashboard).

---

## 2. Scope

**In scope:**

- Add `supabase-swift` as a Swift Package dependency
- Create a Supabase client singleton with project URL and anon key
- Implement Sign in with Apple auth flow using `ASAuthorizationAppleIDButton` → Supabase Auth
- Session persistence (Supabase SDK handles this via Keychain)
- Auth state observation (signed in / signed out / loading)
- A minimal auth UI: Sign in with Apple button accessible from the app
- Graceful handling of unauthenticated state (app works locally, no hard gate)
- Configuration file for Supabase credentials (gitignored)

**Out of scope:**

- Migrating SwiftData data to Supabase (future spec)
- Wiring walk_records or walk_photos to Supabase reads/writes
- Email/password fallback auth (deferred; Sign in with Apple is sufficient for launch)
- User profile editing UI
- Any changes to existing SwiftData/CloudKit behavior

---

## 3. Business Rules

1. **Sign-in is optional.** The app works identically to today in unauthenticated state. All existing SwiftData/CloudKit functionality continues. Sign-in unlocks future multi-user features but blocks nothing now.
2. **Sign in with Apple only.** No email/password, no Google, no other providers at launch.
3. **Session auto-restores.** On app launch, the Supabase SDK checks Keychain for an existing session. If valid, the user is silently authenticated. No re-login needed between launches.
4. **Sign out is available.** A sign-out action exists in the settings area for users who want to de-auth.
5. **Auto-create user profile.** The `handle_new_user()` database trigger (in schema.sql) creates a `user_profiles` row on first sign-up. The app does not need to explicitly create one.
6. **Credentials are not committed to git.** The Supabase project URL and anon key are stored in a configuration file that is gitignored.

---

## 4. Data Model / Schema Changes

No SwiftData model changes. No Supabase schema changes (schema is already provisioned via schema.sql).

### New Files

**`ios/SFStairways/Config/Supabase.plist`** (gitignored)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SUPABASE_URL</key>
    <string>https://xxxxx.supabase.co</string>
    <key>SUPABASE_ANON_KEY</key>
    <string>eyJhbGciOi...</string>
</dict>
</plist>
```

Add to `.gitignore`:
```
ios/SFStairways/Config/Supabase.plist
```

---

## 5. UI / Interface

### 5a. Auth State Manager

Create an `@Observable` class `AuthManager` that wraps the Supabase auth session:

```swift
@Observable
final class AuthManager {
    var session: Session?       // nil = not signed in
    var isLoading: Bool = true  // true while checking Keychain on launch

    var isAuthenticated: Bool { session != nil }
    var userId: UUID? { session?.user.id }
}
```

`AuthManager` is created in `SFStairwaysApp.init()` and injected via `.environment()`, same pattern as `SyncStatusManager`.

On init, `AuthManager`:
1. Calls `supabase.auth.session` to check for existing session in Keychain
2. Sets `session` if found, `nil` if not
3. Sets `isLoading = false`
4. Subscribes to `supabase.auth.onAuthStateChange` to react to sign-in/sign-out events

### 5b. Sign In with Apple Flow

The auth flow uses `ASAuthorizationAppleIDProvider` (AuthenticationServices framework):

1. User taps "Sign in with Apple" button
2. iOS presents the Apple credential sheet
3. On success, the app receives an `ASAuthorizationAppleIDCredential` containing an `identityToken`
4. App sends the identity token to Supabase: `supabase.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: tokenString))`
5. Supabase validates with Apple, creates/finds the user, returns a `Session`
6. `AuthManager.session` is set, UI reacts

### 5c. Sign In UI Location

Add a section to the app where the Sign in with Apple button is accessible. Two implementation options:

**Option A (recommended, aligns with Social Layer spec):** The Curator & Social Layer spec introduces a Settings screen (gear icon in ProgressTab toolbar). Place the auth section there:

```
┌─────────────────────────────────────┐
│  Settings                           │
│                                     │
│  Account                            │
│  ┌─────────────────────────────┐    │
│  │  [Sign in with Apple]       │    │  ← ASAuthorizationAppleIDButton
│  │  Sign in to sync walks and  │    │
│  │  access community features  │    │
│  └─────────────────────────────┘    │
│                                     │
│  (future: Hard Mode toggle, etc.)   │
└─────────────────────────────────────┘
```

When signed in, replace the button with:
```
┌─────────────────────────────────────┐
│  Account                            │
│  ┌─────────────────────────────┐    │
│  │  ✓ Signed in                │    │
│  │  oscar@...                  │    │  ← email from Apple (may be relay)
│  │              [Sign Out]     │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

**Option B (minimal, if Settings screen isn't built yet):** Add the Sign in with Apple button to the ProgressTab, below the recent walks section. Less ideal but doesn't require building a Settings screen.

Either way, the Sign in with Apple button must use Apple's standard `SignInWithAppleButton` SwiftUI view (from `AuthenticationServices`), which handles the branded appearance and accessibility automatically.

### 5d. No Onboarding Gate

There is no onboarding flow. The app launches directly into the map (current behavior). Sign-in is discovered through the Settings/Progress screen. The user is never blocked from using the app.

---

## 6. Integration Points

### Swift Package: supabase-swift

- Repository: `https://github.com/supabase/supabase-swift`
- Add via Xcode: File → Add Package Dependencies → paste the repo URL
- Select the `Supabase` product (includes Auth, PostgREST, Storage, Realtime)
- Minimum version: 2.0.0 (check latest stable)

### Supabase Client Singleton

Create `Services/SupabaseManager.swift`:

```swift
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()
    let client: SupabaseClient

    private init() {
        guard let path = Bundle.main.path(forResource: "Supabase", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let url = dict["SUPABASE_URL"] as? String,
              let key = dict["SUPABASE_ANON_KEY"] as? String else {
            fatalError("[SFStairways] Missing Supabase.plist — see supabase/SETUP_GUIDE.md")
        }
        client = SupabaseClient(
            supabaseURL: URL(string: url)!,
            supabaseKey: key
        )
    }
}
```

### Xcode Capabilities

The following must be enabled in the Xcode target (manual step, same as CloudKit):
- **Sign in with Apple** capability (Signing & Capabilities → + Capability → Sign in with Apple)

This is in addition to the existing iCloud / Push Notifications capabilities.

---

## 7. Constraints

- **iOS 17+ deployment target unchanged.**
- **No behavior changes to existing features.** SwiftData, CloudKit, map, list, progress — all unchanged. This spec is purely additive.
- **supabase-swift is the only new dependency.** No additional packages.
- **Supabase.plist must not be committed.** Add to .gitignore. The app should crash at launch with a clear error message if the plist is missing, so developers know what to configure.
- **Apple's HIG for Sign in with Apple.** Must use `SignInWithAppleButton` (standard Apple-branded button). Cannot customize the button appearance beyond the style variants Apple provides (`.black`, `.white`, `.whiteOutline`).
- **No `.p8` key needed.** Native iOS Sign in with Apple uses `ASAuthorizationAppleIDProvider` on-device. Supabase validates the identity token directly — no server-side client secret generation required. The `.p8` key is only needed for web OAuth flows.
- **Supabase free tier is sufficient.** 50,000 monthly active auth users. No cost concern.

---

## 8. Acceptance Criteria

- [ ] `supabase-swift` added as a Swift Package dependency and builds successfully
- [ ] `SupabaseManager` singleton reads from `Supabase.plist` and creates a valid client
- [ ] `Supabase.plist` is gitignored; app crashes with a helpful message if missing
- [ ] `AuthManager` is `@Observable`, injected via `.environment()` in `SFStairwaysApp`
- [ ] `AuthManager` restores session from Keychain on app launch (no re-login between launches)
- [ ] `AuthManager` updates on auth state changes (sign in, sign out, token refresh)
- [ ] Sign in with Apple button presented using `SignInWithAppleButton` (standard Apple view)
- [ ] Tapping Sign in with Apple → Apple credential sheet → identity token sent to Supabase → session established
- [ ] After sign-in, UI shows "Signed in" state with email and Sign Out button
- [ ] Sign out clears the session and returns to the Sign in with Apple button
- [ ] App works identically in unauthenticated state (no regressions to existing features)
- [ ] `user_profiles` row is auto-created on first sign-up (verify in Supabase Dashboard)
- [ ] Sign in with Apple capability added to Xcode target
- [ ] No Supabase credentials committed to git
- [ ] Feedback loop prompt has been run

---

## 9. Files Likely Touched

| File | Change |
|------|--------|
| **New Files** | |
| `Services/SupabaseManager.swift` | Supabase client singleton, reads from plist |
| `Services/AuthManager.swift` | `@Observable` auth state wrapper, Sign in with Apple flow |
| `Config/Supabase.plist` | Supabase URL + anon key (gitignored) |
| `Views/Settings/SettingsView.swift` | Settings screen with account section (Sign in / Sign out) |
| **Modified Files** | |
| `SFStairwaysApp.swift` | Create `AuthManager`, inject via `.environment()` |
| `Views/Progress/ProgressTab.swift` | Add gear icon to toolbar linking to SettingsView |
| `.gitignore` | Add `ios/SFStairways/Config/Supabase.plist` |
| **Xcode Project (manual)** | |
| `SFStairways.xcodeproj` | Add `supabase-swift` SPM dependency, Sign in with Apple capability |
| `SFStairways.entitlements` | Add `com.apple.developer.applesignin` entitlement |
