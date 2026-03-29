import Foundation
import SwiftData

@Model
class TagAssignment {
    var stairwayID: String = ""
    var tagID: String = ""
    var assignedAt: Date = Date()

    init(stairwayID: String, tagID: String) {
        self.stairwayID = stairwayID
        self.tagID = tagID
        self.assignedAt = Date()
    }
}
