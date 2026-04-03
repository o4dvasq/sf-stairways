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
                            FilterTagPill(name: tag.name, colorIndex: tag.colorIndex, isActive: activeTagID == tag.id) {
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

// MARK: - Flow Layout (wrapping HStack for tag pills)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Filter Tag Pill

private struct FilterTagPill: View {
    let name: String
    let colorIndex: Int
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        let tagColor = Color.tagPalette[colorIndex % Color.tagPalette.count]
        return Button(action: action) {
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(.white)
                .background(tagColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isActive ? Color.white.opacity(0.6) : Color.clear, lineWidth: 2)
                )
        }
    }
}
