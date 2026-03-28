import AuthenticationServices
import Supabase
import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(SyncStatusManager.self) private var syncManager

    @AppStorage("curatorModeActive") private var curatorModeActive = false

    var body: some View {
        NavigationStack {
            List {
                accountSection
                walkingSection
                if authManager.isCurator {
                    curatorSection
                }
                iCloudSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section("Account") {
            if authManager.isLoading {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Checking sign-in status…")
                        .foregroundStyle(.secondary)
                }
            } else if authManager.isAuthenticated {
                signedInView
            } else {
                signedOutView
            }
        }
    }

    private var signedInView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Signed in")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let email = authManager.session?.user.email {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            Button(role: .destructive) {
                authManager.signOut()
            } label: {
                Text("Sign Out")
                    .font(.subheadline)
            }
        }
    }

    private var signedOutView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sign in to sync walks and access community features.")
                .font(.caption)
                .foregroundStyle(.secondary)

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
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Walking Section

    private var hardModeBinding: Binding<Bool> {
        Binding(get: { authManager.hardModeEnabled }, set: { authManager.setHardMode($0) })
    }

    private var walkingSection: some View {
        Section("Walking") {
            Toggle(isOn: hardModeBinding) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hard Mode")
                            .font(.subheadline)
                        Text("Require proximity (150m) to mark stairways as walked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Color.forestGreen)
                }
            }
            .disabled(!authManager.isAuthenticated)
        }
    }

    // MARK: - Curator Section

    private var curatorSection: some View {
        Section("Curator") {
            Toggle(isOn: $curatorModeActive) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Curator Mode")
                            .font(.subheadline)
                        Text("Show curator tools on stairway detail view")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "pencil.and.list.clipboard")
                        .foregroundStyle(Color.brandOrange)
                }
            }
        }
    }

    // MARK: - iCloud Section

    private var iCloudSection: some View {
        Section("iCloud Sync") {
            HStack(spacing: 12) {
                Image(systemName: syncIconName)
                    .foregroundStyle(syncIconColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(syncTitle)
                        .font(.subheadline)
                    Text(syncDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var syncIconName: String {
        switch syncManager.state {
        case .unknown:              return "cloud"
        case .syncing:              return "arrow.clockwise.icloud"
        case .synced:               return "checkmark.icloud.fill"
        case .unavailable:          return "icloud.slash.fill"
        case .error:                return "exclamationmark.icloud.fill"
        }
    }

    private var syncIconColor: Color {
        switch syncManager.state {
        case .unknown:              return .secondary
        case .syncing:              return .blue
        case .synced:               return .green
        case .unavailable, .error:  return .red
        }
    }

    private var syncTitle: String {
        switch syncManager.state {
        case .unknown:              return "iCloud Sync"
        case .syncing:              return "Syncing…"
        case .synced:               return "Up to date"
        case .unavailable:          return "Sync unavailable"
        case .error:                return "Sync error"
        }
    }

    private var syncDetail: String {
        switch syncManager.state {
        case .unknown:
            return "Waiting for first sync event"
        case .syncing:
            return "Uploading or downloading changes"
        case .synced(let date):
            let formatter = RelativeDateTimeFormatter()
            return "Last synced \(formatter.localizedString(for: date, relativeTo: Date()))"
        case .unavailable(let reason):
            return reason
        case .error(let message):
            return message
        }
    }
}
