import SwiftUI

#if canImport(UIKit)
import UIKit

// MARK: - Share Card View

/// SwiftUI view rendered via ImageRenderer to produce a 1080×1920 share card.
/// Render at scale 3.0 → 360×640pt logical size.
struct ShareCardView: View {
    let stairwayName: String
    let neighborhood: String
    let heightFt: Double?
    let photoImage: UIImage?

    private let cardWidth: CGFloat = 360
    private let cardHeight: CGFloat = 640
    private let photoFraction: CGFloat = 0.60

    var body: some View {
        ZStack {
            if let photo = photoImage {
                withPhotoLayout(photo: photo)
            } else {
                noPhotoLayout
            }
        }
        .frame(width: cardWidth, height: cardHeight)
    }

    // MARK: - With Photo Layout

    private func withPhotoLayout(photo: UIImage) -> some View {
        let photoHeight = cardHeight * photoFraction
        let textHeight = cardHeight * (1 - photoFraction)

        return VStack(spacing: 0) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: cardWidth, height: photoHeight)
                .clipped()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                Text(stairwayName)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255))
                    .lineLimit(2)

                Text(neighborhood)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0x6B/255, green: 0x6B/255, blue: 0x6B/255))
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    if let h = heightFt {
                        CardStatPill(text: "\(Int(h)) ft", onDark: false)
                    }
                    CardStatPill(text: "Walked ✓", onDark: false)
                }
                .padding(.top, 12)

                Spacer()

                Text("Climb every stairway\nin San Francisco")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0x6B/255, green: 0x6B/255, blue: 0x6B/255))
                    .lineSpacing(2)

                HStack {
                    Text("sfstairways.app")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0xD4/255, green: 0x72/255, blue: 0x4E/255))
                    Spacer()
                    Text("SF Stairways")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0xD4/255, green: 0x72/255, blue: 0x4E/255))
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(width: cardWidth, height: textHeight)
            .background(Color(red: 0xFA/255, green: 0xFA/255, blue: 0xF7/255))
        }
    }

    // MARK: - No Photo Layout

    private var noPhotoLayout: some View {
        ZStack {
            Color(red: 0xD4/255, green: 0x72/255, blue: 0x4E/255)

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                Text(stairwayName)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)

                Text(neighborhood)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.top, 6)

                HStack(spacing: 8) {
                    if let h = heightFt {
                        CardStatPill(text: "\(Int(h)) ft", onDark: true)
                    }
                    CardStatPill(text: "Walked ✓", onDark: true)
                }
                .padding(.top, 16)

                Spacer()

                Text("Climb every stairway\nin San Francisco")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineSpacing(2)

                HStack {
                    Text("sfstairways.app")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("SF Stairways")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
    }
}

// MARK: - Stat Pill

private struct CardStatPill: View {
    let text: String
    let onDark: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(onDark ? Color.white : Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(onDark ? Color.white.opacity(0.22) : Color(red: 0xE8/255, green: 0xE4/255, blue: 0xDF/255))
            .clipShape(Capsule())
    }
}

// MARK: - Activity Share Sheet

struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        // iPad popover anchor — prevents a crash when presented on larger screens
        controller.popoverPresentationController?.sourceView = UIView()
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#endif
