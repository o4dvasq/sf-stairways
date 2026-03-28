import SwiftUI

struct StairwayAnnotation: View {
    let stairway: Stairway
    let walkRecord: WalkRecord?
    var isSelected: Bool = false
    var isDimmed: Bool = false

    var body: some View {
        StairwayPin(
            state: pinState,
            isSelected: isSelected,
            isDimmed: isDimmed,
            isClosed: stairway.closed
        )
    }

    private var pinState: StairwayPin.PinState {
        guard let record = walkRecord else { return .unsaved }
        return record.walked ? .walked : .saved
    }
}
