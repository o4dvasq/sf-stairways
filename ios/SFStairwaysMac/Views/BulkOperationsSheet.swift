import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct BulkOperationsSheet: View {
    let selectedStairways: [Stairway]
    let allRows: [StairwayRow]
    let tags: [StairwayTag]
    let tagAssignments: [TagAssignment]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTagID: String? = nil
    @State private var selectedRemoveTagID: String? = nil
    @State private var showCreateTagField = false
    @State private var inlineNewTagName = ""
    @State private var markWalkedDate: Date = Date()
    @State private var showDatePicker = false
    @State private var operationResult: String? = nil
    @State private var showExportPanel = false

    private var assignedTagIDsByStairway: [String: Set<String>] {
        var dict: [String: Set<String>] = [:]
        let ids = Set(selectedStairways.map(\.id))
        for assignment in tagAssignments where ids.contains(assignment.stairwayID) {
            dict[assignment.stairwayID, default: []].insert(assignment.tagID)
        }
        return dict
    }

    private var tagsOnSelectedStairways: [StairwayTag] {
        let stairwayIDs = Set(selectedStairways.map(\.id))
        let assignedTagIDs = Set(
            tagAssignments
                .filter { stairwayIDs.contains($0.stairwayID) }
                .map(\.tagID)
        )
        var seen = Set<String>()
        return tags
            .filter { assignedTagIDs.contains($0.id) && seen.insert($0.id).inserted }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .font(.title2)
                    .foregroundStyle(Color.brandAmber)
                VStack(alignment: .leading) {
                    Text("Bulk Actions")
                        .font(.title2.bold())
                    Text("\(selectedStairways.count) stairways selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    selectedPreview
                    assignTagSection
                    if !tagsOnSelectedStairways.isEmpty {
                        removeTagSection
                    }
                    markWalkedSection
                    exportSection

                    if let result = operationResult {
                        Text(result)
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 500)
    }

    // MARK: - Selected Preview

    private var selectedPreview: some View {
        GroupBox("Selected Stairways") {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(selectedStairways) { stairway in
                        HStack {
                            Text(stairway.name)
                                .font(.system(size: 12))
                            Spacer()
                            Text(stairway.neighborhood)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 140)
        }
    }

    // MARK: - Assign Tag

    private var assignTagSection: some View {
        GroupBox("Assign Tag to All Selected") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Tag", selection: $selectedTagID) {
                    Text("Choose a tag…").tag(nil as String?)
                    ForEach(tags) { tag in
                        Text(tag.name).tag(tag.id as String?)
                    }
                }
                .frame(width: 280)

                if showCreateTagField {
                    HStack(spacing: 8) {
                        TextField("New tag name…", text: $inlineNewTagName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                            .onSubmit { createAndBulkAssign() }
                        Button("Add & Assign") { createAndBulkAssign() }
                            .buttonStyle(.borderedProminent)
                            .disabled(inlineNewTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button("Cancel") {
                            showCreateTagField = false
                            inlineNewTagName = ""
                        }
                        .buttonStyle(.bordered)
                    }
                }

                HStack {
                    Button("Assign Tag") {
                        bulkAssignTag()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedTagID == nil || showCreateTagField)

                    Button("Create new tag…") {
                        showCreateTagField.toggle()
                        if !showCreateTagField { inlineNewTagName = "" }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(8)
        }
    }

    // MARK: - Remove Tag

    private var removeTagSection: some View {
        GroupBox("Remove Tag from All Selected") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Tag to remove", selection: $selectedRemoveTagID) {
                    Text("Choose a tag…").tag(nil as String?)
                    ForEach(tagsOnSelectedStairways) { tag in
                        Text(tag.name).tag(tag.id as String?)
                    }
                }
                .frame(width: 280)

                Button("Remove Tag from All Selected") {
                    bulkRemoveTag()
                }
                .buttonStyle(.bordered)
                .disabled(selectedRemoveTagID == nil)
            }
            .padding(8)
        }
    }

    // MARK: - Mark as Walked

    private var markWalkedSection: some View {
        GroupBox("Mark All as Walked") {
            VStack(alignment: .leading, spacing: 10) {
                DatePicker("Date", selection: $markWalkedDate, displayedComponents: .date)
                    .frame(width: 280)

                Button("Mark \(selectedStairways.count) as Walked") {
                    bulkMarkWalked()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(8)
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        GroupBox("Export") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Export selected stairways as CSV (name, neighborhood, height, walked, date walked).")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Button("Export CSV…") {
                    exportCSV()
                }
                .buttonStyle(.bordered)
            }
            .padding(8)
        }
    }

    // MARK: - Actions

    private func bulkAssignTag() {
        guard let tagID = selectedTagID else { return }
        var count = 0
        for stairway in selectedStairways {
            let alreadyAssigned = assignedTagIDsByStairway[stairway.id]?.contains(tagID) ?? false
            if !alreadyAssigned {
                let assignment = TagAssignment(stairwayID: stairway.id, tagID: tagID)
                modelContext.insert(assignment)
                count += 1
            }
        }
        try? modelContext.save()
        let tagName = tags.first { $0.id == tagID }?.name ?? tagID
        operationResult = "Tag '\(tagName)' assigned to \(count) stairways."
    }

    private func bulkRemoveTag() {
        guard let tagID = selectedRemoveTagID else { return }
        let stairwayIDs = Set(selectedStairways.map(\.id))
        let toDelete = tagAssignments.filter {
            stairwayIDs.contains($0.stairwayID) && $0.tagID == tagID
        }
        toDelete.forEach { modelContext.delete($0) }
        try? modelContext.save()
        let tagName = tags.first { $0.id == tagID }?.name ?? tagID
        operationResult = "Tag '\(tagName)' removed from \(toDelete.count) stairways."
        selectedRemoveTagID = nil
    }

    private func createAndBulkAssign() {
        let name = inlineNewTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let tagID = String(slug.prefix(30))

        if !tags.contains(where: { $0.id == tagID }) {
            let tag = StairwayTag(id: tagID, name: name, isPreset: false)
            modelContext.insert(tag)
        }

        var count = 0
        for stairway in selectedStairways {
            let alreadyAssigned = tagAssignments.contains {
                $0.stairwayID == stairway.id && $0.tagID == tagID
            }
            if !alreadyAssigned {
                let assignment = TagAssignment(stairwayID: stairway.id, tagID: tagID)
                modelContext.insert(assignment)
                count += 1
            }
        }
        try? modelContext.save()
        operationResult = "Tag '\(name)' created and assigned to \(count) stairways."
        showCreateTagField = false
        inlineNewTagName = ""
    }

    private func bulkMarkWalked() {
        for stairway in selectedStairways {
            let existing = allRows.first { $0.stairway.id == stairway.id }?.walkRecord
            let record: WalkRecord
            if let r = existing {
                record = r
            } else {
                record = WalkRecord(stairwayID: stairway.id, walked: false)
                modelContext.insert(record)
            }
            if !record.walked {
                record.walked = true
                record.dateWalked = markWalkedDate
                record.updatedAt = Date()
            }
        }
        try? modelContext.save()
        let dateStr = markWalkedDate.formatted(date: .abbreviated, time: .omitted)
        operationResult = "\(selectedStairways.count) stairways marked as walked on \(dateStr)."
    }

    private func exportCSV() {
        var lines: [String] = ["Name,Neighborhood,Height (ft),Walked,Date Walked"]
        for stairway in selectedStairways {
            let row = allRows.first { $0.stairway.id == stairway.id }
            let height = row?.heightFt.map { String(Int($0)) } ?? ""
            let walked = (row?.walked ?? false) ? "Yes" : "No"
            let dateWalked = row?.dateWalked.map { $0.formatted(date: .numeric, time: .omitted) } ?? ""
            let name = stairway.name.replacingOccurrences(of: ",", with: ";")
            let neighborhood = stairway.neighborhood.replacingOccurrences(of: ",", with: ";")
            lines.append("\(name),\(neighborhood),\(height),\(walked),\(dateWalked)")
        }
        let csvString = lines.joined(separator: "\n")

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue = "sf-stairways-export.csv"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try csvString.write(to: url, atomically: true, encoding: .utf8)
                operationResult = "Exported \(selectedStairways.count) stairways to \(url.lastPathComponent)."
            } catch {
                operationResult = "Export failed: \(error.localizedDescription)"
            }
        }
    }
}
