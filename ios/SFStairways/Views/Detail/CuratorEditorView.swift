import SwiftUI

/// Curator-only editor for writing and publishing stairway commentary.
/// Visible only when the user has is_curator = true AND curator mode is active.
struct CuratorEditorView: View {
    let stairwayId: String
    let curatorId: UUID
    let notesText: String
    let service: CuratorService
    @Binding var triggerPromote: Bool

    @State private var draftText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String? = nil

    private var isPublished: Bool { service.commentary?.isPublished ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack {
                Text("Curator Commentary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.leading, 4)
                }
                Spacer()
                if isPublished {
                    Label("Published", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.walkedGreen)
                } else {
                    Text("Draft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $draftText)
                    .font(.subheadline)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                if draftText.isEmpty {
                    Text("Write commentary for this stairway…")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.closedRed)
            }

            HStack(spacing: 10) {
                // Promote Notes — only when notes are non-empty
                if !notesText.isEmpty {
                    Button {
                        draftText = notesText
                    } label: {
                        Label("Promote Notes", systemImage: "arrow.up.doc")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }

                Spacer()

                Button("Save Draft") {
                    save(publish: false)
                }
                .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .buttonStyle(.bordered)
                .tint(Color.forestGreen)

                Button(isPublished ? "Unpublish" : "Publish") {
                    save(publish: !isPublished)
                }
                .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .buttonStyle(.borderedProminent)
                .tint(isPublished ? .secondary : Color.forestGreen)
            }
        }
        .onAppear {
            draftText = service.commentary?.commentary ?? ""
        }
        .onChange(of: service.commentary?.commentary) { _, newValue in
            // Only sync from service if user hasn't typed (i.e., draftText still matches)
            if draftText == (service.commentary?.commentary ?? "") {
                draftText = newValue ?? ""
            }
        }
        .onChange(of: triggerPromote) { _, shouldPromote in
            if shouldPromote {
                draftText = notesText
                triggerPromote = false
            }
        }
    }

    private func save(publish: Bool) {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await service.upsert(stairwayId: stairwayId, curatorId: curatorId, text: text, isPublished: publish)
            } catch {
                errorMessage = "Couldn't save. Try again."
            }
            isSaving = false
        }
    }
}
