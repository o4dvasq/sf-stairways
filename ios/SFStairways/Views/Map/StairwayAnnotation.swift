import SwiftUI

struct StairwayAnnotation: View {
    let stairway: Stairway
    let walkRecord: WalkRecord?
    var isSelected: Bool = false
    var isDimmed: Bool = false
    var scale: CGFloat = 1.0

    var body: some View {
        StairwayPin(
            state: pinState,
            isSelected: isSelected,
            isDimmed: isDimmed,
            isClosed: stairway.closed,
            scale: scale
        )
    }

    private var pinState: StairwayPin.PinState {
        guard let record = walkRecord, record.walked else { return .unsaved }
        return .walked
    }
}
