import SwiftUI

struct StairwayBottomSheet: View {
    let stairway: Stairway
    let walkRecord: WalkRecord?
    let onToggleWalk: () -> Void

    @State private var showDetail = false

    private var isWalked: Bool {
        walkRecord?.walked ?? false
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
                            if let steps = walkRecord?.stepCount {
                                Text("\(steps) steps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let height = stairway.heightFt {
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

                    Button(action: onToggleWalk) {
                        ZStack {
                            Circle()
                                .fill(isWalked ? Color.walkedGreen : Color(.systemGray5))
                                .frame(width: 48, height: 48)
                            Image(systemName: isWalked ? "checkmark" : "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(isWalked ? .white : .secondary)
                        }
                    }
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
                if isWalked, let date = walkRecord?.dateWalked {
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

                // View details button
                NavigationLink(destination: StairwayDetail(stairway: stairway)) {
                    Text("View details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.forestGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(20)
        }
    }
}
