import Foundation
import MapKit
import SwiftData
import Observation

@Observable
final class StairwayStore {
    private(set) var stairways: [Stairway] = []
    private(set) var neighborhoodGroups: [(name: String, stairways: [Stairway])] = []

    init() {
        loadStairways()
    }

    private func loadStairways() {
        // Try multiple approaches to find the file
        var url: URL?

        // Approach 1: Standard bundle lookup
        url = Bundle.main.url(forResource: "all_stairways", withExtension: "json")

        // Approach 2: Look in a Resources subdirectory
        if url == nil {
            url = Bundle.main.url(forResource: "all_stairways", withExtension: "json", subdirectory: "Resources")
        }

        // Approach 3: Search the entire bundle
        if url == nil {
            if let bundlePath = Bundle.main.resourcePath {
                let fileManager = FileManager.default
                if let enumerator = fileManager.enumerator(atPath: bundlePath) {
                    while let file = enumerator.nextObject() as? String {
                        if file.hasSuffix("all_stairways.json") {
                            url = URL(fileURLWithPath: bundlePath).appendingPathComponent(file)
                            print("[SFStairways] Found JSON via search at: \(file)")
                            break
                        }
                    }
                }
            }
        }

        // Debug: list all JSON files in bundle
        if url == nil {
            print("[SFStairways] ERROR: all_stairways.json not found anywhere in bundle")
            if let bundlePath = Bundle.main.resourcePath {
                let fileManager = FileManager.default
                if let enumerator = fileManager.enumerator(atPath: bundlePath) {
                    var jsonFiles: [String] = []
                    while let file = enumerator.nextObject() as? String {
                        if file.hasSuffix(".json") {
                            jsonFiles.append(file)
                        }
                    }
                    print("[SFStairways] All JSON files in bundle: \(jsonFiles)")
                }
            }
            return
        }

        print("[SFStairways] Loading stairways from: \(url!)")

        guard let data = try? Data(contentsOf: url!) else {
            print("[SFStairways] ERROR: Could not read data from \(url!)")
            return
        }

        let decoder = JSONDecoder()
        do {
            stairways = try decoder.decode([Stairway].self, from: data)
            print("[SFStairways] Loaded \(stairways.count) stairways successfully")
            buildNeighborhoodGroups()
        } catch {
            print("[SFStairways] ERROR: Failed to decode stairways: \(error)")
        }
    }

    private func buildNeighborhoodGroups() {
        let grouped = Dictionary(grouping: stairways, by: \.neighborhood)
        neighborhoodGroups = grouped
            .map { (name: $0.key, stairways: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.name < $1.name }
    }

    func stairway(for id: String) -> Stairway? {
        stairways.first { $0.id == id }
    }

    func stairways(in neighborhood: String) -> [Stairway] {
        stairways.filter { $0.neighborhood == neighborhood }
    }

    func search(_ query: String) -> [Stairway] {
        guard !query.isEmpty else { return stairways }
        let lowered = query.lowercased()
        return stairways.filter {
            $0.name.lowercased().contains(lowered) ||
            $0.neighborhood.lowercased().contains(lowered)
        }
    }

    /// Search by stairway name only. "Street" tab uses this since street info
    /// is embedded in most stairway names (e.g. "Vulcan Street Steps").
    func searchByName(_ query: String) -> [Stairway] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        return stairways.filter { $0.name.lowercased().contains(lowered) }
    }

    /// Search neighborhoods by name, returning groups sorted by name.
    /// Empty query returns all neighborhoods.
    func searchByNeighborhood(_ query: String) -> [(name: String, stairways: [Stairway])] {
        let lowered = query.lowercased()
        return neighborhoodGroups.filter { group in
            query.isEmpty || group.name.lowercased().contains(lowered)
        }
    }

    /// Returns the map region that fits all stairways in a given neighborhood.
    func region(for neighborhood: String) -> MKCoordinateRegion? {
        let coords = stairways(in: neighborhood).compactMap(\.coordinate)
        guard !coords.isEmpty else { return nil }

        let minLat = coords.map(\.latitude).min()!
        let maxLat = coords.map(\.latitude).max()!
        let minLng = coords.map(\.longitude).min()!
        let maxLng = coords.map(\.longitude).max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        // Add 20% padding around the bounding box
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
            longitudeDelta: max((maxLng - minLng) * 1.4, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
