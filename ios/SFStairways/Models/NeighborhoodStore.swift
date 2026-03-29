import Foundation
import CoreLocation
import SwiftUI
import Observation

/// Single source of truth for all neighborhood data.
/// Loads `sf_neighborhoods.geojson` at startup, computes centroids and adjacency
/// from polygon geometry, and exposes lookups used by the rest of the app.
@Observable
final class NeighborhoodStore {

    // MARK: - Public State

    private(set) var neighborhoods: [Neighborhood] = []
    private(set) var adjacency: [String: Set<String>] = [:]

    // MARK: - Init

    init() {
        let raw = loadGeoJSON()
        let assigned = assignColors(raw)
        neighborhoods = assigned
        adjacency = computeAdjacency(assigned)
        print("[NeighborhoodStore] Loaded \(neighborhoods.count) neighborhoods, computed \(adjacency.count) adjacency entries")
    }

    // MARK: - Public API

    /// Returns the neighborhood whose polygon contains the given coordinate.
    /// Falls back to nearest centroid if outside all polygons.
    func neighborhood(for coordinate: CLLocationCoordinate2D) -> Neighborhood? {
        // Point-in-polygon first
        for n in neighborhoods {
            if containsPoint(coordinate, polygons: n.polygons) {
                return n
            }
        }
        // Nearest centroid fallback
        return neighborhoods.min(by: {
            distance($0.centroid, coordinate) < distance($1.centroid, coordinate)
        })
    }

    func neighborhood(named name: String) -> Neighborhood? {
        neighborhoods.first { $0.name == name }
    }

    func neighbors(of name: String) -> Set<String> {
        adjacency[name] ?? []
    }

    func centroid(for name: String) -> CLLocationCoordinate2D? {
        neighborhood(named: name)?.centroid
    }

    // MARK: - GeoJSON Loading

    private struct GeoJSONFeature: Decodable {
        struct Properties: Decodable {
            let nhood: String
        }
        struct Geometry: Decodable {
            let type: String
            // coordinates is either [[[Double]]] (Polygon) or [[[[Double]]]] (MultiPolygon)
            // Decoded as raw JSON and parsed manually
        }
        let properties: Properties
        let geometry: RawGeometry
    }

    private struct RawGeometry: Decodable {
        let type: String
        let coordinates: CoordinatePayload

        enum CodingKeys: String, CodingKey {
            case type, coordinates
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(String.self, forKey: .type)
            coordinates = try container.decode(CoordinatePayload.self, forKey: .coordinates)
        }
    }

    // Handles both Polygon ([[[Double]]]) and MultiPolygon ([[[[Double]]]]) shapes
    private enum CoordinatePayload: Decodable {
        case polygon([[[Double]]])
        case multiPolygon([[[[Double]]]])

        init(from decoder: Decoder) throws {
            // Try MultiPolygon (4D) first, then Polygon (3D)
            if let mp = try? decoder.singleValueContainer().decode([[[[Double]]]].self) {
                self = .multiPolygon(mp)
            } else if let p = try? decoder.singleValueContainer().decode([[[Double]]].self) {
                self = .polygon(p)
            } else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown coordinate shape"))
            }
        }

