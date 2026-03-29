import SwiftUI
import SwiftData

struct RemovedStairwaysView: View {
    let store: StairwayStore

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \StairwayDeletion.deletedAt, order: .reverse) private var deletions: [StairwayDeletion]

    var body: some View {
        NavigationStack {
            Group {
                if deletions.isEmpty {
                    ContentUnavailableView(
                        "No Removed Stairways",
                        systemImage: "checkmark.circle",
                        description: Text("Stairways removed from the catalog will appear here.")
                    )
                } else {
                    List {
                        ForEach(deletions) { deletion in
                            removedRow(deletion)
                        }
                        .onDelete { indexSet in
                            let toRestore = indexSet.map { deletions[$0] }
                            toRestore.forEach { restore($0) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Removed Stairways")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func removedRow(_ deletion: StairwayDeletion) -> some View {
        let name = store.stairway(for: deletion.stairwayID)?.name ?? deletion.stairwayID
        let neighborhood = store.stairway(for: deletion.stairwayID)?.neighborhood

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                if let hood = neighborhood {
                    Text(hood)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let reason = deletion.reason, !reason.isEmpty {
                    Text("Reason: \(reason)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                Text(deletion.deletedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                restore(deletion)
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward.circle")
                    .font(.callout)
                    .foregroundStyle(Color.walkedGreen)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func restore(_ deletion: StairwayDeletion) {
        modelContext.delete(deletion)
        try? modelContext.save()
    }
}
