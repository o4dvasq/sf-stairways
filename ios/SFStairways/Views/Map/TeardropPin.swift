import SwiftUI

// MARK: - Stair Shape

/// 3-step ascending stair silhouette — matches the app icon.
/// Steps ascend from bottom-left to top-right.
struct StairShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let stepW = w / 3.0
        let stepH = h / 3.0

        // Start at bottom-left
        path.move(to: CGPoint(x: 0, y: h))

        // Step 1: up one, right one
        path.addLine(to: CGPoint(x: 0, y: h - stepH))
        path.addLine(to: CGPoint(x: stepW, y: h - stepH))

        // Step 2: up one, right one
        path.addLine(to: CGPoint(x: stepW, y: h - 2 * stepH))
        path.addLine(to: CGPoint(x: 2 * stepW, y: h - 2 * stepH))

        // Step 3: up one, right one
        path.addLine(to: CGPoint(x: 2 * stepW, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))

        // Close: down the right side, across bottom
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()

        return path
    }
}

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

/// Three-state map pin: colored circles (gray/orange/green) per walk state.
struct StairwayPin: View {
    enum PinState {
        case unsaved, walked
    }

    let state: PinState
    var isSelected: Bool = false
    var isDimmed: Bool = false
    var isClosed: Bool = false
    var scale: CGFloat = 1.0

    var body: some View {
        let size = pinSize
        let tapTarget = max(44, size)
        Circle()
            .fill(fillColor)
            .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            .opacity(opacity)
            .animation(.spring(response: 0.2), value: isSelected)
            .animation(.easeInOut(duration: 0.25), value: isDimmed)
            .frame(width: tapTarget, height: tapTarget)
            .contentShape(Rectangle())
    }

    private var pinSize: CGFloat {
        let base: CGFloat
        if isSelected { base = 28 }
        else {
            switch state {
            case .unsaved: base = 18
            case .walked: base = 22
            }
        }
        return base * scale
    }

    private var fillColor: Color {
        if isClosed { return Color.unwalkedSlate }
        if isSelected {
            switch state {
            case .unsaved: return Color.brandAmberDark
            case .walked: return Color.walkedGreenDark
            }
        }
        switch state {
        case .unsaved: return Color.brandAmber
        case .walked: return Color.walkedGreen
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
            StairwayPin(state: .walked)
        }
        VStack(spacing: 16) {
            StairwayPin(state: .unsaved, isSelected: true)
            StairwayPin(state: .walked, isSelected: true)
        }
        VStack(spacing: 16) {
            StairwayPin(state: .unsaved, isDimmed: true)
            StairwayPin(state: .walked, isDimmed: true)
        }
    }
    .padding(40)
    .background(Color.gray)
}
