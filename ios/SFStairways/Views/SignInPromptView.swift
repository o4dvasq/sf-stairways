import AuthenticationServices
import SwiftUI

struct SignInPromptView: View {
    @Environment(AuthManager.self) private var authManager
    var onMaybeLater: () -> Void

    var body: some View {
        ZStack {
            Color.surfaceBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    brandMark
                        .padding(.top, 64)
                        .padding(.bottom, 28)

                    Text("Welcome to SF Stairs")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)

                    Text("Sign in to get the most out of the app.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)

                    benefitList
                        .padding(.horizontal, 32)
                        .padding(.bottom, 28)

                    privacyNote
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)

                    signInButton
                        .padding(.horizontal, 32)

                    if let error = authManager.signInError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 8)
                    }

                    Button("Maybe later") {
                        onMaybeLater()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)
                    .padding(.bottom, 56)
                }
            }
        }
    }

    // MARK: - Subviews

    private var brandMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.brandOrange)
                .frame(width: 90, height: 90)
            Image(systemName: "figure.walk")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private var benefitList: some View {
        VStack(spacing: 20) {
            benefitRow(
                icon: "icloud.and.arrow.up",
                iconColor: Color.forestGreen,
                text: "Sync your photos across devices"
            )
            benefitRow(
                icon: "trophy.fill",
                iconColor: Color.brandAmber,
                text: "Earn climb-order achievements like \"First to Climb\""
            )
            benefitRow(
                icon: "person.2.fill",
                iconColor: Color.brandOrange,
                text: "Join the community as more features arrive"
            )
        }
    }

    private var privacyNote: some View {
        Text("We never share personal or identifying information. Your sign-in is used only to associate your walks and photos with your account.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private var signInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                authManager.handleAppleAuthorization(authorization)
            case .failure(let error):
                // ASAuthorizationError.canceled (1001) means the user swiped down the sheet —
                // do not set hasSeenSignInPrompt so they can retry or tap Maybe later.
                let asError = error as? ASAuthorizationError
                if asError?.code != .canceled {
                    print("[SignInPromptView] Sign in with Apple failed: \(error)")
                }
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func benefitRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28, alignment: .center)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
    }
}