        // Returns a list of outer rings (one per polygon/sub-polygon)
        var outerRings: [[CLLocationCoordinate2D]] {
            switch self {
            case .polygon(let rings):
                return rings.prefix(1).map { ring in ring.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) } }
            case .multiPolygon(let polygons):
                return polygons.map { rings in
                    rings[0].map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                }
            }
        }
    }

    private struct GeoJSONRoot: Decodable {
        struct Feature: Decodable {
            struct Properties: Decodable { let nhood: String }
            let properties: Properties
            let geometry: RawGeometry
        }
        let features: [Feature]
    }

    private func loadGeoJSON() -> [(name: String, polygons: [[CLLocationCoordinate2D]])] {
        guard let url = Bundle.main.url(forResource: "sf_neighborhoods", withExtension: "geojson"),
              let data = try? Data(contentsOf: url)
        else {
            print("[NeighborhoodStore] ERROR: sf_neighborhoods.geojson not found in bundle")
            return []
        }

        do {
            let root = try JSONDecoder().decode(GeoJSONRoot.self, from: data)
            return root.features.map { feature in
                let polygons = feature.geometry.coordinates.outerRings
                return (name: feature.properties.nhood, polygons: polygons)
            }
        } catch {
            print("[NeighborhoodStore] ERROR: Failed to parse GeoJSON: \(error)")
            return []
        }
    }

    // MARK: - Color Assignment

    // Pastel palette for map overlays. Assigned round-robin by sorted name so
    // assignment is stable and adjacent neighborhoods tend to get different colors.
    private let palette: [Color] = [
        Color(red: 0.96, green: 0.76, blue: 0.76),  // soft rose
        Color(red: 0.76, green: 0.88, blue: 0.96),  // sky blue
        Color(red: 0.80, green: 0.96, blue: 0.80),  // mint green
        Color(red: 0.96, green: 0.92, blue: 0.76),  // warm yellow
        Color(red: 0.88, green: 0.80, blue: 0.96),  // lavender
        Color(red: 0.96, green: 0.84, blue: 0.76),  // peach
        Color(red: 0.76, green: 0.96, blue: 0.92),  // aqua
        Color(red: 0.92, green: 0.76, blue: 0.88),  // pink-purple
    ]

    private func assignColors(_ raw: [(name: String, polygons: [[CLLocationCoordinate2D]])]) -> [Neighborhood] {
        let sorted = raw.sorted { $0.name < $1.name }
        return sorted.enumerated().map { index, entry in
            let centroid = computeCentroid(entry.polygons)
            let color = palette[index % palette.count]
            return Neighborhood(name: entry.name, polygons: entry.polygons, centroid: centroid, color: color)
        }
    }

    // MARK: - Centroid Computation

    private func computeCentroid(_ polygons: [[CLLocationCoordinate2D]]) -> CLLocationCoordinate2D {
        // Use the largest polygon's outer ring
        guard let largest = polygons.max(by: { $0.count < $1.count }), !largest.isEmpty else {
            return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        }
        let lat = largest.map(\.latitude).reduce(0, +) / Double(largest.count)
        let lng = largest.map(\.longitude).reduce(0, +) / Double(largest.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    // MARK: - Adjacency Computation

    // Two neighborhoods are adjacent if any vertex of one polygon is within
    // ~100m of any vertex of the other, or if their polygons share a border
    // segment. We use a grid-bucketing approach: snap each vertex to a
    // ~100m grid cell and mark any neighborhoods sharing a cell as adjacent.
    private func computeAdjacency(_ hoods: [Neighborhood]) -> [String: Set<String>] {
        // Grid cell size in degrees (~90m at SF latitude)
        let cellSize = 0.001

        // Build cell → neighborhood name map
        var cellToNames: [String: Set<String>] = [:]
        for hood in hoods {
            for ring in hood.polygons {
                for coord in ring {
                    let key = gridKey(coord, cellSize: cellSize)
                    cellToNames[key, default: []].insert(hood.name)
                }
            }
        }

        // Any cell with 2+ neighborhoods → those neighborhoods are adjacent
        var adj: [String: Set<String>] = [:]
        for (_, names) in cellToNames where names.count > 1 {
            let sorted = Array(names)
            for i in 0..<sorted.count {
                for j in (i + 1)..<sorted.count {
                    adj[sorted[i], default: []].insert(sorted[j])
                    adj[sorted[j], default: []].insert(sorted[i])
                }
            }
        }
        return adj
    }

    private func gridKey(_ coord: CLLocationCoordinate2D, cellSize: Double) -> String {
        let latCell = Int(coord.latitude / cellSize)
        let lngCell = Int(coord.longitude / cellSize)
        return "\(latCell),\(lngCell)"
    }

    // MARK: - Point-in-Polygon (Ray Casting)

    private func containsPoint(_ point: CLLocationCoordinate2D, polygons: [[CLLocationCoordinate2D]]) -> Bool {
        for ring in polygons {
            if raycast(point, ring: ring) {
                return true
            }
        }
        return false
    }

    private func raycast(_ point: CLLocationCoordinate2D, ring: [CLLocationCoordinate2D]) -> Bool {
        let lat = point.latitude
        let lng = point.longitude
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let xi = ring[i].longitude, yi = ring[i].latitude
            let xj = ring[j].longitude, yj = ring[j].latitude
            if ((yi > lat) != (yj > lat)) && (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    // MARK: - Helpers

    private func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let loc2 = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return loc1.distance(from: loc2)
    }
}
