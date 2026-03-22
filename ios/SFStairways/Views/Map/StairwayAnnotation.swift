import SwiftUI

struct StairwayAnnotation: View {
    let stairway: Stairway
    let walkRecord: WalkRecord?
    var isSelected: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor)
                .frame(width: isSelected ? 20 : 14, height: isSelected ? 20 : 14)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: isSelected ? 3 : 2)
                )
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
        .opacity(stairway.closed ? 0.6 : 1.0)
        .animation(.spring(response: 0.2), value: isSelected)
    }

    private var pinColor: Color {
        if stairway.closed {
            return Color.closedRed
        }
        if let record = walkRecord, record.walked {
            return Color.walkedGreen
        }
        return Color.unwalkedSlate
    }
}
