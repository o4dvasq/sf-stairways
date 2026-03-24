import Foundation
import SwiftData

struct SeedStairway: Codable {
    let id: String
    let name: String
    let neighborhood: String
    let lat: Double
    let lng: Double
    let stepCount: Int?
    let walked: Bool
    let dateWalked: String?
    let notes: String?
    let photoURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, neighborhood, lat, lng, walked, notes
        case stepCount = "step_count"
        case dateWalked = "date_walked"
        case photoURL = "photo_url"
    }
}

enum SeedDataService {
    private static let hasSeededKey = "com.sfstairways.hasSeededData"

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
                notes: seed.notes,
                stepCount: seed.stepCount
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
}
