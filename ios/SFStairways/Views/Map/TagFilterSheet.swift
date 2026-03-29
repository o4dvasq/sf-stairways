import SwiftUI
import SwiftData

struct TagFilterSheet: View {
    @Binding var activeTagID: String?

    @Environment(\.dismiss) private var dismiss
    @Query private var allTags: [StairwayTag]
    @Query private var allAssignments: [TagAssignment]

    private var tagsWithAssignments: [StairwayTag] {
        let assignedTagIDs = Set(allAssignments.map(\.tagID))
        // Deduplicate by id (CloudKit + seed can create duplicates)
        var seen = Set<String>()
        return allTags
            .filter { assignedTagIDs.contains($0.id) && seen.insert($0.id).inserted }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if tagsWithAssignments.isEmpty {
                    ContentUnavailableView(
                        "No tags yet",
                        systemImage: "tag",
                        description: Text("Tag stairways from their detail view")
                    )
                    .padding(.top, 40)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(tagsWithAssignments) { tag in
                            FilterTagPill(name: tag.name, isActive: activeTagID == tag.id) {
                                if activeTagID == tag.id {
                                    activeTagID = nil
                                } else {
                                    activeTagID = tag.id
                                    dismiss()
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Filter by Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if activeTagID != nil {
                        Button("Clear") {
                            activeTagID = nil
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Filter Tag Pill

private struct FilterTagPill: View {
    let name: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isActive ? Color.brandAmber : Color(.systemBackground))
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isActive ? Color.clear : Color(.separator), lineWidth: 0.5)
                )
        }
    }
}
