import SwiftUI
import SwiftData

/// Horizontal photo carousel showing local and remote photos for a stairway.
/// Remote photos include like overlays. Local-only photos show a cloud-slash badge
/// (gray = pending upload, red = upload failed).
struct PhotoCarousel: View {
    let photos: [PhotoSource]
    let likedPhotoIds: Set<UUID>
    let userId: UUID?
    let failedPhotoIDs: Set<PersistentIdentifier>
    let onLikeTap: (SupabasePhoto) -> Void
    let onAddTap: () -> Void

    @State private var selectedSource: PhotoSource? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if photos.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(photos) { source in
                            photoCell(source)
                        }
                        addButton
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .sheet(item: $selectedSource) { source in
            FullScreenPhotoView(source: source)
        }
    }

    // MARK: - Photo Cell

    private func photoCell(_ source: PhotoSource) -> some View {
        ZStack(alignment: .bottomLeading) {
            thumbnailView(for: source)
                .frame(width: 120, height: 120)
                .onTapGesture { selectedSource = source }

            switch source {
            case .remote(let photo):
                likeOverlay(for: photo)
                    .padding(6)
            case .local(let photo):
                // Only show the cloud badge when signed in AND this specific photo failed to upload.
                // When userId is nil (not signed in), the badge is meaningless — hide it.
                if userId != nil && failedPhotoIDs.contains(photo.persistentModelID) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .padding(5)
                        .background(.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnailView(for source: PhotoSource) -> some View {
        switch source {
        case .remote(let photo):
            AsyncImage(url: photo.thumbnailURL()) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .overlay(ProgressView().scaleEffect(0.7))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        )
                @unknown default:
                    EmptyView()
                }
            }
        case .local(let photo):
            Group {
                if let image = photo.thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        )
                }
            }
        }
    }

    private func likeOverlay(for photo: SupabasePhoto) -> some View {
        Button {
            if userId != nil {
                onLikeTap(photo)
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: likedPhotoIds.contains(photo.id) ? "heart.fill" : "heart")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(likedPhotoIds.contains(photo.id) ? Color.closedRed : .white)
                Text("\(photo.likeCount)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.5))
            .clipShape(Capsule())
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            onAddTap()
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundStyle(.tertiary)
                .frame(width: 120, height: 120)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.title3)
                        Text("Add")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Button {
            onAddTap()
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundStyle(.tertiary)
                .frame(height: 80)
                .overlay {
                    HStack(spacing: 8) {
                        Image(systemName: "camera")
                        Text("Add a photo")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                }
        }
    }
}

// MARK: - Full Screen Photo Viewer

private struct FullScreenPhotoView: View {
    let source: PhotoSource
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            switch source {
            case .remote(let photo):
                AsyncImage(url: photo.fullImageURL()) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    default:
                        ProgressView()
                            .tint(.white)
                    }
                }
            case .local(let photo):
                if let image = photo.fullImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(20)
            }
        }
    }
}
