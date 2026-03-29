import Foundation
import CoreLocation

struct Stairway: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let neighborhood: String
    let lat: Double?
    let lng: Double?
    let heightFt: Double?
    let closed: Bool
    let geocodeSource: String?
    let sourceURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, neighborhood, lat, lng, closed
        case heightFt = "height_ft"
        case geocodeSource = "geocode_source"
        case sourceURL = "source_url"
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = lat, let lng = lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var hasValidCoordinate: Bool {
        lat != nil && lng != nil
    }

    func distance(from location: CLLocation) -> CLLocationDistance {
        guard let lat = lat, let lng = lng else { return .greatestFiniteMagnitude }
        let stairLocation = CLLocation(latitude: lat, longitude: lng)
        return location.distance(from: stairLocation)
    }

    /// Truncated name for map pin labels: first 4 words, trailing .,; stripped from each.
    /// Full `name` is used everywhere else (detail sheet, list, search, progress tab).
    var displayName: String {
        let words = name.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard words.count > 4 else { return name }
        let truncated = words.prefix(4).map { word -> String in
            var w = word
            while let last = w.last, ".,;".contains(last) { w.removeLast() }
            return w
        }.filter { !$0.isEmpty }
        return truncated.joined(separator: " ")
    }
}
