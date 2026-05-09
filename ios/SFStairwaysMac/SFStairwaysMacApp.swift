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
            TagAssignment.self,
            StairwayDeletion.self
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
                .onAppear {
                    runTagDedupMigrationIfNeeded(modelContext: modelContainer.mainContext)
                    cleanupSeedBugRecordsIfNeeded(modelContext: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1200, height: 720)
    }

    // Mirrors SeedDataService.cleanupSeedBugRecordsIfNeeded — inlined here because
    // SeedDataService.swift is not in the Mac target membership.
    private func cleanupSeedBugRecordsIfNeeded(modelContext: ModelContext) {
        let migrationKey = "hasCleanedSeedBugRecords_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let seedDate1 = formatter.date(from: "2026-03-09"),
              let seedDate2 = formatter.date(from: "2026-03-10") else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        let seedBugIDs: Set<String> = [
            "16th-avenue-tiled-steps",
            "hidden-garden-steps",
            "lincoln-park-steps",
            "vulcan-stairway",
            "saturn-street-west-of-ord-street",
            "pemberton-place-clayton-street-to-villa-terrace",
            "filbert-street-sansome-street-to-montgomery-street",
            "greenwich-street-sansome-street-to-montgomery-street"
        ]

        let calendar = Calendar.current
        let descriptor = FetchDescriptor<WalkRecord>(predicate: #Predicate { $0.walked })
        let walkedRecords = (try? modelContext.fetch(descriptor)) ?? []

        var toDelete: [WalkRecord] = []
        for record in walkedRecords {
            guard seedBugIDs.contains(record.stairwayID),
                  let dateWalked = record.dateWalked else { continue }
            if calendar.isDate(dateWalked, inSameDayAs: seedDate1) ||
               calendar.isDate(dateWalked, inSameDayAs: seedDate2) {
                toDelete.append(record)
            }
        }

        toDelete.forEach { modelContext.delete($0) }
        if !toDelete.isEmpty {
            try? modelContext.save()
        }

        print("[SFStairwaysMac] Seed bug cleanup: removed \(toDelete.count) records")
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    // Mirrors SeedDataService.runTagDedupMigrationIfNeeded — inlined here because
    // SeedDataService.swift is not in the Mac target membership.
    private func runTagDedupMigrationIfNeeded(modelContext: ModelContext) {
        let migrationKey = "hasRunTagDedupMigration_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let allTags = (try? modelContext.fetch(FetchDescriptor<StairwayTag>())) ?? []
        var keepByTagID: [String: StairwayTag] = [:]
        var tagsToDelete: [StairwayTag] = []
        for tag in allTags {
            if let existing = keepByTagID[tag.id] {
                if tag.createdAt < existing.createdAt {
                    tagsToDelete.append(existing)
                    keepByTagID[tag.id] = tag
                } else {
                    tagsToDelete.append(tag)
                }
            } else {
                keepByTagID[tag.id] = tag
            }
        }
        tagsToDelete.forEach { modelContext.delete($0) }

        let allAssignments = (try? modelContext.fetch(FetchDescriptor<TagAssignment>())) ?? []
        var keepByKey: [String: TagAssignment] = [:]
        var assignmentsToDelete: [TagAssignment] = []
        for assignment in allAssignments {
            if assignment.compoundKey.isEmpty {
                assignment.compoundKey = "\(assignment.stairwayID)::\(assignment.tagID)"
            }
            let key = assignment.compoundKey
            if let existing = keepByKey[key] {
                if assignment.assignedAt < existing.assignedAt {
                    assignmentsToDelete.append(existing)
                    keepByKey[key] = assignment
                } else {
                    assignmentsToDelete.append(assignment)
                }
            } else {
                keepByKey[key] = assignment
            }
        }
        assignmentsToDelete.forEach { modelContext.delete($0) }

        try? modelContext.save()
        print("[SFStairwaysMac] Tag dedup: removed \(tagsToDelete.count) duplicate tags, \(assignmentsToDelete.count) duplicate assignments")
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
