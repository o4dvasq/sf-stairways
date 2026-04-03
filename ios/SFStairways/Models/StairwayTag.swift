import Foundation
import SwiftData

@Model
class StairwayTag {
    var id: String = ""
    var name: String = ""
    var isPreset: Bool = false
    var createdAt: Date = Date()
    var colorIndex: Int = 0

    init(id: String, name: String, isPreset: Bool = false) {
        self.id = id
        self.name = name
        self.isPreset = isPreset
        self.createdAt = Date()
    }
}
