import Foundation
import SwiftData

struct SeedStairway: Codable {
    let id: String
    let name: String
    let neighborhood: String
    let lat: Double
    let lng: Double
    let walked: Bool
    let dateWalked: String?
    let notes: String?
    let photoURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, neighborhood, lat, lng, walked, notes
        case dateWalked = "date_walked"
        case photoURL = "photo_url"
    }
}

enum SeedDataService {
    private static let hasSeededKey = "com.sfstairways.hasSeededData"
    private static let hasSeededTagsKey = "com.sfstairways.hasSeededTags"
    private static let hasCleanedUnwalkedKey = "com.sfstairways.hasCleanedUnwalked"
    private static let hasRunTagDedupKey = "hasRunTagDedupMigration_v1"
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

    static func seedIfNeeded(modelContext: ModelContext) {
        // Check for existing records first — CloudKit may have already delivered data
        // from another device before this call, making seeding unnecessary.
        let descriptor = FetchDescriptor<WalkRecord>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        if existingCount > 0 {
            print("[SeedDataService] Skipping seed — \(existingCount) records already exist")
            UserDefaults.standard.set(true, forKey: hasSeededKey)
            return
        }

        guard !UserDefaults.standard.bool(forKey: hasSeededKey) else { return }

        guard let url = Bundle.main.url(forResource: "target_list", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("target_list.json not found in bundle")
            return
        }

        let decoder = JSONDecoder()
        guard let seeds = try? decoder.decode([SeedStairway].self, from: data) else {
            print("Failed to decode target_list.json")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for seed in seeds {
            let record = WalkRecord(
                stairwayID: seed.id,
                walked: seed.walked,
                dateWalked: seed.dateWalked.flatMap { dateFormatter.date(from: $0) },
                notes: seed.notes
            )
            modelContext.insert(record)
        }

        do {
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: hasSeededKey)
            print("Seeded \(seeds.count) walk records from target_list.json")
        } catch {
            print("Failed to save seed data: \(error)")
        }
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
