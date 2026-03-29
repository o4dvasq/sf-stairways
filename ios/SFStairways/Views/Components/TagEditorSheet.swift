import SwiftUI
import SwiftData

// MARK: - TagEditorSheet

struct TagEditorSheet: View {
    let stairwayID: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTags: [StairwayTag]
    @Query private var allAssignments: [TagAssignment]

    @State private var searchText = ""

    private var assignedTagIDs: Set<String> {
        Set(allAssignments.filter { $0.stairwayID == stairwayID }.map(\.tagID))
    }

    private var filteredTags: [StairwayTag] {
        // Deduplicate by id (CloudKit + seed can create duplicates)
        var seen = Set<String>()
        let unique = allTags.filter { seen.insert($0.id).inserted }
        let sorted = unique.sorted { $0.name.lowercased() < $1.name.lowercased() }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var canCreateCustomTag: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 30 else { return false }
        return !allTags.contains(where: { $0.name.lowercased() == trimmed.lowercased() })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search or create tag...", text: $searchText)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if canCreateCustomTag {
                            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                            Button {
                                createAndAssignTag(name: trimmed)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 13))
                                    Text("Create \"\(trimmed)\"")
                                        .font(.subheadline)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.forestGreen.opacity(0.12))
                                .foregroundStyle(Color.forestGreen)
                                .clipShape(Capsule())
                            }
                            .padding(.horizontal)
                        }

                        if !filteredTags.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(filteredTags) { tag in
                                    TagPill(
                                        name: tag.name,
                                        isSelected: assignedTagIDs.contains(tag.id)
                                    ) {
                                        toggleTag(tag)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else if !canCreateCustomTag {
                            Text("No tags found")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toggleTag(_ tag: StairwayTag) {
        if let existing = allAssignments.first(where: {
            $0.stairwayID == stairwayID && $0.tagID == tag.id
        }) {
            modelContext.delete(existing)
        } else {
            let assignment = TagAssignment(stairwayID: stairwayID, tagID: tag.id)
            modelContext.insert(assignment)
        }
        try? modelContext.save()
    }

    private func createAndAssignTag(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = trimmed.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }

        let tag = StairwayTag(id: id, name: trimmed, isPreset: false)
        modelContext.insert(tag)
        let assignment = TagAssignment(stairwayID: stairwayID, tagID: id)
        modelContext.insert(assignment)
        try? modelContext.save()
        searchText = ""
    }
}

// MARK: - TagPill

struct TagPill: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(name)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.forestGreen : Color(.systemBackground))
            .foregroundStyle(isSelected ? .white : Color.forestGreen)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.forestGreen, lineWidth: 1))
        }
    }
}

// MARK: - FlowLayout

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
