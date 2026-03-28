import SwiftUI

/// Horizontal photo carousel showing all public Supabase photos for a stairway.
/// Includes per-photo like overlays and an "Add photo" button at the end.
struct PhotoCarousel: View {
    let photos: [SupabasePhoto]
    let likedPhotoIds: Set<UUID>
    let userId: UUID?
    let onLikeTap: (SupabasePhoto) -> Void
    let onAddTap: () -> Void

    @State private var selectedPhoto: SupabasePhoto? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Photos")
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !photos.isEmpty {
                    Text("(\(photos.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if photos.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(photos) { photo in
                            photoCell(photo)
                        }
                        addButton
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            FullScreenPhotoView(photo: photo)
        }
    }

    // MARK: - Photo Cell

    private func photoCell(_ photo: SupabasePhoto) -> some View {
        ZStack(alignment: .bottomLeading) {
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
            .frame(width: 120, height: 120)
            .onTapGesture {
                selectedPhoto = photo
            }

            // Like overlay (bottom-left)
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
            .padding(6)
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
    let photo: SupabasePhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

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
