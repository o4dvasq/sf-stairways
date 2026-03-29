import Foundation
import CoreLocation
import Observation

/// Manages the "Around Me" neighborhood-aware filter.
///
/// Receives a NeighborhoodStore at activation time so it can be initialized
/// as a @State property without requiring the environment to be available yet.
/// Uses nearest-centroid lookup to determine the user's current neighborhood,
/// then highlights that neighborhood and its adjacent neighbors.
@Observable
final class AroundMeManager {

    // MARK: - Public State

    private(set) var isActive: Bool = false
    private(set) var currentNeighborhood: String? = nil
    private(set) var highlightedNeighborhoods: Set<String> = []

    // MARK: - Private

    // Max distance from any SF neighborhood centroid to be considered "in SF"
    private let maxSFDistanceMeters: CLLocationDistance = 5000

    // MARK: - Public API

    /// Activate Around Me for the given location. Returns a toast message if there's an issue.
    func activate(location: CLLocation, store: NeighborhoodStore) -> String? {
        guard let neighborhood = findNeighborhood(for: location, store: store) else {
            return "Around Me works within San Francisco"
        }

        currentNeighborhood = neighborhood
        var highlighted: Set<String> = [neighborhood]
        highlighted.formUnion(store.neighbors(of: neighborhood))
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

    private func findNeighborhood(for location: CLLocation, store: NeighborhoodStore) -> String? {
        var nearest: String? = nil
        var nearestDist: CLLocationDistance = .greatestFiniteMagnitude

        for hood in store.neighborhoods {
            let centroidLocation = CLLocation(latitude: hood.centroid.latitude, longitude: hood.centroid.longitude)
            let dist = location.distance(from: centroidLocation)
            if dist < nearestDist {
                nearestDist = dist
                nearest = hood.name
            }
        }

        return nearestDist < maxSFDistanceMeters ? nearest : nil
    }
}
