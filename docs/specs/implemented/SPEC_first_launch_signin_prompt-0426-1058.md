SPEC: First-Launch Sign-In Prompt | Project: sf-stairways | Date: 2026-04-26 | Status: Ready for implementation

## 1. Objective

On first launch, present a one-time onboarding screen that prompts the user to sign in with Apple before they reach the main app. Explain the benefits of signing in (photo sync, climb-order achievements, future community features) and state plainly that personal or identifying information is never shared. The screen is skippable — users can decline and sign in later from Settings — but the default path is to sign in upfront.

This addresses a real problem observed in beta: a tester used the app without ever signing in, uploaded photos, and those photos were tied to a throwaway anonymous Supabase user (created automatically on first photo upload). When that user eventually signs in with Apple, the previously-uploaded photos are orphaned to an identity that no longer reflects them.

## 2. Scope

In scope:
- A new full-screen onboarding view shown on first launch (and only on first launch) after the existing brand splash.
- "Sign in with Apple" as the primary action.
- "Maybe later" as a secondary action that dismisses the prompt and drops the user into the app unauthenticated.
- Persistent flag in UserDefaults so the prompt is shown at most once per install.
- Copy that explains the three benefits (photo sync, climb-order achievements, community features) and the privacy commitment.

Out of scope (call out as follow-on work, do not implement here):
- Migrating anonymous-user-owned photos to a real Apple-signed identity when a user signs in later. This is a separate Supabase-level identity-merge problem that needs its own spec.
- Re-showing the prompt after sign-out, or any logic that nags users who skipped.
- Any change to the existing 2.5s brand splash before this prompt.
- Any change to the existing Settings → Account sign-in surface.

## 3. Business Rules

- The onboarding screen is shown only when `UserDefaults.standard.bool(forKey: "hasSeenSignInPrompt")` is false.
- Once the user takes any action on the screen (signs in successfully, taps "Maybe later", or successfully completes Apple Sign-In), set `hasSeenSignInPrompt = true` and dismiss.
- If the user cancels the Apple sheet (returns to the prompt without completing), do NOT set the flag — they remain on the prompt and can retry or tap "Maybe later".
- The screen never appears for a user who is already authenticated when the app launches (e.g., they signed in on a previous launch, or restored from iCloud backup with a live Supabase session).
- The screen appears AFTER the existing 2.5s brand splash, not in place of it. Order: brand splash → onboarding prompt (first launch only) → main TabView.
- Privacy commitment copy must match the language in the existing `privacy.html` — the spec implementer should read that file and reuse phrasing rather than invent new claims.
- The "Maybe later" path must result in the user being able to use the full app (browse, mark walks, view photos uploaded by others). Photo upload while unauthenticated continues to use the existing anonymous Supabase fallback for now.

## 4. Data Model / Schema Changes

None.

The only new persistent state is one boolean in UserDefaults: `hasSeenSignInPrompt`. No SwiftData schema change, no Supabase schema change, no CloudKit container change.

## 5. UI / Interface

