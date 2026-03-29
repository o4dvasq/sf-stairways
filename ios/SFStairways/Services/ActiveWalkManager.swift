import Foundation
import Combine

@Observable class ActiveWalkManager {
    var activeStairwayID: String? = nil
    var activeStairwayName: String? = nil
    var sessionStartTime: Date? = nil
    var elapsedSeconds: Int = 0

    @ObservationIgnored
    private var timerCancellable: AnyCancellable?

    var hasActiveSession: Bool { activeStairwayID != nil }

    func isActive(for stairwayID: String) -> Bool {
        activeStairwayID == stairwayID
    }

    func startWalk(stairwayID: String, name: String) {
        activeStairwayID = stairwayID
        activeStairwayName = name
        sessionStartTime = Date()
        elapsedSeconds = 0
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    // Returns (startTime, endTime) and clears session state.
    func endWalk() -> (startTime: Date, endTime: Date)? {
        guard let start = sessionStartTime else { return nil }
        let end = Date()
        clearState()
        return (start, end)
    }

    func cancelWalk() {
        clearState()
    }

    private func clearState() {
        timerCancellable?.cancel()
        timerCancellable = nil
        activeStairwayID = nil
        activeStairwayName = nil
        sessionStartTime = nil
        elapsedSeconds = 0
    }
}
