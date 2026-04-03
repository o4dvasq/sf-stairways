import Foundation

struct NuggetProvider {
    private struct NuggetFact: Decodable {
        let id: String
        let neighborhood: String?
        let fact: String
    }

    private let facts: [NuggetFact]

    init() {
        guard
            let url = Bundle.main.url(forResource: "neighborhood_facts", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([NuggetFact].self, from: data)
        else {
            facts = []
            return
        }
        facts = decoded
    }

    // Returns the static fact for a specific neighborhood, or nil if none exists.
    func fact(for neighborhood: String) -> String? {
        facts.first { $0.neighborhood == neighborhood }?.fact
    }

    // Returns a global (non-neighborhood) fact rotated by a seed value.
    // Pass Calendar.current.ordinality(of: .day, in: .year, for: Date()) for a daily rotation.
    func globalFact(seed: Int) -> String? {
        let globals = facts.filter { $0.neighborhood == nil }
        guard !globals.isEmpty else { return nil }
        return globals[abs(seed) % globals.count].fact
    }
}
