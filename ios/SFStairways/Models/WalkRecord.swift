import Foundation
import SwiftData

@Model
final class WalkRecord {
    var stairwayID: String = ""
    var walked: Bool = false
    var dateWalked: Date?
    var notes: String?
    var stepCount: Int?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var hardMode: Bool = false
    // nil = Hard Mode was never enabled for this record
    // false = Hard Mode enabled, walk predates opt-in (unverified)
    // true = walk occurred within 150m with Hard Mode active
    var proximityVerified: Bool? = nil

    @Relationship(deleteRule: .cascade, inverse: \WalkPhoto.walkRecord)
    var photos: [WalkPhoto]?

    init(
        stairwayID: String,
        walked: Bool = false,
        dateWalked: Date? = nil,
        notes: String? = nil,
        stepCount: Int? = nil
    ) {
        self.stairwayID = stairwayID
        self.walked = walked
        self.dateWalked = dateWalked
        self.notes = notes
        self.stepCount = stepCount
        self.createdAt = Date()
        self.updatedAt = Date()
        self.photos = []
    }

    func toggleWalked() {
        walked.toggle()
        if walked {
            dateWalked = dateWalked ?? Date()
            if hardMode {
                proximityVerified = true
            }
        }
        updatedAt = Date()
    }

    var showUnverifiedBadge: Bool {
        hardMode && walked && proximityVerified == false
    }

    var photoArray: [WalkPhoto] {
        photos ?? []
    }
}
