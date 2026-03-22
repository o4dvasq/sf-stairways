import SwiftUI
import SwiftData

@main
struct SFStairwaysApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([WalkRecord.self, WalkPhoto.self])

        // Try CloudKit first, fall back to local-only
        var container: ModelContainer?

        do {
            let cloudConfig = ModelConfiguration(
                "SFStairways",
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.o4dvasq.sfstairways")
            )
            container = try ModelContainer(for: schema, configurations: [cloudConfig])
            print("[SFStairways] CloudKit ModelContainer created successfully")
        } catch {
            print("[SFStairways] CloudKit failed: \(error). Falling back to local storage.")
            do {
                let localConfig = ModelConfiguration(
                    "SFStairways",
                    schema: schema,
                    cloudKitDatabase: .none
                )
                container = try ModelContainer(for: schema, configurations: [localConfig])
                print("[SFStairways] Local ModelContainer created successfully")
            } catch {
                fatalError("[SFStairways] Cannot create any ModelContainer: \(error)")
            }
        }

        modelContainer = container!
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    print("[SFStairways] ContentView appeared")
                    let store = StairwayStore()
                    print("[SFStairways] Store loaded \(store.stairways.count) stairways")
                    SeedDataService.seedIfNeeded(modelContext: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
    }
}
