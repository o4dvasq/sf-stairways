import AuthenticationServices
import Supabase
import SwiftUI

@Observable
final class AuthManager: NSObject {
    var session: Session?
    var isLoading: Bool = true
    var userProfile: UserProfile? = nil
    var hardModeEnabled: Bool = UserDefaults.standard.bool(forKey: "hardModeEnabled")
    var signInError: String? = nil

    var isAuthenticated: Bool { session != nil }
    var userId: UUID? { session?.user.id }
    var isCurator: Bool { userProfile?.isCurator ?? false }

    private var authStateTask: Task<Void, Never>?

    override init() {
        super.init()
        Task { await restoreSession() }
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Hard Mode

    func setHardMode(_ enabled: Bool) {
        hardModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "hardModeEnabled")
        Task { await syncHardModeToSupabase() }
    }

    private func syncHardModeToSupabase() async {
        guard let userId else { return }
        do {
            try await SupabaseManager.shared.client
                .from("user_profiles")
                .update(["hard_mode_enabled": hardModeEnabled])
                .eq("id", value: userId.uuidString)
                .execute()
        } catch {
            print("[AuthManager] Failed to sync hard mode: \(error)")
        }
    }

    // MARK: - Profile

    func loadProfile() async {
        guard let userId else { return }
        do {
            let profiles: [UserProfile] = try await SupabaseManager.shared.client
                .from("user_profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            if let profile = profiles.first {
                await MainActor.run {
                    self.userProfile = profile
                    // Supabase is the source of truth for hard mode on sign-in
                    self.hardModeEnabled = profile.hardModeEnabled
                    UserDefaults.standard.set(profile.hardModeEnabled, forKey: "hardModeEnabled")
                }
            }
        } catch {
            print("[AuthManager] Failed to load profile: \(error)")
        }
    }

    // MARK: - Session restore

    private func restoreSession() async {
        do {
            let currentSession = try await SupabaseManager.shared.client.auth.session
            await MainActor.run {
                self.session = currentSession
                self.isLoading = false
            }
            await loadProfile()
        } catch {
            await MainActor.run {
                self.session = nil
                self.isLoading = false
            }
        }

        authStateTask = Task {
            for await (_, session) in SupabaseManager.shared.client.auth.authStateChanges {
                await MainActor.run { self.session = session }
                if session != nil {
                    await self.loadProfile()
                }
            }
        }
    }

    // MARK: - Sign in with Apple

    /// Handles the credential returned directly by SignInWithAppleButton's onCompletion handler.
    /// Extracts the identity token and passes it to Supabase — no second ASAuthorizationController needed.
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
                await MainActor.run {
                    self.session = session
                    self.signInError = nil
                }
                await loadProfile()
            } catch {
                print("[AuthManager] Supabase sign-in failed: \(error)")
                await MainActor.run {
                    self.signInError = error.localizedDescription
                }
            }
        }
    }

    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - Sign out

    func signOut() {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.signOut()
                await MainActor.run { self.session = nil }
            } catch {
                print("[AuthManager] Sign out failed: \(error)")
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
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
            } catch {
                print("[AuthManager] Supabase sign-in failed: \(error)")
            }
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        // ASAuthorizationError.canceled (1001) is normal — user dismissed the sheet
        let asError = error as? ASAuthorizationError
        if asError?.code != .canceled {
            print("[AuthManager] Sign in with Apple error: \(error)")
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Find the key window to present the Apple credential sheet.
        // A foreground-active UIWindowScene is always present when this is called.
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            preconditionFailure("No UIWindowScene available to present Apple sign-in sheet")
        }
        return windowScene.keyWindow ?? UIWindow(windowScene: windowScene)
    }
}
