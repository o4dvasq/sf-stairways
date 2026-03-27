import AuthenticationServices
import Supabase
import SwiftUI

@Observable
final class AuthManager: NSObject {
    var session: Session?
    var isLoading: Bool = true

    var isAuthenticated: Bool { session != nil }
    var userId: UUID? { session?.user.id }

    private var authStateTask: Task<Void, Never>?

    override init() {
        super.init()
        Task { await restoreSession() }
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Session restore

    private func restoreSession() async {
        do {
            let currentSession = try await SupabaseManager.shared.client.auth.session
            await MainActor.run {
                self.session = currentSession
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.session = nil
                self.isLoading = false
            }
        }

        authStateTask = Task {
            for await (_, session) in await SupabaseManager.shared.client.auth.authStateChanges {
                await MainActor.run { self.session = session }
            }
        }
    }

    // MARK: - Sign in with Apple

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
        // Find the key window to present the Apple credential sheet
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.windows.first { $0.isKeyWindow } ?? UIWindow()
    }
}
