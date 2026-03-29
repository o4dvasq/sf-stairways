import Foundation
import CoreLocation
import SwiftUI

struct Neighborhood: Identifiable {
    let name: String
    let polygons: [[CLLocationCoordinate2D]]   // Outer ring(s) from GeoJSON (MultiPolygon flattened to list)
    let centroid: CLLocationCoordinate2D
    let color: Color

    var id: String { name }
}
