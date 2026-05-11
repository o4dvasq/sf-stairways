import AuthenticationServices
import SwiftUI

struct OnboardingView: View {
    @Environment(AuthManager.self) private var authManager
    var onFinish: () -> Void

    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.accentAmber.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    page1.tag(0)
                    page2.tag(1)
                    page3.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomBar
                    .padding(.horizontal, 32)
                    .padding(.bottom, 52)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Page 1: Discovery

    private var page1: some View {
        VStack(spacing: 0) {
            Spacer()

            // Stair icon — same shape used in the app icon and top bar
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 160, height: 160)
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 220, height: 220)
                StairShape()
                    .fill(Color.white)
                    .frame(width: 72, height: 72)
            }
            .padding(.bottom, 44)

            Text("SF Stairs")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(Color.white)
                .padding(.bottom, 16)

            Text("382 public stairways across 53 neighborhoods. Get in some steps, explore new corners of the city.")
                .font(.body)
                .foregroundStyle(Color.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 48)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 2: How It Works

    private var page2: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("How it works")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(Color.white)
                .padding(.bottom, 52)

            VStack(spacing: 36) {
                howItWorksRow(
                    icon: pinCircle(color: Color.brandAmber),
                    title: "Find them on the map",
                    detail: "Tap a pin for details, photos, and directions."
                )
                howItWorksRow(
                    icon: pinCircle(color: Color.walkedGreen, checked: true),
                    title: "Log your walks",
                    detail: "Mark a stairway walked once you've climbed it. The pin turns green."
                )
                howItWorksRow(
                    icon: progressIcon,
                    title: "Watch the map fill in",
                    detail: "Track your progress across every neighborhood in the city."
                )
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 3: Sign In + CTA

    private var page3: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Text("One last thing")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)

                    Text("Sign in to sync your walks and photos across devices, and to earn climb-order achievements like First to Climb.")
                        .font(.body)
                        .foregroundStyle(Color.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        authManager.handleAppleAuthorization(authorization)
                    case .failure(let error):
                        let asError = error as? ASAuthorizationError
                        if asError?.code != .canceled {
                            print("[OnboardingView] Sign in with Apple failed: \(error)")
                        }
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 32)

                if let error = authManager.signInError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button("Maybe later", action: onFinish)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.70))

                Text("Your sign-in only links walks and photos to your account. Nothing else is collected or shared.")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }

            Spacer()
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(0..<3) { i in
                    Capsule()
                        .fill(Color.white.opacity(i == currentPage ? 1.0 : 0.30))
                        .frame(width: i == currentPage ? 22 : 8, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                }
            }

            if currentPage < 2 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(Color.brandOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else {
                Button(action: onFinish) {
                    HStack(spacing: 8) {
                        Text("Let's Get Climbing!")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                            .font(.headline)
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.walkedGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    // MARK: - Row Icon Helpers

    /// Colored circle matching the map pin visual language.
    private func pinCircle(color: Color, checked: Bool = false) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.20), radius: 2, y: 1)
            if checked {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 30, height: 30)
    }

    /// Small stair-shape icon for the "watch the map fill in" row.
    private var progressIcon: some View {
        ZStack {
            Circle()
                .fill(Color.walkedGreen)
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.20), radius: 2, y: 1)
            StairShape()
                .fill(Color.white)
                .frame(width: 14, height: 14)
        }
        .frame(width: 30, height: 30)
    }

    private func howItWorksRow(icon: some View, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            icon
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.80))
                    .lineSpacing(2)
            }

            Spacer()
        }
    }
}
