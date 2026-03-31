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

        for preset in presets {
            let tag = StairwayTag(id: preset.id, name: preset.name, isPreset: true)
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
