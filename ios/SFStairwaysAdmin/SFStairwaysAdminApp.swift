import SwiftUI
import SwiftData

@main
struct SFStairwaysAdminApp: App {
    let modelContainer: ModelContainer
    let syncStatusManager: SyncStatusManager

    init() {
        let schema = Schema([
            WalkRecord.self,
            WalkPhoto.self,
            StairwayOverride.self,
            StairwayTag.self,
            TagAssignment.self,
            StairwayDeletion.self
        ])
        let manager = SyncStatusManager()

        do {
            let cloudConfig = ModelConfiguration(
                "SFStairways",
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.o4dvasq.sfstairways")
            )
            modelContainer = try ModelContainer(for: schema, configurations: [cloudConfig])
            print("[SFStairwaysAdmin] CloudKit ModelContainer created successfully")
        } catch {
            let nsError = error as NSError
            print("[SFStairwaysAdmin] CloudKit init failed — \(nsError). Falling back to local storage.")
            manager.markUnavailable(reason: nsError.localizedDescription)
            do {
                let localConfig = ModelConfiguration(
                    "SFStairways",
                    schema: schema,
                    cloudKitDatabase: .none
                )
                modelContainer = try ModelContainer(for: schema, configurations: [localConfig])
                print("[SFStairwaysAdmin] Local ModelContainer created successfully")
            } catch {
                fatalError("[SFStairwaysAdmin] Cannot create any ModelContainer: \(error)")
            }
        }

        syncStatusManager = manager
    }

    var body: some Scene {
        WindowGroup {
            AdminBrowser()
        }
        .modelContainer(modelContainer)
        .environment(syncStatusManager)
    }
}
