import Foundation
import SwiftData

enum SeedDataService {
    private static let hasSeededTagsKey = "com.sfstairways.hasSeededTags"
    private static let hasCleanedUnwalkedKey = "com.sfstairways.hasCleanedUnwalked"
    private static let hasRunTagDedupKey = "hasRunTagDedupMigration_v1"
    private static let hasRunWalkRecordDedupKey = "hasRunWalkRecordDedupMigration_v1"
    private static let hasCleanedSeedBugRecordsKey = "hasCleanedSeedBugRecords_v1"

    private static let seedBugStairwayIDs: Set<String> = [
        "16th-avenue-tiled-steps",
        "hidden-garden-steps",
        "lincoln-park-steps",
        "vulcan-stairway",
        "saturn-street-west-of-ord-street",
        "pemberton-place-clayton-street-to-villa-terrace",
        "filbert-street-sansome-street-to-montgomery-street",
        "greenwich-street-sansome-street-to-montgomery-street"
    ]

    /// One-time migration: for each stairwayID, keep the WalkRecord with the earliest
    /// createdAt and delete the rest. Cleans up duplicates introduced by CloudKit sync.
    static func deduplicateWalkRecordsIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: hasRunWalkRecordDedupKey) else { return }

        let allRecords = (try? modelContext.fetch(FetchDescriptor<WalkRecord>())) ?? []
        var keepByStairwayID: [String: WalkRecord] = [:]
        var toDelete: [WalkRecord] = []
        for record in allRecords {
            if let existing = keepByStairwayID[record.stairwayID] {
                if record.createdAt < existing.createdAt {
                    toDelete.append(existing)
                    keepByStairwayID[record.stairwayID] = record
                } else {
                    toDelete.append(record)
                }
            } else {
                keepByStairwayID[record.stairwayID] = record
            }
        }
        toDelete.forEach { modelContext.delete($0) }
        if !toDelete.isEmpty {
            try? modelContext.save()
        }
        print("[SeedDataService] WalkRecord dedup: removed \(toDelete.count) duplicates")
        UserDefaults.standard.set(true, forKey: hasRunWalkRecordDedupKey)
    }
    /// One-time migration: delete the eight WalkRecords injected by the old seedIfNeeded()
    /// function. Fingerprint: walked == true, stairwayID in seedBugStairwayIDs, dateWalked
    /// is 2026-03-09 or 2026-03-10. Deletions propagate to CloudKit and other devices.
    static func cleanupSeedBugRecordsIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: hasCleanedSeedBugRecordsKey) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let seedDate1 = formatter.date(from: "2026-03-09"),
              let seedDate2 = formatter.date(from: "2026-03-10") else {
            UserDefaults.standard.set(true, forKey: hasCleanedSeedBugRecordsKey)
            return
        }

        let calendar = Calendar.current
        let descriptor = FetchDescriptor<WalkRecord>(predicate: #Predicate { $0.walked })
        let walkedRecords = (try? modelContext.fetch(descriptor)) ?? []

        var toDelete: [WalkRecord] = []
        for record in walkedRecords {
            guard seedBugStairwayIDs.contains(record.stairwayID),
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

        print("[SeedDataService] Seed bug cleanup: removed \(toDelete.count) records")
        UserDefaults.standard.set(true, forKey: hasCleanedSeedBugRecordsKey)
    }

    /// One-time migration: deduplicate StairwayTag and TagAssignment records, and backfill
    /// TagAssignment.compoundKey. Must run after the ModelContainer is created but before
    /// any tag-related UI is shown.
    static func runTagDedupMigrationIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: hasRunTagDedupKey) else { return }

        // Dedup StairwayTag — keep the earliest by createdAt for each id.
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

        // Dedup TagAssignment — keep the earliest by assignedAt for each (stairwayID, tagID) pair.
        // Also backfill compoundKey for records created before this field existed.
        let allAssignments = (try? modelContext.fetch(FetchDescriptor<TagAssignment>())) ?? []
        var keepByCompoundKey: [String: TagAssignment] = [:]
        var assignmentsToDelete: [TagAssignment] = []
        for assignment in allAssignments {
            if assignment.compoundKey.isEmpty {
                assignment.compoundKey = "\(assignment.stairwayID)::\(assignment.tagID)"
            }
            let key = assignment.compoundKey
            if let existing = keepByCompoundKey[key] {
                if assignment.assignedAt < existing.assignedAt {
                    assignmentsToDelete.append(existing)
                    keepByCompoundKey[key] = assignment
                } else {
                    assignmentsToDelete.append(assignment)
                }
            } else {
                keepByCompoundKey[key] = assignment
            }
        }
        assignmentsToDelete.forEach { modelContext.delete($0) }

        try? modelContext.save()
        print("[SeedDataService] Tag dedup: removed \(tagsToDelete.count) duplicate tags, \(assignmentsToDelete.count) duplicate assignments; backfilled compoundKey on \(allAssignments.count) records")
        UserDefaults.standard.set(true, forKey: hasRunTagDedupKey)
    }

    /// One-time migration: delete any WalkRecord where walked == false.
    /// These were "saved but not walked" records from the old Saved concept, now orphaned.
    static func cleanUnwalkedRecordsIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: hasCleanedUnwalkedKey) else { return }
        let descriptor = FetchDescriptor<WalkRecord>(predicate: #Predicate { !$0.walked })
        let unwalked = (try? modelContext.fetch(descriptor)) ?? []
        for record in unwalked {
            modelContext.delete(record)
        }
        if !unwalked.isEmpty {
            try? modelContext.save()
            print("[SeedDataService] Cleaned up \(unwalked.count) unwalked (saved-only) records")
        }
        UserDefaults.standard.set(true, forKey: hasCleanedUnwalkedKey)
    }

    static func seedTagsIfNeeded(modelContext: ModelContext) {
        // Skip if already seeded
        guard !UserDefaults.standard.bool(forKey: hasSeededTagsKey) else { return }

        // Skip if tags already exist (e.g. synced from another device)
        let descriptor = FetchDescriptor<StairwayTag>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        if existingCount > 0 {
            UserDefaults.standard.set(true, forKey: hasSeededTagsKey)
            return
        }

        guard let url = Bundle.main.url(forResource: "tags_preset", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[SeedDataService] tags_preset.json not found in bundle")
            return
        }

        struct PresetTag: Codable {
            let id: String
            let name: String
        }

        guard let presets = try? JSONDecoder().decode([PresetTag].self, from: data) else {
            print("[SeedDataService] Failed to decode tags_preset.json")
            return
        }

        for (index, preset) in presets.enumerated() {
            let tag = StairwayTag(id: preset.id, name: preset.name, isPreset: true)
            tag.colorIndex = index % 12
            modelContext.insert(tag)
        }

        do {
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: hasSeededTagsKey)
            print("[SeedDataService] Seeded \(presets.count) preset tags")
        } catch {
            print("[SeedDataService] Failed to save preset tags: \(error)")
        }
    }
}
