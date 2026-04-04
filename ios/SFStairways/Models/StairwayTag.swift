import Foundation
import SwiftData

@Model
class StairwayTag {
    // @Attribute(.unique) intentionally absent: SwiftData refuses to open an existing store
    // that has duplicate id values when this constraint is present. The one-time dedup migration
    // (runTagDedupMigrationIfNeeded) must run first to collapse duplicates. Once that migration
    // has shipped and all devices have run it, this constraint can be re-added safely.
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
