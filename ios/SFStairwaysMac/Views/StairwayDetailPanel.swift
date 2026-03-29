import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct StairwayDetailPanel: View {
    @Environment(\.modelContext) private var modelContext

    let stairway: Stairway
    let walkRecord: WalkRecord?
    let override: StairwayOverride?
    let tags: [StairwayTag]
    let tagAssignments: [TagAssignment]

    // Editable override fields — initialized from the existing override on appear.
    @State private var editStepCount: String = ""
    @State private var editHeightFt: String = ""
    @State private var editDescription: String = ""
    @State private var overrideSaved = false

    // Tag picker state
    @State private var showTagPicker = false

    // Inline create-and-assign state
    @State private var showCreateTagField = false
    @State private var inlineTagName = ""

    // Notes editing state
    @State private var isEditingNotes = false
    @State private var editNotesText: String = ""

    // Photo drop state
    @State private var isPhotoDropTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                dataComparisonTable
                curatorOverridesSection
                notesSection
                tagsSection
                photosSection
            }
            .padding(20)
        }
        .navigationTitle(stairway.name)
        .onAppear { loadOverrideFields() }
        .onChange(of: stairway.id) {
            loadOverrideFields()
            isEditingNotes = false
            showCreateTagField = false
            inlineTagName = ""
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stairway.name)
                    .font(.title2.bold())
                Text(stairway.neighborhood)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            walkedBadge
        }
    }

    @ViewBuilder
    private var walkedBadge: some View {
        if walkRecord?.walked == true {
            Label("Walked", systemImage: "checkmark.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(Color.walkedGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.walkedGreen.opacity(0.12), in: Capsule())
        } else {
            Label("Not Walked", systemImage: "circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1), in: Capsule())
        }
    }

    // MARK: - Data Comparison Table

    private var dataComparisonTable: some View {
        GroupBox("Data") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Field")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("Catalog")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("Walk Data")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                Divider().gridCellColumns(3)

                dataRow("Height",
                    catalog: stairway.heightFt.map { "\(Int($0)) ft" } ?? "—",
                    walk: walkRecord?.elevationGain.map { "\(Int($0)) ft gained" } ?? "—"
                )
                dataRow("Step Count",
                    catalog: "—",
                    walk: walkRecord?.stepCount.map { "\($0) steps (HealthKit)" } ?? "—"
                )
                dataRow("Coordinates",
                    catalog: stairway.hasValidCoordinate
                        ? String(format: "%.4f, %.4f", stairway.lat ?? 0, stairway.lng ?? 0)
                        : "Missing",
                    walk: "—"
                )
                dataRow("Neighborhood",
                    catalog: stairway.neighborhood,
                    walk: "—"
                )
                dataRow("Closed",
                    catalog: stairway.closed ? "Yes" : "No",
                    walk: "—"
                )
                dataRow("Date Walked",
                    catalog: "—",
                    walk: walkRecord?.dateWalked.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—"
                )
                dataRow("Walk Method",
                    catalog: "—",
                    walk: walkRecord?.walkMethod ?? "—"
                )
                dataRow("Proximity Verified",
                    catalog: "—",
                    walk: walkRecord?.proximityVerified.map { $0 ? "Yes" : "No" } ?? "—"
                )
                dataRow("Hard Mode",
                    catalog: "—",
                    walk: walkRecord?.hardModeAtCompletion == true ? "Yes" : "—"
                )

                if let url = stairway.sourceURL {
                    GridRow {
                        Text("Source")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Link(url, destination: URL(string: url) ?? URL(string: "about:blank")!)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("—")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func dataRow(_ field: String, catalog: String, walk: String) -> some View {
        GridRow {
            Text(field)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(catalog)
                .font(.system(size: 12))
            Text(walk)
                .font(.system(size: 12))
                .foregroundStyle(walk == "—" ? .tertiary : .primary)
        }
    }

    // MARK: - Curator Overrides

    private var curatorOverridesSection: some View {
        GroupBox("Curator Overrides") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Verified Step Count")
                        .font(.system(size: 13))
                        .frame(width: 160, alignment: .leading)
                    TextField("e.g. 148", text: $editStepCount)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                HStack {
                    Text("Verified Height (ft)")
                        .font(.system(size: 13))
                        .frame(width: 160, alignment: .leading)
                    TextField("e.g. 82.5", text: $editHeightFt)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Curator Description")
                        .font(.system(size: 13))
                    TextEditor(text: $editDescription)
                        .font(.system(size: 12))
                        .frame(minHeight: 80)
                        .border(Color.secondary.opacity(0.3))
                }
                HStack {
                    Button(overrideSaved ? "Saved ✓" : "Save Overrides") {
                        saveOverrides()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(overrideSaved)
                    Spacer()
                }
            }
            .padding(8)
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        GroupBox("Notes") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Personal Notes")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    if walkRecord != nil && !isEditingNotes {
                        Button("Edit") {
                            editNotesText = walkRecord?.notes ?? ""
                            isEditingNotes = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if isEditingNotes {
                    TextEditor(text: $editNotesText)
                        .font(.system(size: 12))
                        .frame(minHeight: 80)
                        .border(Color.secondary.opacity(0.3))
                    HStack {
                        Button("Save") {
                            saveNotes()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Cancel") {
                            isEditingNotes = false
                        }
                        .buttonStyle(.bordered)
                    }
                } else if let notes = walkRecord?.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12))
                    Button("Promote to Curator Description") {
                        promoteNotes(notes)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text("No personal notes recorded for this walk.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if let desc = override?.stairwayDescription, !desc.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Curator Description (current)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(desc)
                            .font(.system(size: 12))
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        GroupBox("Tags") {
            VStack(alignment: .leading, spacing: 8) {
                let assignedTagIDs = Set(tagAssignments.filter { $0.stairwayID == stairway.id }.map(\.tagID))
                let assignedTags = tags.filter { assignedTagIDs.contains($0.id) }

                if assignedTags.isEmpty {
                    Text("No tags assigned.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(assignedTags) { tag in
                            HStack(spacing: 4) {
                                Text(tag.name)
                                    .font(.system(size: 12))
                                Button {
                                    removeTag(tagID: tag.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.brandAmber.opacity(0.15), in: Capsule())
                        }
                    }
                }

                let unassignedTags = tags.filter { !assignedTagIDs.contains($0.id) }
                Menu("Add Tag") {
                    ForEach(unassignedTags) { tag in
                        Button(tag.name) {
                            addTag(tagID: tag.id)
                        }
                    }
                    if !unassignedTags.isEmpty {
                        Divider()
                    }
                    Button("Create & Assign…") {
                        showCreateTagField = true
                        inlineTagName = ""
                    }
                }
                .menuStyle(.borderedButton)

                if showCreateTagField {
                    HStack(spacing: 6) {
                        TextField("Tag name…", text: $inlineTagName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { createAndAssignInlineTag() }
                        Button("Add") { createAndAssignInlineTag() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(inlineTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button("Cancel") {
                            showCreateTagField = false
                            inlineTagName = ""
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Photos

    private var photosSection: some View {
        GroupBox("Photos") {
            VStack(alignment: .leading, spacing: 8) {
                let photos = walkRecord?.photoArray ?? []

                if photos.isEmpty {
                    Text("No local photos for this walk.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: Array(repeating: .init(.fixed(100)), count: 4), spacing: 8) {
                        ForEach(photos) { photo in
                            PhotoThumbnailView(photo: photo)
                        }
                    }
                }

                HStack {
                    if walkRecord != nil {
                        Button("Add Photos...") {
                            openPhotoPicker()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Text("Mark as walked first to add photos.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isPhotoDropTargeted ? Color.brandAmber.opacity(0.12) : Color.clear)
            .onDrop(of: [UTType.fileURL], isTargeted: $isPhotoDropTargeted) { providers in
                guard walkRecord != nil else { return false }
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url = url else { return }
                        let ext = url.pathExtension.lowercased()
                        guard ["jpg", "jpeg", "png", "heic"].contains(ext) else { return }
                        guard let data = try? Data(contentsOf: url) else { return }
                        DispatchQueue.main.async { importImages(from: [data]) }
                    }
                }
                return true
            }
        }
    }

    // MARK: - Actions

    private func loadOverrideFields() {
        overrideSaved = false
        editStepCount = override?.verifiedStepCount.map { String($0) } ?? ""
        editHeightFt = override?.verifiedHeightFt.map { String($0) } ?? ""
        editDescription = override?.stairwayDescription ?? ""
    }

    private func saveOverrides() {
        let target: StairwayOverride
        if let existing = override {
            target = existing
        } else {
            target = StairwayOverride(stairwayID: stairway.id)
            modelContext.insert(target)
        }

        target.verifiedStepCount = Int(editStepCount.trimmingCharacters(in: .whitespaces))
        target.verifiedHeightFt = Double(editHeightFt.trimmingCharacters(in: .whitespaces))
        let desc = editDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        target.stairwayDescription = desc.isEmpty ? nil : desc
        target.updatedAt = Date()

        try? modelContext.save()
        overrideSaved = true

        // Reset the saved indicator after a moment.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            overrideSaved = false
        }
    }

    private func promoteNotes(_ notes: String) {
        editDescription = notes
        saveOverrides()
    }

    private func addTag(tagID: String) {
        let assignment = TagAssignment(stairwayID: stairway.id, tagID: tagID)
        modelContext.insert(assignment)
        try? modelContext.save()
    }

    private func removeTag(tagID: String) {
        let toDelete = tagAssignments.filter { $0.stairwayID == stairway.id && $0.tagID == tagID }
        toDelete.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }

    private func createAndAssignInlineTag() {
        let name = inlineTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let tag = StairwayTag(id: slug, name: name, isPreset: false)
        modelContext.insert(tag)
        let assignment = TagAssignment(stairwayID: stairway.id, tagID: slug)
        modelContext.insert(assignment)
        try? modelContext.save()
        showCreateTagField = false
        inlineTagName = ""
    }

    private func saveNotes() {
        walkRecord?.notes = editNotesText
        try? modelContext.save()
        isEditingNotes = false
    }

    private func openPhotoPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.jpeg, .png, .heic, .image]
        guard panel.runModal() == .OK else { return }
        let dataItems = panel.urls.compactMap { try? Data(contentsOf: $0) }
        importImages(from: dataItems)
    }

    private func importImages(from dataItems: [Data]) {
        guard let record = walkRecord else { return }
        for rawData in dataItems {
            guard let nsImage = NSImage(data: rawData),
                  let tiff = nsImage.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiff),
                  let jpegData = bitmapRep.representation(
                      using: .jpeg,
                      properties: [.compressionFactor: NSNumber(value: 0.85)]
                  ) else { continue }
            let photo = WalkPhoto(imageData: jpegData)
            photo.walkRecord = record
            modelContext.insert(photo)
        }
        try? modelContext.save()
    }
}

// MARK: - Photo Thumbnail

private struct PhotoThumbnailView: View {
    let photo: WalkPhoto
    @State private var showDeleteConfirm = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let data = photo.thumbnailData ?? photo.imageData,
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                }
            }
            .frame(width: 100, height: 100)
            .clipped()
            .cornerRadius(6)

            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.red)
                    .background(Color.white.clipShape(Circle()))
            }
            .buttonStyle(.plain)
            .padding(4)
            .confirmationDialog("Delete this photo?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(photo)
                    try? modelContext.save()
                }
            }
        }
    }
}

// MARK: - Flow Layout (wrapping HStack for tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width > width && rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
