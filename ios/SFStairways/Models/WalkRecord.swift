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
        }
        updatedAt = Date()
    }

    var photoArray: [WalkPhoto] {
        photos ?? []
    }
}
