import SwiftUI

struct StairwayBottomSheet: View {
    let stairway: Stairway
    let walkRecord: WalkRecord?
    var override: StairwayOverride? = nil
    let locationManager: LocationManager
    let onSave: () -> Void
    let onMarkWalked: () -> Void
    let onUnmarkWalk: () -> Void
    let onRemove: () -> Void

    @Environment(AuthManager.self) private var authManager

    private enum StairwayState {
        case unsaved, saved, walked
    }

    private var state: StairwayState {
        guard let record = walkRecord else { return .unsaved }
        return record.walked ? .walked : .saved
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stairway.name)
                            .font(.title3)
                            .fontWeight(.medium)
                        Text(stairway.neighborhood)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            if let verifiedStairs = override?.verifiedStepCount {
                                verifiedStatText("\(verifiedStairs) stairs")
                            } else if let steps = walkRecord?.stepCount {
                                Text("\(steps) steps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let verifiedHeight = override?.verifiedHeightFt {
                                verifiedStatText("\(Int(verifiedHeight)) ft")
                            } else if let height = stairway.heightFt {
                                Text("\(Int(height)) ft")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if stairway.closed {
                                Text("Closed")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.closedRed)
                            }
                        }
                        .padding(.top, 4)
                    }

                    Spacer()

                    stateIndicator
                }

                // Photo thumbnails
                let photos = walkRecord?.photoArray ?? []
                if !photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(photos) { photo in
                                if let thumb = photo.thumbnailImage {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }

                // Walk date
                if state == .walked, let date = walkRecord?.dateWalked {
                    Text("Walked \(date.formatted(date: .long, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Notes preview
                if let notes = walkRecord?.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Action buttons
                actionButtons

                // View details
                NavigationLink(destination: StairwayDetail(stairway: stairway, locationManager: locationManager)) {
                    Text("View details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(detailButtonColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(20)
        }
    }

    // MARK: - Verified Stat

    private func verifiedStatText(_ text: String) -> some View {
        HStack(spacing: 2) {
            Text(text)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 8))
                .foregroundStyle(Color.forestGreen)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Hard Mode

    private var isMarkWalkedDisabled: Bool {
        guard authManager.hardModeEnabled else { return false }
        return !locationManager.isWithinRadius(150, ofLatitude: stairway.lat ?? 0, longitude: stairway.lng ?? 0)
    }

    // MARK: - State Indicator

    @ViewBuilder
    private var stateIndicator: some View {
        switch state {
        case .unsaved:
            EmptyView()
        case .saved:
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.brandAmber.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.brandAmber)
                }
                Text("Saved")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandAmber)
            }
        case .walked:
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.walkedGreenDim)
                        .frame(width: 48, height: 48)
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("Walked")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.walkedGreen)
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch state {
        case .unsaved:
            HStack(spacing: 10) {
                ActionButton(title: "Save", icon: "bookmark", color: Color.brandAmber, action: onSave)
                ActionButton(title: "Mark Walked", icon: "checkmark.circle", color: Color.walkedGreen, action: onMarkWalked)
                    .opacity(isMarkWalkedDisabled ? 0.4 : 1.0)
                    .disabled(isMarkWalkedDisabled)
            }
        case .saved:
            HStack(spacing: 10) {
                ActionButton(title: "Unsave", icon: "bookmark.slash", color: .secondary, action: onRemove)
                ActionButton(title: "Mark Walked", icon: "checkmark.circle", color: Color.walkedGreen, action: onMarkWalked)
                    .opacity(isMarkWalkedDisabled ? 0.4 : 1.0)
                    .disabled(isMarkWalkedDisabled)
            }
        case .walked:
            HStack(spacing: 10) {
                ActionButton(title: "Unmark Walk", icon: "arrow.uturn.backward", color: Color.brandAmber, action: onUnmarkWalk)
                ActionButton(title: "Remove", icon: "trash", color: .secondary, action: onRemove)
            }
        }
    }

    private var detailButtonColor: Color {
        switch state {
        case .unsaved: return Color.forestGreen
        case .saved: return Color.brandAmber
        case .walked: return Color.walkedGreen
        }
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
