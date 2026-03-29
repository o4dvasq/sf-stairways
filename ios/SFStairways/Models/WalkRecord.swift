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
    // Deprecated — per-stairway hard mode replaced by user-level setting.
    // Read-only for backward compatibility with pre-migration data.
    var hardMode: Bool = false
    var proximityVerified: Bool? = nil
    // Stamped true at walk completion when global Hard Mode was enabled
    var hardModeAtCompletion: Bool = false
    var elevationGain: Double? = nil    // Feet climbed, from HealthKit, nil if not captured
    var walkStartTime: Date? = nil      // Precise session start, used for photo suggestion window
    var walkEndTime: Date? = nil        // Precise session end, used for photo suggestion window

    var dismissedPhotoIDs: [String] = []
    var addedPhotoAssetIDs: [String] = []

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

    // Human-readable label for how the walk was recorded.
    var walkMethod: String {
        if walkStartTime != nil {
            return stepCount != nil || elevationGain != nil ? "Active Walk" : "Active Walk (no HealthKit data)"
        } else {
            return "Logged manually"
        }
    }

    // True when the walk was manually marked and has no HealthKit stats yet —
    // meaning a retroactive pull could add data.
    var canRetroactivelyPullStats: Bool {
        walked && walkStartTime == nil && stepCount == nil && elevationGain == nil
    }
}
