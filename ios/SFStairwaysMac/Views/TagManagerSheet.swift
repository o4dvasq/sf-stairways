import SwiftUI
import SwiftData

struct TagManagerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTags: [StairwayTag]
    @Query private var allAssignments: [TagAssignment]

    @State private var newTagName = ""
    @State private var editingTagID: String? = nil
    @State private var editingTagName = ""
    @State private var tagToDelete: StairwayTag? = nil

    private var presetTags: [StairwayTag] {
        var seen = Set<String>()
        return allTags
            .filter { $0.isPreset && seen.insert($0.id).inserted }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var customTags: [StairwayTag] {
        var seen = Set<String>()
        return allTags
            .filter { !$0.isPreset && seen.insert($0.id).inserted }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private func assignmentCount(for tagID: String) -> Int {
        Set(allAssignments.filter { $0.tagID == tagID }.map(\.stairwayID)).count
    }

    private func makeTagID(from name: String) -> String {
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return String(slug.prefix(30))
    }

    private func isNameUnique(_ name: String, excludingID: String? = nil) -> Bool {
        let lower = name.lowercased()
        return !allTags.contains { $0.name.lowercased() == lower && $0.id != excludingID }
    }

    private var deleteConfirmTitle: String {
        guard let tag = tagToDelete else { return "Delete tag?" }
        let count = assignmentCount(for: tag.id)
        if count == 0 {
            return "Delete tag '\(tag.name)'?"
        }
        return "Delete '\(tag.name)'? It is assigned to \(count) stairway\(count == 1 ? "" : "s")."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !presetTags.isEmpty {
                        presetTagsSection
                    }
                    customTagsSection
                }
                .padding()
            }
        }
        .frame(minWidth: 440, minHeight: 420)
        .confirmationDialog(
            deleteConfirmTitle,
            isPresented: Binding(
                get: { tagToDelete != nil },
                set: { if !$0 { tagToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let tag = tagToDelete { deleteTag(tag) }
                tagToDelete = nil
            }
            Button("Cancel", role: .cancel) { tagToDelete = nil }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "tag.fill")
                .font(.title2)
                .foregroundStyle(Color.brandAmber)
            VStack(alignment: .leading) {
                Text("Tag Manager")
                    .font(.title2.bold())
                Text("\(Set(allTags.map(\.id)).count) tags total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
        }
        .padding()
    }

    // MARK: - Preset Tags Section

    private var presetTagsSection: some View {
        GroupBox("Preset Tags") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(presetTags) { tag in
                    HStack {
                        Text(tag.name)
                            .font(.system(size: 13))
                        Spacer()
                        countPill(assignmentCount(for: tag.id))
                    }
                }
            }
            .padding(8)
        }
    }

    // MARK: - Custom Tags Section

    private var customTagsSection: some View {
        GroupBox("Custom Tags") {
            VStack(alignment: .leading, spacing: 8) {
                if customTags.isEmpty {
                    Text("No custom tags yet.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(customTags) { tag in
                        customTagRow(tag)
                    }
                }

                Divider()
                newTagRow
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func customTagRow(_ tag: StairwayTag) -> some View {
        HStack(spacing: 8) {
            if editingTagID == tag.id {
                TextField("Tag name", text: $editingTagName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveRename(tag: tag) }
            } else {
                Text(tag.name)
                    .font(.system(size: 13))
            }
            Spacer()
            countPill(assignmentCount(for: tag.id))
            if editingTagID == tag.id {
                Button("Save") { saveRename(tag: tag) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(
                        editingTagName.trimmingCharacters(in: .whitespaces).isEmpty ||
                        !isNameUnique(editingTagName, excludingID: tag.id)
                    )
                Button("Cancel") {
                    editingTagID = nil
                    editingTagName = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button {
                    editingTagID = tag.id
                    editingTagName = tag.name
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Button {
                    tagToDelete = tag
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
    }

    private var newTagRow: some View {
        HStack(spacing: 8) {
            TextField("New tag name…", text: $newTagName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { createTag() }
            Button("Add") { createTag() }
                .buttonStyle(.borderedProminent)
                .disabled(
                    newTagName.trimmingCharacters(in: .whitespaces).isEmpty ||
                    !isNameUnique(newTagName)
                )
        }
    }

    private func countPill(_ count: Int) -> some View {
        Text("\(count) stairway\(count == 1 ? "" : "s")")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.1), in: Capsule())
    }

    // MARK: - Actions

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, isNameUnique(name) else { return }
        let id = makeTagID(from: name)
        let tag = StairwayTag(id: id, name: name, isPreset: false)
        modelContext.insert(tag)
        try? modelContext.save()
        newTagName = ""
    }

    private func saveRename(tag: StairwayTag) {
        let name = editingTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, isNameUnique(name, excludingID: tag.id) else { return }
        tag.name = name
        try? modelContext.save()
        editingTagID = nil
        editingTagName = ""
    }

    private func deleteTag(_ tag: StairwayTag) {
        let assignments = allAssignments.filter { $0.tagID == tag.id }
        assignments.forEach { modelContext.delete($0) }
        modelContext.delete(tag)
        try? modelContext.save()
    }
}
