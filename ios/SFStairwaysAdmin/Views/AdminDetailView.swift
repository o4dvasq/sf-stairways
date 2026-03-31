import SwiftUI
import SwiftData

struct AdminDetailView: View {
    let stairway: Stairway

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var walkRecords: [WalkRecord]
    @Query private var allOverrides: [StairwayOverride]
    @Query private var allTags: [StairwayTag]
    @Query private var allAssignments: [TagAssignment]

    @State private var heightText = ""
    @State private var descriptionText = ""
    @State private var showRemoveConfirmation = false
    @State private var removalReason = ""
    @State private var showTagPicker = false

    // MARK: - Derived data

    private var walkRecord: WalkRecord? {
        walkRecords.first { $0.stairwayID == stairway.id && $0.walked }
    }

    private var existingOverride: StairwayOverride? {
        allOverrides.first { $0.stairwayID == stairway.id }
    }

    private var currentTags: [StairwayTag] {
        let assignedTagIDs = Set(allAssignments.filter { $0.stairwayID == stairway.id }.map(\.tagID))
        var seen = Set<String>()
        return allTags
            .filter { assignedTagIDs.contains($0.id) && seen.insert($0.id).inserted }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var availableTags: [StairwayTag] {
        let assignedTagIDs = Set(allAssignments.filter { $0.stairwayID == stairway.id }.map(\.tagID))
        var seen = Set<String>()
        return allTags
            .filter { !assignedTagIDs.contains($0.id) && seen.insert($0.id).inserted }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // MARK: - Body

    var body: some View {
        Form {
            catalogSection
            overridesSection
            tagsSection
            actionsSection
        }
        .navigationTitle(stairway.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadOverrideFields()
        }
        .confirmationDialog(
            "Remove \(stairway.name)?",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                removeStairway()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This hides it from all devices. You can restore it from Removed Stairways.")
        }
        .sheet(isPresented: $showTagPicker) {
            TagPickerSheet(stairwayID: stairway.id, availableTags: availableTags)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Catalog Section

    private var catalogSection: some View {
        Section("Catalog Data") {
            LabeledContent("Name", value: stairway.name)
            LabeledContent("Neighborhood", value: stairway.neighborhood)
            if let height = stairway.heightFt {
                LabeledContent("Height", value: "\(Int(height)) ft")
            } else {
                LabeledContent("Height") {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            if let lat = stairway.lat, let lng = stairway.lng {
                LabeledContent("Coordinates", value: String(format: "%.5f, %.5f", lat, lng))
            } else {
                LabeledContent("Coordinates") {
                    Text("Missing").foregroundStyle(.red)
                }
            }
            if stairway.closed {
                LabeledContent("Status") {
                    Label("Closed", systemImage: "lock.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
            if let url = stairway.sourceURL, !url.isEmpty {
                LabeledContent("Source") {
                    if let dest = URL(string: url) {
                        Link(url, destination: dest)
                            .font(.callout)
                            .lineLimit(1)
                    } else {
                        Text(url)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Overrides Section

    private var overridesSection: some View {
        Section {
            LabeledContent("Height (ft)") {
                TextField("e.g. 85.5", text: $heightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            TextField("Curator description…", text: $descriptionText, axis: .vertical)
                .lineLimit(3...8)

            if let override = existingOverride {
                LabeledContent("Last updated") {
                    Text(override.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button("Save Override") { saveOverride() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.forestGreen)
                Button("Reset") { loadOverrideFields() }
                    .buttonStyle(.bordered)
            }
        } header: {
            Text("Overrides")
        } footer: {
            Text("Clearing all fields and saving removes the override record.")
                .font(.caption)
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        Section("Tags") {
            if currentTags.isEmpty {
                Text("No tags assigned")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(currentTags) { tag in
                            AdminTagChip(name: tag.name) {
                                removeTag(tag)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                showTagPicker = true
            } label: {
                Label("Add Tag", systemImage: "plus.circle")
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            Button(role: .destructive) {
                showRemoveConfirmation = true
            } label: {
                Label("Remove Stairway", systemImage: "trash")
            }
        }
    }

    // MARK: - Override Helpers

    private func loadOverrideFields() {
        let o = existingOverride
        heightText = o?.verifiedHeightFt.map { String($0) } ?? ""
        descriptionText = o?.stairwayDescription ?? ""
    }

    private func saveOverride() {
        let height = Double(heightText.trimmingCharacters(in: .whitespaces))
        let desc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmpty = height == nil && desc.isEmpty

        if isEmpty {
            if let existing = existingOverride {
                modelContext.delete(existing)
                try? modelContext.save()
            }
            return
        }

        let override: StairwayOverride
        if let existing = existingOverride {
            override = existing
        } else {
            override = StairwayOverride(stairwayID: stairway.id)
            modelContext.insert(override)
        }

        override.verifiedHeightFt = height
        override.stairwayDescription = desc.isEmpty ? nil : desc
        override.updatedAt = Date()
        try? modelContext.save()
    }

    private func removeTag(_ tag: StairwayTag) {
        let toRemove = allAssignments.filter { $0.stairwayID == stairway.id && $0.tagID == tag.id }
        toRemove.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }

    private func removeStairway() {
        let deletion = StairwayDeletion(stairwayID: stairway.id, reason: removalReason.isEmpty ? nil : removalReason)
        modelContext.insert(deletion)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Tag Chip

struct AdminTagChip: View {
    let name: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.callout)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.brandAmber.opacity(0.15))
        .foregroundStyle(Color.brandAmber)
        .clipShape(Capsule())
    }
}

// MARK: - Tag Picker Sheet

private struct TagPickerSheet: View {
    let stairwayID: String
    let availableTags: [StairwayTag]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTags: [StairwayTag]
    @State private var newTagName = ""

    private func isNameUnique(_ name: String) -> Bool {
        let lower = name.lowercased()
        return !allTags.contains { $0.name.lowercased() == lower }
    }

    private func makeTagID(from name: String) -> String {
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return String(slug.prefix(30))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("New tag name…", text: $newTagName)
                            .autocorrectionDisabled()
                        Button("Create") { createAndAssign() }
                            .disabled(
                                newTagName.trimmingCharacters(in: .whitespaces).isEmpty ||
                                !isNameUnique(newTagName)
                            )
                    }
                } header: {
                    Text("Create New Tag")
                }

                if !availableTags.isEmpty {
                    Section("Add Existing Tag") {
                        ForEach(availableTags) { tag in
                            Button {
                                assignTag(tag)
                            } label: {
                                HStack {
                                    Text(tag.name)
                                    Spacer()
                                    Image(systemName: "plus")
                                        .foregroundStyle(Color.brandAmber)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Add Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func assignTag(_ tag: StairwayTag) {
        let assignment = TagAssignment(stairwayID: stairwayID, tagID: tag.id)
        modelContext.insert(assignment)
        try? modelContext.save()
        dismiss()
    }

    private func createAndAssign() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, isNameUnique(name) else { return }
        let id = makeTagID(from: name)
        let tag = StairwayTag(id: id, name: name, isPreset: false)
        modelContext.insert(tag)
        let assignment = TagAssignment(stairwayID: stairwayID, tagID: id)
        modelContext.insert(assignment)
        try? modelContext.save()
        newTagName = ""
        dismiss()
    }
}
