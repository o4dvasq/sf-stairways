import Foundation
import SwiftData

@Model
final class StairwayDeletion {
    // Note: .unique removed — CloudKit does not support unique constraints.
    // Uniqueness is enforced in app logic (check before insert).
    var stairwayID: String = ""
    var deletedAt: Date = Date()
    var reason: String?

    init(stairwayID: String, deletedAt: Date = Date(), reason: String? = nil) {
        self.stairwayID = stairwayID
        self.deletedAt = deletedAt
        self.reason = reason
    }
}
