import SwiftUI

private struct Particle {
    let xFraction: CGFloat
    let horizontalDrift: CGFloat
    let fallSpeed: CGFloat
    let color: Color
    let rotationRate: Double
    let delay: Double
    let width: CGFloat
    let height: CGFloat
}

struct ConfettiView: View {
    private static let palette: [Color] = [
        Color(red: 80/255, green: 200/255, blue: 120/255),  // forest green
        Color(red: 0.91, green: 0.72, blue: 0.22),           // gold
        Color(red: 0.95, green: 0.45, blue: 0.38),           // coral
        Color(red: 0.40, green: 0.74, blue: 0.93),           // sky blue
        Color(red: 0.74, green: 0.55, blue: 0.95),           // lavender
    ]

    private let particles: [Particle]
    @State private var startTime = Date()

    init() {
        var gen = SystemRandomNumberGenerator()
        var built: [Particle] = []
        let palette = ConfettiView.palette
        for _ in 0..<60 {
            let xFraction = CGFloat.random(in: 0...1, using: &gen)
            let drift = CGFloat.random(in: -0.12...0.12, using: &gen)
            let speed = CGFloat.random(in: 240...480, using: &gen)
            let colorIndex = Int.random(in: 0..<palette.count, using: &gen)
            let rotRate = Double.random(in: -3.5...3.5, using: &gen)
            let delay = Double.random(in: 0...0.4, using: &gen)
            let w = CGFloat.random(in: 6...11, using: &gen)
            let h = w * CGFloat.random(in: 1.5...2.5, using: &gen)
            built.append(Particle(
                xFraction: xFraction,
                horizontalDrift: drift,
                fallSpeed: speed,
                color: palette[colorIndex],
                rotationRate: rotRate,
                delay: delay,
                width: w,
                height: h
            ))
        }
        self.particles = built
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSince(startTime)
                    for p in particles {
                        let t = max(0, elapsed - p.delay)
                        guard t > 0 else { continue }

                        let y = p.fallSpeed * CGFloat(t)
                        let x = p.xFraction * size.width + p.horizontalDrift * size.width * CGFloat(t)
                        let progress = y / size.height
                        let alpha = max(0.0, 1.0 - progress * 1.3)
                        guard alpha > 0 else { continue }

                        let particlePath = Path(roundedRect: CGRect(
                            x: -p.width / 2, y: -p.height / 2,
                            width: p.width, height: p.height
                        ), cornerRadius: 2)

                        context.drawLayer { ctx in
                            ctx.translateBy(x: x, y: y)
                            ctx.rotate(by: Angle(radians: p.rotationRate * t))
                            ctx.opacity = alpha
                            ctx.fill(particlePath, with: .color(p.color))
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
