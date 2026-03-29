import Foundation
import Observation

@Observable
class NavigationCoordinator {
    var pendingStairway: Stairway? = nil
    var pendingNeighborhood: String? = nil
}
