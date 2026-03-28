import SwiftUI
import SwiftData

struct StairwayBottomSheet: View {
    let stairway: Stairway
    let locationManager: LocationManager

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @Query private var walkRecords: [WalkRecord]
    @Query private var overrides: [StairwayOverride]

    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var editingNotes = false
    @State private var notesText = ""
    @State private var editingDate = false

    // Curator fields (local StairwayOverride)
    @State private var curatorStepCountText = ""
    @State private var curatorHeightText = ""
    @State private var curatorDescription = ""
    @State private var curatorDirty = false
    @FocusState private var curatorFocus: CuratorField?

    // Supabase services
    @State private var curatorService = CuratorService()
    @State private var photoLikeService = PhotoLikeService()

    @AppStorage("curatorModeActive") private var curatorModeActive = false

    @State private var triggerCuratorPromote = false

    private enum CuratorField: Hashable {
        case stepCount, height, description
    }

    private var walkRecord: WalkRecord? {
        walkRecords.first { $0.stairwayID == stairway.id }
    }

    private var currentOverride: StairwayOverride? {
        overrides.first { $0.stairwayID == stairway.id }
    }

    private var isWalked: Bool { walkRecord?.walked ?? false }

    private var isMarkWalkedDisabled: Bool {
        guard authManager.hardModeEnabled else { return false }
        return !locationManager.isWithinRadius(150, ofLatitude: stairway.lat ?? 0, longitude: stairway.lng ?? 0)
    }

    private enum StairwayState { case unsaved, saved, walked }

