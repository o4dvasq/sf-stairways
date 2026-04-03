import SwiftUI
import SwiftData

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

    /// All tags deduped by id, presets first then custom, both sorted alphabetically.
    private var sortedTags: [StairwayTag] {
        var seen = Set<String>()
        let deduped = allTags.filter { seen.insert($0.id).inserted }
        let presets = deduped.filter { $0.isPreset }.sorted { $0.name.lowercased() < $1.name.lowercased() }
        let custom  = deduped.filter { !$0.isPreset }.sorted { $0.name.lowercased() < $1.name.lowercased() }
        return presets + custom
    }

    private var filteredTags: [StairwayTag] {
        guard !searchText.isEmpty else { return sortedTags }
        return sortedTags.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// True when the search text doesn't match any existing tag name exactly (case-insensitive).
    private var canCreateTag: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 30 else { return false }
        return !allTags.contains { $0.name.lowercased() == trimmed.lowercased() }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        tagGrid
                        if canCreateTag {
                            createPill
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search or create tag…", text: $searchText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Tag Grid

    @ViewBuilder
    private var tagGrid: some View {
        if filteredTags.isEmpty && !canCreateTag {
            Text("No tags found.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            FlowLayout(spacing: 8) {
                ForEach(filteredTags) { tag in
                    tagPill(tag)
                }
            }
        }
    }

    private func tagPill(_ tag: StairwayTag) -> some View {
        let assigned = assignedTagIDs.contains(tag.id)
        let tagColor = Color.tagPalette[tag.colorIndex % Color.tagPalette.count]
        return Button {
            toggleAssignment(tag: tag)
        } label: {
            HStack(spacing: 4) {
                if assigned {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(tag.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(.white)
            .background(assigned ? tagColor : tagColor.opacity(0.35))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create Pill

    private var createPill: some View {
        let name = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return Button {
            createAndAssign(name: name)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("Create \"\(name)\"")
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(Color.brandAmber)
            .background(Color.brandAmber.opacity(0.1))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.brandAmber, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func toggleAssignment(tag: StairwayTag) {
        if assignedTagIDs.contains(tag.id) {
            // Remove assignment
            let toDelete = allAssignments.filter { $0.stairwayID == stairwayID && $0.tagID == tag.id }
            toDelete.forEach { modelContext.delete($0) }
        } else {
            let assignment = TagAssignment(stairwayID: stairwayID, tagID: tag.id)
            modelContext.insert(assignment)
        }
        try? modelContext.save()
    }

    private func createAndAssign(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let id = makeTagID(from: trimmed)
        // Guard against a duplicate id (slug collision)
        guard !allTags.contains(where: { $0.id == id }) else { return }

        let tag = StairwayTag(id: id, name: trimmed, isPreset: false)
        tag.colorIndex = Int.random(in: 0..<12)
        modelContext.insert(tag)
        let assignment = TagAssignment(stairwayID: stairwayID, tagID: id)
        modelContext.insert(assignment)
        try? modelContext.save()

        searchText = ""
    }

    private func makeTagID(from name: String) -> String {
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return String(slug.prefix(30))
    }
}
