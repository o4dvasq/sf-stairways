import Foundation
import SwiftData

@Model
class TagAssignment {
    // compoundKey = "\(stairwayID)::\(tagID)" — used to detect and deduplicate assignments.
    // @Attribute(.unique) is deferred until after all existing records have been backfilled
    // by runTagDedupMigrationIfNeeded(); adding the constraint before backfill would cause
    // all existing rows (compoundKey == "") to conflict at migration time.
    var compoundKey: String = ""
    var stairwayID: String = ""
    var tagID: String = ""
    var assignedAt: Date = Date()

    init(stairwayID: String, tagID: String) {
        self.stairwayID = stairwayID
        self.tagID = tagID
        self.compoundKey = "\(stairwayID)::\(tagID)"
        self.assignedAt = Date()
    }
}
