import Foundation
import SwiftData

@Model
final class StairwayDeletion {
    @Attribute(.unique) var stairwayID: String
    var deletedAt: Date
    var reason: String?

    init(stairwayID: String, deletedAt: Date = Date(), reason: String? = nil) {
        self.stairwayID = stairwayID
        self.deletedAt = deletedAt
        self.reason = reason
    }
}
