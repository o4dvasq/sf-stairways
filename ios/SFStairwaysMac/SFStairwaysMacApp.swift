//
//  SFStairwaysMacApp.swift
//  SFStairwaysMac
//
//  Created by Oscar Vasquez on 3/29/26.
//

import SwiftUI
import SwiftData

@main
struct SFStairwaysMacApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            WalkRecord.self,
            WalkPhoto.self,
            StairwayOverride.self,
            StairwayTag.self,
            TagAssignment.self
        ])

        // Attempt CloudKit-backed container using the same container as iOS.
        // Requires: iCloud signed in on Mac, CloudKit schema deployed, entitlement present.
        do {
            let cloudConfig = ModelConfiguration(
                "SFStairways",
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.o4dvasq.sfstairways")
            )
            modelContainer = try ModelContainer(for: schema, configurations: [cloudConfig])
            print("[SFStairwaysMac] CloudKit ModelContainer created successfully")
        } catch {
            print("[SFStairwaysMac] CloudKit init failed: \(error). Falling back to local storage.")
            do {
                let localConfig = ModelConfiguration(
                    "SFStairways",
                    schema: schema,
                    cloudKitDatabase: .none
                )
                modelContainer = try ModelContainer(for: schema, configurations: [localConfig])
                print("[SFStairwaysMac] Local ModelContainer created successfully")
            } catch {
                fatalError("[SFStairwaysMac] Cannot create any ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            StairwayBrowser()
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1200, height: 720)
    }
}
