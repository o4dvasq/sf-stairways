import SwiftUI

// MARK: - Teardrop Shape

/// Classic map-pin teardrop: a full circle bulb on top tapering to a point at the bottom.
struct TeardropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let r = w / 2.0
        let center = CGPoint(x: w / 2, y: r)

        // Start at the bottom point, draw left side up to the circle,
        // arc around the top, then right side back down.
        path.move(to: CGPoint(x: w / 2, y: h))
        path.addLine(to: CGPoint(x: 0, y: r))
        path.addArc(
            center: center,
            radius: r,
            startAngle: .radians(.pi),   // 9 o'clock (left)
            endAngle: .radians(0),       // 3 o'clock (right)
            clockwise: true              // clockwise in screen coords = arc goes up and over
        )
        path.addLine(to: CGPoint(x: w / 2, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - Stairway Pin View

/// Three-state map pin: Unsaved (amber, 50% opacity), Saved (light green), Walked (green).
/// All states display the same 3-step stair silhouette icon.
struct StairwayPin: View {
    enum PinState {
        case unsaved, saved, walked
    }

    let state: PinState
    var isSelected: Bool = false
    var isDimmed: Bool = false
    var isClosed: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            TeardropShape()
                .fill(fillColor)
                .frame(width: pinWidth, height: pinHeight)
                .shadow(
                    color: .black.opacity(isSelected ? 0.35 : 0.2),
                    radius: isSelected ? 4 : 2,
                    y: 1
                )

            // Stair icon centered in the bulb area (top pinWidth × pinWidth square)
            Image(systemName: "stairs")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: pinWidth, height: pinWidth)
        }
        .opacity(opacity)
        .animation(.spring(response: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.25), value: isDimmed)
    }

    private var pinWidth: CGFloat {
        if isSelected { return 34 }
        return state == .unsaved ? 24 : 28
    }

    private var pinHeight: CGFloat {
        if isSelected { return 42 }
        return state == .unsaved ? 30 : 35
    }

    private var iconSize: CGFloat { pinWidth * 0.38 }

    private var fillColor: Color {
        if isClosed { return Color.unwalkedSlate }
        switch state {
        case .unsaved:
            let base = isSelected ? Color.brandAmberDark : Color.brandAmber
            return base.opacity(0.5)
        case .saved:
            return isSelected ? Color.pinSavedDark : Color.pinSaved
        case .walked:
            return isSelected ? Color.walkedGreenDark : Color.walkedGreen
        }
    }

    private var opacity: Double {
        if isDimmed { return 0.3 }
        if isClosed { return 0.4 }
        return 1.0
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 20) {
        VStack(spacing: 16) {
            StairwayPin(state: .unsaved)
            StairwayPin(state: .saved)
            StairwayPin(state: .walked)
        }
        VStack(spacing: 16) {
            StairwayPin(state: .unsaved, isSelected: true)
            StairwayPin(state: .saved, isSelected: true)
            StairwayPin(state: .walked, isSelected: true)
        }
        VStack(spacing: 16) {
            StairwayPin(state: .unsaved, isDimmed: true)
            StairwayPin(state: .saved, isDimmed: true)
            StairwayPin(state: .walked, isDimmed: true)
        }
    }
    .padding(40)
    .background(Color.gray)
}
