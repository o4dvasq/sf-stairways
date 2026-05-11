import AuthenticationServices
import Supabase
import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(SyncStatusManager.self) private var syncManager

    @AppStorage("curatorModeActive") private var curatorModeActive = false
    @AppStorage("hasSeenSignInPrompt") private var hasSeenSignInPrompt = false

    var body: some View {
        NavigationStack {
            List {
                accountSection
                walkingSection
                if authManager.isCurator {
                    curatorSection
                }
                iCloudSection
                buildSection
                acknowledgementsSection
                #if DEBUG
                simulateNewUserSection
                #endif
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

            if let error = authManager.signInError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }
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

            if case .unavailable = syncManager.state {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Common fixes:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("• Sign into iCloud in iOS Settings\n• Enable iCloud Drive\n• Check iCloud > Apps Using iCloud > SFStairways is on")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
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

    // MARK: - Build Info

    private var buildSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "hammer")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(buildVersionString)
                        .font(.subheadline)
                    Text(buildDateString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var buildVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(version) (\(build))"
    }

    private var buildDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Built \(formatter.string(from: buildDate))"
    }

    private var buildDate: Date {
        // __DATE__ and __TIME__ aren't available in Swift, so use the
        // executable's modification date as a reliable build timestamp.
        guard let execURL = Bundle.main.executableURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: execURL.path),
              let date = attrs[.modificationDate] as? Date else {
            return Date()
        }
        return date
    }

    // MARK: - Acknowledgements

    private var acknowledgementsSection: some View {
        Section("Acknowledgements") {
            Text("Data Sources")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Stairway data originally compiled from the index in Stairway Walks in San Francisco by Adah Bakalinsky, maintained at sfstairways.com")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let url = URL(string: "https://www.sfstairways.com") {
                    Link(destination: url) {
                        Label("sfstairways.com", systemImage: "arrow.up.right")
                            .font(.subheadline)
                            .foregroundStyle(Color.forestGreen)
                    }
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("Additional stairway locations from the San Francisco Public Stairway Map by Alexandra Kenin / Urban Hiker SF")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let url = URL(string: "https://www.urbanhikersf.com") {
                    Link(destination: url) {
                        Label("urbanhikersf.com", systemImage: "arrow.up.right")
                            .font(.subheadline)
                            .foregroundStyle(Color.forestGreen)
                    }
                }
                if let url = URL(string: "https://www.google.com/maps/d/viewer?mid=1F4TY3dl4yiG6VBqigpnrFvhsbK_FYcsW") {
                    Link(destination: url) {
                        Label("View the Stairway Map", systemImage: "arrow.up.right")
                            .font(.subheadline)
                            .foregroundStyle(Color.forestGreen)
                    }
                }
            }
            .padding(.vertical, 4)

            if let url = URL(string: "https://buymeacoffee.com/urbanhikersf") {
                Link(destination: url) {
                    HStack(spacing: 10) {
                        Image(systemName: "cup.and.saucer.fill")
                            .foregroundStyle(Color.brandAmber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Buy a Matcha")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Support Alexandra's incredible work cataloging SF's stairways")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 10) {
                Image(systemName: "book.fill")
                    .foregroundStyle(.secondary)
                Text("Stairway Walks in San Francisco by Adah Bakalinsky — the original field guide that started it all")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Debug (DEBUG builds only)

    #if DEBUG
    @State private var simulateNewUserDone = false

    private var simulateNewUserSection: some View {
        Section("Testing") {
            if simulateNewUserDone {
                Label("Done — force-quit and reopen to see the intro", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Simulate New User") {
                        authManager.signOut()
                        hasSeenSignInPrompt = false
                        simulateNewUserDone = true
                    }
                    .foregroundStyle(.red)
                    Text("Signs out and resets the first-launch intro. Force-quit the app, then reopen to see the splash + sign-in prompt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    #endif

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
