import Foundation
import SwiftData

@Model
final class StairwayOverride {
    var stairwayID: String = ""
    var verifiedStepCount: Int? = nil
    var verifiedHeightFt: Double? = nil
    var stairwayDescription: String? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(stairwayID: String) {
        self.stairwayID = stairwayID
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// True when at least one verified field has a non-empty value.
    var hasAnyValue: Bool {
        verifiedStepCount != nil ||
        verifiedHeightFt != nil ||
        (stairwayDescription.map { !$0.isEmpty } ?? false)
    }
}
