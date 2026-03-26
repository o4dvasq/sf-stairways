import Foundation
import CoreLocation
import Observation

/// Manages the "Around Me" neighborhood-aware filter.
///
/// Loads pre-computed neighborhood centroids and adjacency data from bundled JSON.
/// Uses nearest-centroid lookup to determine the user's current neighborhood,
/// then highlights that neighborhood and its adjacent neighbors on the map.
@Observable
final class AroundMeManager {

    // MARK: - Public State

    private(set) var isActive: Bool = false
    private(set) var currentNeighborhood: String? = nil
    private(set) var highlightedNeighborhoods: Set<String> = []

    // MARK: - Private

    private struct Centroid {
        let lat: Double
        let lng: Double
    }

    private var centroids: [String: Centroid] = [:]
    private var adjacency: [String: [String]] = [:]

    // Max distance from any SF neighborhood centroid to be considered "in SF"
    private let maxSFDistanceMeters: CLLocationDistance = 5000

    init() {
        loadCentroids()
        loadAdjacency()
    }

    // MARK: - Public API

    /// Activate Around Me for the given location. Returns a toast message if there's an issue.
    func activate(location: CLLocation) -> String? {
        guard let neighborhood = findNeighborhood(for: location) else {
            return "Around Me works within San Francisco"
        }

        currentNeighborhood = neighborhood
        var highlighted: Set<String> = [neighborhood]
        if let neighbors = adjacency[neighborhood] {
            highlighted.formUnion(neighbors)
        }
        highlightedNeighborhoods = highlighted
        isActive = true
        return nil
    }

    func deactivate() {
        isActive = false
        currentNeighborhood = nil
        highlightedNeighborhoods = []
    }

    /// Returns true when Around Me is active and this neighborhood is NOT highlighted.
    func isDimmed(neighborhood: String) -> Bool {
        guard isActive else { return false }
        return !highlightedNeighborhoods.contains(neighborhood)
    }

    // MARK: - Neighborhood Detection

    private func findNeighborhood(for location: CLLocation) -> String? {
        var nearest: String? = nil
        var nearestDist: CLLocationDistance = .greatestFiniteMagnitude

        for (name, centroid) in centroids {
            let centroidLocation = CLLocation(latitude: centroid.lat, longitude: centroid.lng)
            let dist = location.distance(from: centroidLocation)
            if dist < nearestDist {
                nearestDist = dist
                nearest = name
            }
        }

        return nearestDist < maxSFDistanceMeters ? nearest : nil
    }

    // MARK: - Data Loading

    private func loadCentroids() {
        guard let url = Bundle.main.url(forResource: "neighborhood_centroids", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [String: Double]].self, from: data)
        else {
            print("[AroundMeManager] Failed to load neighborhood_centroids.json")
            return
        }

        centroids = raw.compactMapValues { dict in
            guard let lat = dict["lat"], let lng = dict["lng"] else { return nil }
            return Centroid(lat: lat, lng: lng)
        }
        print("[AroundMeManager] Loaded \(centroids.count) neighborhood centroids")
    }

    private func loadAdjacency() {
        guard let url = Bundle.main.url(forResource: "neighborhood_adjacency", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [String]].self, from: data)
        else {
            print("[AroundMeManager] Failed to load neighborhood_adjacency.json")
            return
        }

        adjacency = raw
        print("[AroundMeManager] Loaded adjacency for \(adjacency.count) neighborhoods")
    }
}