    private var state: StairwayState {
        guard let record = walkRecord else { return .unsaved }
        return record.walked ? .walked : .saved
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Collapsed content (fits at .height(390)) ──────────────

                headerSection
                statsRow
                walkStatusCard
                actionButtons

                // ── Expanded content (revealed by dragging to .large) ─────

                Divider()
                    .padding(.vertical, 4)

                // Curator commentary (all users — published only)
                if !(authManager.isCurator && curatorModeActive) {
                    CuratorCommentaryView(commentary: curatorService.commentary)
                }

                notesSection

                // Curator editor (curator mode only — below notes)
                if authManager.isCurator && curatorModeActive, let userId = authManager.userId {
                    CuratorEditorView(
                        stairwayId: stairway.id,
                        curatorId: userId,
                        notesText: notesText,
                        service: curatorService,
                        triggerPromote: $triggerCuratorPromote
                    )
                    .id("curatorEditor")
                }

                PhotoCarousel(
                    photos: photoLikeService.sortedPhotos,
                    likedPhotoIds: photoLikeService.likedPhotoIds,
                    userId: authManager.userId,
                    onLikeTap: { photo in
                        if let userId = authManager.userId {
                            Task { await photoLikeService.toggleLike(photo: photo, userId: userId) }
                        }
                    },
                    onAddTap: { showPhotoPicker = true }
                )

                curatorSection

                if let urlString = stairway.sourceURL, let url = URL(string: urlString) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "safari")
                            Text("View on sfstairways.com")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.forestGreen)
                        .padding(14)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker { imageData in addPhoto(imageData: imageData) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { imageData in addPhoto(imageData: imageData) }
                .ignoresSafeArea()
        }
        .onAppear {
            notesText = walkRecord?.notes ?? ""
            initCuratorFields()
        }
        .task {
            if authManager.isCurator && curatorModeActive {
                await curatorService.fetchForEditor(stairwayId: stairway.id)
            } else {
                await curatorService.fetchPublished(stairwayId: stairway.id)
            }
            await photoLikeService.fetchPhotos(stairwayId: stairway.id, userId: authManager.userId)
        }
        .onChange(of: curatorFocus) { _, newFocus in
            if newFocus == nil && curatorDirty { saveCuratorData() }
        }
        .onDisappear {
            if editingNotes { saveNotes() }
            if curatorDirty { saveCuratorData() }
        }
        .onChange(of: triggerCuratorPromote) { _, shouldPromote in
            if shouldPromote {
                withAnimation { proxy.scrollTo("curatorEditor", anchor: .top) }
            }
        }
        } // end ScrollViewReader
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stairway.name)
                    .font(.title3)
                    .fontWeight(.medium)
                Text(stairway.neighborhood)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if stairway.closed {
                    Text("Closed")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.closedRed)
                        .padding(.top, 2)
                }
            }
            Spacer()
            HStack(spacing: 12) {
                Menu {
                    Button { showCamera = true } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                    Button { showPhotoPicker = true } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                stateIndicator
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            if let verifiedStairs = currentOverride?.verifiedStepCount {
                verifiedStatText("\(verifiedStairs) stairs")
            } else if let steps = walkRecord?.stepCount {
                Text("\(steps) steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let verifiedHeight = currentOverride?.verifiedHeightFt {
                verifiedStatText("\(Int(verifiedHeight)) ft")
            } else if let height = stairway.heightFt {
                Text("\(Int(height)) ft")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            let photoCount = photoLikeService.photos.count
            if photoCount > 0 {
                Text("\(photoCount) \(photoCount == 1 ? "photo" : "photos")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func verifiedStatText(_ text: String) -> some View {
        HStack(spacing: 2) {
            Text(text)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 8))
                .foregroundStyle(Color.forestGreen)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Walk Status Card

    private var walkStatusCard: some View {
        VStack(spacing: 10) {
            if isWalked {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.walkedGreen)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Walked")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.walkedGreen)
                        if let date = walkRecord?.dateWalked {
                            Text(date.formatted(date: .long, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        editingDate = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(Color.walkedGreen.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Button {
                    markWalked()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Mark as Walked")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.walkedGreen)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .opacity(isMarkWalkedDisabled ? 0.4 : 1.0)
                .disabled(isMarkWalkedDisabled)

                if isMarkWalkedDisabled {
                    Text("Hard Mode: get within 150m to mark as walked")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if editingDate, let record = walkRecord {
                DatePicker(
                    "Date walked",
                    selection: Binding(
                        get: { record.dateWalked ?? Date() },
                        set: {
                            record.dateWalked = $0
                            record.updatedAt = Date()
                            try? modelContext.save()
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch state {
        case .unsaved:
            HStack(spacing: 10) {
                ActionButton(title: "Save", icon: "bookmark", color: Color.brandAmber, action: saveStairway)
                ActionButton(title: "Mark Walked", icon: "checkmark.circle", color: Color.walkedGreen, action: markWalked)
                    .opacity(isMarkWalkedDisabled ? 0.4 : 1.0)
                    .disabled(isMarkWalkedDisabled)
            }
        case .saved:
            HStack(spacing: 10) {
                ActionButton(title: "Unsave", icon: "bookmark.slash", color: .secondary, action: removeRecord)
                ActionButton(title: "Mark Walked", icon: "checkmark.circle", color: Color.walkedGreen, action: markWalked)
                    .opacity(isMarkWalkedDisabled ? 0.4 : 1.0)
                    .disabled(isMarkWalkedDisabled)
            }
        case .walked:
            HStack(spacing: 10) {
                ActionButton(title: "Unmark Walk", icon: "arrow.uturn.backward", color: Color.brandAmber, action: unmarkWalk)
                ActionButton(title: "Remove", icon: "trash", color: .secondary, action: removeRecord)
            }
        }
    }

    // MARK: - State Indicator

    @ViewBuilder
    private var stateIndicator: some View {
        switch state {
        case .unsaved:
            EmptyView()
        case .saved:
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.brandAmber.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.brandAmber)
                }
                Text("Saved")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brandAmber)
            }
        case .walked:
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.walkedGreenDim)
                        .frame(width: 40, height: 40)
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("Walked")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.walkedGreen)
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("My Notes")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if authManager.isCurator && curatorModeActive && !notesText.isEmpty {
                    Button {
                        triggerCuratorPromote = true
                    } label: {
                        Label("Promote to Commentary", systemImage: "arrow.up.doc")
                            .font(.caption)
                            .foregroundStyle(Color.forestGreen)
                    }
                }
            }

            if editingNotes {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $notesText)
                        .font(.subheadline)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    if notesText.isEmpty {
                        Text("Write a note...")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                HStack {
                    Spacer()
                    Button {
                        saveNotes()
                        editingNotes = false
                    } label: {
                        Text("Save")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.forestGreen)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button {
                        notesText = walkRecord?.notes ?? ""
                        editingNotes = false
                    } label: {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let notes = walkRecord?.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture { editingNotes = true }
            } else {
                Button { editingNotes = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                        Text("Add Note")
                            .font(.subheadline)
                    }
                    .foregroundStyle(Color.forestGreen)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Curator Section (local StairwayOverride)

    @ViewBuilder
    private var curatorSection: some View {
        if isWalked && authManager.isCurator && curatorModeActive {
            VStack(alignment: .leading, spacing: 12) {
                Divider()

                HStack(spacing: 6) {
                    Text("Stairway Info")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if currentOverride?.hasAnyValue == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.forestGreen)
                    }
                }

                HStack {
                    Text("Stair count")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("Add stair count", text: $curatorStepCountText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                        .focused($curatorFocus, equals: .stepCount)
                        .onChange(of: curatorStepCountText) { _, _ in curatorDirty = true }
                }

                HStack {
                    Text("Height (ft)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("Add height", text: $curatorHeightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                        .focused($curatorFocus, equals: .height)
                        .onChange(of: curatorHeightText) { _, _ in curatorDirty = true }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $curatorDescription)
                            .font(.subheadline)
                            .frame(minHeight: 60)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .focused($curatorFocus, equals: .description)
                            .onChange(of: curatorDescription) { _, _ in curatorDirty = true }
                        if curatorDescription.isEmpty {
                            Text("Add description...")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Walk Record Actions

    private func saveStairway() {
        guard walkRecord == nil else { return }
        let record = WalkRecord(stairwayID: stairway.id, walked: false)
        modelContext.insert(record)
        try? modelContext.save()
    }

    private func markWalked() {
        if let record = walkRecord {
            record.walked = true
            record.dateWalked = record.dateWalked ?? Date()
            record.hardModeAtCompletion = authManager.hardModeEnabled
            record.updatedAt = Date()
        } else {
            let record = WalkRecord(stairwayID: stairway.id, walked: true, dateWalked: Date())
            record.hardModeAtCompletion = authManager.hardModeEnabled
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    private func unmarkWalk() {
        guard let record = walkRecord else { return }
        record.walked = false
        record.updatedAt = Date()
        try? modelContext.save()
    }

    private func removeRecord() {
        guard let record = walkRecord else { return }
        modelContext.delete(record)
        try? modelContext.save()
        dismiss()
    }

    private func addPhoto(imageData: Data) {
        let record: WalkRecord
        if let existing = walkRecord {
            record = existing
        } else {
            record = WalkRecord(stairwayID: stairway.id)
            modelContext.insert(record)
        }
        let photo = WalkPhoto(imageData: imageData)
        photo.walkRecord = record
        if record.photos == nil { record.photos = [] }
        record.photos?.append(photo)
        try? modelContext.save()

        guard let userId = authManager.userId else { return }
        Task {
            do {
                try await photoLikeService.uploadPhoto(
                    stairwayId: stairway.id,
                    userId: userId,
                    imageData: imageData
                )
            } catch {
                print("[StairwayBottomSheet] Supabase photo upload failed: \(error)")
            }
        }
    }

    private func saveNotes() {
        if let record = walkRecord {
            record.notes = notesText.isEmpty ? nil : notesText
            record.updatedAt = Date()
        } else if !notesText.isEmpty {
            let record = WalkRecord(stairwayID: stairway.id, notes: notesText)
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    // MARK: - Curator Override Actions

    private func initCuratorFields() {
        guard let o = currentOverride else { return }
        curatorStepCountText = o.verifiedStepCount.map(String.init) ?? ""
        curatorHeightText = o.verifiedHeightFt.map { "\($0)" } ?? ""
        curatorDescription = o.stairwayDescription ?? ""
    }

    private func saveCuratorData() {
        curatorDirty = false
        let stepCount = Int(curatorStepCountText)
        let height = Double(curatorHeightText)
        let desc = curatorDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let descValue: String? = desc.isEmpty ? nil : desc

        if stepCount == nil && height == nil && descValue == nil {
            if let existing = currentOverride {
                modelContext.delete(existing)
                try? modelContext.save()
            }
            return
        }

        let override: StairwayOverride
        if let existing = currentOverride {
            override = existing
        } else {
            override = StairwayOverride(stairwayID: stairway.id)
            modelContext.insert(override)
        }
        override.verifiedStepCount = stepCount
        override.verifiedHeightFt = height
        override.stairwayDescription = descValue
        override.updatedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
