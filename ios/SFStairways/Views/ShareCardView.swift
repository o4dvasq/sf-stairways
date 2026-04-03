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
    let neighborhoodWalked: Int
    let neighborhoodTotal: Int

    private let cardWidth: CGFloat = 360
    private let cardHeight: CGFloat = 640
    private let frameWidth: CGFloat = 16
    private let photoSectionFraction: CGFloat = 0.58

    private var photoSectionHeight: CGFloat { cardHeight * photoSectionFraction }
    private var textSectionHeight: CGFloat { cardHeight * (1 - photoSectionFraction) }
    private var photoInsetWidth: CGFloat { cardWidth - frameWidth * 2 }
    private var photoInsetHeight: CGFloat { photoSectionHeight - frameWidth * 2 }

    var body: some View {
        VStack(spacing: 0) {
            if let photo = photoImage {
                withPhotoTopSection(photo: photo)
            } else {
                noPhotoTopSection
            }
            bottomPanel
        }
        .frame(width: cardWidth, height: cardHeight)
    }

    // MARK: - With Photo: Top Section

    private func withPhotoTopSection(photo: UIImage) -> some View {
        ZStack {
            Color.brandAmber
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: photoInsetWidth, height: photoInsetHeight)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    logoOverlay.padding(12)
                }
                .overlay(alignment: .bottomTrailing) {
                    progressPill(compact: true).padding(12)
                }
        }
        .frame(width: cardWidth, height: photoSectionHeight)
    }

    // MARK: - No Photo: Top Section

    private var noPhotoTopSection: some View {
        ZStack {
            Color.brandAmber
            ZStack {
                // Fixed brandOrange — no light/dark adaptive, card is a static image
                Color(red: 0xD4/255, green: 0x72/255, blue: 0x4E/255)
                VStack(alignment: .leading, spacing: 0) {
                    logoOverlay
                        .padding(.top, 14)
                        .padding(.leading, 14)
                    Spacer()
                    VStack(alignment: .leading, spacing: 5) {
                        Text(stairwayName)
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                        Text(neighborhood)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 18)
                    Spacer()
                    progressPill(compact: false)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 16)
                }
                .frame(width: photoInsetWidth, height: photoInsetHeight, alignment: .topLeading)
            }
            .frame(width: photoInsetWidth, height: photoInsetHeight)
        }
        .frame(width: cardWidth, height: photoSectionHeight)
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if photoImage != nil {
                Spacer()
                Text(stairwayName)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255))
                    .lineLimit(2)
                Text(neighborhood)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0x6B/255, green: 0x6B/255, blue: 0x6B/255))
                    .padding(.top, 3)
                statPills.padding(.top, 10)
                Spacer()
            } else {
                Spacer()
                statPills
                Spacer()
            }
            Text("Climb every stairway in San Francisco")
                .font(.system(size: 11))
                .foregroundStyle(Color(red: 0x6B/255, green: 0x6B/255, blue: 0x6B/255))
            Text("sfstairways.app")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 0xD4/255, green: 0x72/255, blue: 0x4E/255))
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(width: cardWidth, height: textSectionHeight, alignment: .leading)
        .background(Color(red: 0xFA/255, green: 0xFA/255, blue: 0xF7/255))
    }

    private var statPills: some View {
        HStack(spacing: 8) {
            if let h = heightFt {
                CardStatPill(text: "\(Int(h)) ft")
            }
            CardStatPill(text: "Walked ✓")
        }
    }

    // MARK: - Logo Overlay

    private var logoOverlay: some View {
        HStack(spacing: 5) {
            StairShape()
                .fill(Color.white)
                .frame(width: 15, height: 15)
            Text("SF Stairways")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.42))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 4)
    }

    // MARK: - Progress Pill

    @ViewBuilder
    private func progressPill(compact: Bool) -> some View {
        if compact {
            Text("\(neighborhoodWalked) of \(neighborhoodTotal)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.42))
                .clipShape(Capsule())
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(neighborhoodWalked) of \(neighborhoodTotal) in")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(neighborhood)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Stat Pill

private struct CardStatPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(red: 0xE8/255, green: 0xE4/255, blue: 0xDF/255))
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