A single full-screen view, presented modally over the main app or as a gating layer (implementer's call — see Constraints).

Visual structure, top to bottom:
- App icon or simple brand mark at the top, generous vertical space.
- Headline: "Welcome to SF Stairs"
- Subhead: "Sign in to get the most out of the app."
- Three short benefit rows, each with an SF Symbol icon and a one-line label:
  - "icloud.and.arrow.up" — "Sync your photos across devices"
  - "trophy.fill" — "Earn climb-order achievements like 'First to Climb'"
  - "person.2.fill" — "Join the community as more features arrive"
- Privacy reassurance block, below the benefits, smaller type:
  "We never share personal or identifying information. Your sign-in is used only to associate your walks and photos with your account."
- Primary action: SignInWithAppleButton, full-width, ~50pt tall, black style, rounded.
- Secondary action: a plain text button labeled "Maybe later", below the Apple button, smaller and lower-emphasis.

Brand colors and typography should match the rest of the app: warm background (`Color.surfaceBackground`), forest-green or brand-orange accents where icons appear, rounded-design font for headings.

After successful Apple sign-in, the screen dismisses with a brief fade. After "Maybe later", same dismissal.

If `authManager.signInError` is non-nil after a sign-in attempt, show it inline in red below the Apple button (same pattern as `SettingsView.signedOutView`).

## 6. Integration Points

- `AuthManager.handleAppleAuthorization(_:)` — existing, reuse as-is. Do not introduce a new sign-in code path.
- `SignInWithAppleButton` from `AuthenticationServices` — same usage pattern as `SettingsView.signedOutView`.
- `SFStairwaysApp.swift` — needs to gate the onboarding view on `!authManager.isAuthenticated && !UserDefaults.hasSeenSignInPrompt`, and present it after the 2.5s brand splash dismisses.
- `privacy.html` — read this for exact privacy language to mirror in the prompt copy. Do not write a new privacy claim; mirror what is already published.

No new services. No new network calls beyond the existing Supabase Apple-token exchange.

## 7. Constraints

- Cowork preference is no functionality changes from Cowork. This spec is the handoff to Claude Code.
- Do not introduce any third-party packages. Use AuthenticationServices, SwiftUI, and the existing `AuthManager`.
- Do not block app launch on a network call. The Apple sign-in flow is user-initiated; if Supabase is slow, the existing `signInError` surface handles failure.
- Implementer choice — present the prompt as either (a) a full-screen `.sheet` over `ContentView`, dismissed by setting an `@State` flag in `SFStairwaysApp`, or (b) a sibling view in the existing `ZStack` in `SFStairwaysApp.body`. Option (b) is closer to the existing splash pattern and is the recommended approach.
- The prompt must not appear in Xcode previews or test fixtures by default. Gate on UserDefaults so previews start with `hasSeenSignInPrompt = true` if needed.
- Do not change the 2.5s splash duration. Do not stack the prompt on top of the splash — wait for splash dismissal first.
- Apple's Sign in with Apple Human Interface Guidelines apply: use the official `SignInWithAppleButton`, do not restyle it beyond the existing app-wide button styling, do not bury it below the fold.

## 8. Acceptance Criteria

- On a fresh install (or after deleting and reinstalling), launching the app shows: brand splash for 2.5s → onboarding prompt → on completion, main TabView.
- Tapping "Sign in with Apple" and completing the sheet successfully signs the user into Supabase, sets `hasSeenSignInPrompt = true`, and dismisses the prompt to the main app.
- Tapping "Maybe later" sets `hasSeenSignInPrompt = true`, dismisses the prompt, and drops the user into the main app unauthenticated.
- Cancelling the Apple sheet (swiping it down without completing) returns the user to the prompt with `hasSeenSignInPrompt` still false. They can retry or tap "Maybe later".
- Force-quitting and relaunching the app after either action does NOT show the prompt again.
- A user who is already signed in (session restored from a prior install) never sees the prompt — they go straight from the brand splash into the main app.
- A sign-in error (`authManager.signInError`) is displayed in red inline beneath the Apple button.
- Copy on the screen names photo sync, climb-order achievements, and community features as the three benefits.
- Copy explicitly states personal or identifying information will not be shared, in language consistent with `privacy.html`.
- The feedback loop prompt has been run.

## 9. Files Likely Touched

- `ios/SFStairways/Views/SignInPromptView.swift` — new file, the onboarding screen described in section 5.
- `ios/SFStairways/SFStairwaysApp.swift` — add gating logic to present `SignInPromptView` after the brand splash and on first launch only.
- `ios/SFStairways/Resources/AppColors.swift` (or wherever brand colors live) — only if a new shade is needed; should not be required.
- `ios/SFStairways/Views/SplashView.swift` — no change; called out so the implementer knows not to merge the two views.
- `docs/PROJECT_STATE.md` — update with a one-line note that first-launch onboarding is in place and that anonymous-photo-merge remains an open follow-on.

Follow-on, do not include in this spec's PR:
- Anonymous-user-to-Apple-user photo migration. This needs Supabase-side reasoning (linking auth identities, reassigning row ownership) and is significantly more involved than a UI change.
