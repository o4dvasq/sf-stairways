import SwiftUI

struct PhotoViewer: View {
    let photo: WalkPhoto
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = photo.fullImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    VStack(spacing: 4) {
                        if let caption = photo.caption {
                            Text(caption)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        Text(photo.takenAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Delete this photo?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
