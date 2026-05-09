import SwiftUI
import SwiftData

@main
struct SFStairwaysApp: App {
    let modelContainer: ModelContainer
    let syncStatusManager: SyncStatusManager
    let authManager: AuthManager
    let neighborhoodStore = NeighborhoodStore()
    let communityService = CommunityService()

    init() {
        let schema = Schema([WalkRecord.self, WalkPhoto.self, StairwayOverride.self, StairwayTag.self, TagAssignment.self, StairwayDeletion.self])
        let manager = SyncStatusManager()

        // Attempt CloudKit-backed container. Common failure reasons:
        //   - iCloud not signed in on device
        //   - CloudKit schema not deployed in Dashboard (container: iCloud.com.o4dvasq.sfstairways)
        //   - Background Modes → Remote Notifications not enabled in Xcode target capabilities
        //   - Running in Simulator (CloudKit push sync requires physical device)
        do {
            let cloudConfig = ModelConfiguration(
                "SFStairways",
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.o4dvasq.sfstairways")
            )
            modelContainer = try ModelContainer(for: schema, configurations: [cloudConfig])
            print("[SFStairways] CloudKit ModelContainer created successfully")
        } catch {
            let nsError = error as NSError
            print("[SFStairways] CloudKit init failed — domain=\(nsError.domain) code=\(nsError.code): \(nsError.localizedDescription)")
            print("[SFStairways] Falling back to local storage. Fix CloudKit config and reinstall to enable sync.")
            let unavailableReason: String
            if nsError.domain == "SwiftData.SwiftDataError" && nsError.code == 1 {
                unavailableReason = "CloudKit schema needs updating — open Xcode and deploy the schema to CloudKit Dashboard (container: iCloud.com.o4dvasq.sfstairways)"
            } else {
                unavailableReason = nsError.localizedDescription
            }
            manager.markUnavailable(reason: unavailableReason)

            do {
                let localConfig = ModelConfiguration(
                    "SFStairways",
                    schema: schema,
                    cloudKitDatabase: .none
                )
                modelContainer = try ModelContainer(for: schema, configurations: [localConfig])
                print("[SFStairways] Local ModelContainer created successfully")
            } catch {
                fatalError("[SFStairways] Cannot create any ModelContainer: \(error)")
            }
        }

        syncStatusManager = manager
        authManager = AuthManager()
    }

    @State private var showSplash = true
    @State private var showSignInPrompt = false
    @AppStorage("hasSeenSignInPrompt") private var hasSeenSignInPrompt = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .preferredColorScheme(.light)
                    .onAppear {
                        print("[SFStairways] ContentView appeared")
                        let store = StairwayStore()
                        print("[SFStairways] Store loaded \(store.stairways.count) stairways")
                        SeedDataService.runTagDedupMigrationIfNeeded(modelContext: modelContainer.mainContext)
                        SeedDataService.deduplicateWalkRecordsIfNeeded(modelContext: modelContainer.mainContext)
                        SeedDataService.cleanupSeedBugRecordsIfNeeded(modelContext: modelContainer.mainContext)
                        SeedDataService.seedTagsIfNeeded(modelContext: modelContainer.mainContext)
                        SeedDataService.cleanUnwalkedRecordsIfNeeded(modelContext: modelContainer.mainContext)
                        Task { await communityService.fetchClimbCounts() }
                    }
                    .onChange(of: authManager.isLoading) { _, loading in
                        // Edge case: auth check finishes after the splash has already dismissed.
                        if !loading && !showSplash && !authManager.isAuthenticated && !hasSeenSignInPrompt {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showSignInPrompt = true
                            }
                        }
                    }
                    .onChange(of: authManager.isAuthenticated) { _, authenticated in
                        // Dismiss the prompt as soon as sign-in succeeds.
                        if authenticated && showSignInPrompt {
                            hasSeenSignInPrompt = true
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showSignInPrompt = false
                            }
                        }
                    }

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    showSplash = false
                                }
                                // Show sign-in prompt after the splash fades if auth check is
                                // already done and the user is not signed in.
                                if !authManager.isLoading && !authManager.isAuthenticated && !hasSeenSignInPrompt {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        withAnimation(.easeInOut(duration: 0.4)) {
                                            showSignInPrompt = true
                                        }
                                    }
                                }
                            }
                        }
                }

                if showSignInPrompt {
                    SignInPromptView(onMaybeLater: {
                        hasSeenSignInPrompt = true
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showSignInPrompt = false
                        }
                    })
                    .transition(.opacity)
                }
            }
        }
        .modelContainer(modelContainer)
        .environment(syncStatusManager)
        .environment(authManager)
        .environment(neighborhoodStore)
        .environment(communityService)
    }
}
