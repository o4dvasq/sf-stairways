import SwiftUI
import SwiftData
import Photos

struct StairwayBottomSheet: View {
    let stairway: Stairway
    let locationManager: LocationManager

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @Environment(ActiveWalkManager.self) private var activeWalkManager
    @Query private var walkRecords: [WalkRecord]
    @Query private var overrides: [StairwayOverride]
    @Query private var allTags: [StairwayTag]
    @Query private var allAssignments: [TagAssignment]

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
    @State private var suggestionService = PhotoSuggestionService()
    @State private var addingAssetID: String?

    @AppStorage("curatorModeActive") private var curatorModeActive = false

    @State private var triggerCuratorPromote = false
    @State private var showCancelWalkAlert = false
    @State private var showHardModeAlert = false
    @State private var toastMessage: String? = nil
    @State private var failedPhotoIDs: Set<PersistentIdentifier> = []

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

    /// Merged photo list: remote Supabase photos + local SwiftData photos, sorted most recent first.
    private var mergedPhotos: [PhotoSource] {
        let remote = photoLikeService.sortedPhotos.map { PhotoSource.remote($0) }
        let local = (walkRecord?.photoArray ?? []).map { PhotoSource.local($0) }
        return (remote + local).sorted { $0.createdAt > $1.createdAt }
    }

    // Start Walk remains proximity-gated — you should be at the stairway to begin a session.
    private var isStartWalkDisabled: Bool {
        guard authManager.hardModeEnabled else { return false }
        return !locationManager.isWithinRadius(150, ofLatitude: stairway.lat ?? 0, longitude: stairway.lng ?? 0)
    }

    private enum StairwayState { case unwalked, walked }

    private var state: StairwayState {
        isWalked ? .walked : .unwalked
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Collapsed content (fits at .height(390)) ──────────────

                headerSection
                statsRow
                if activeWalkManager.isActive(for: stairway.id) {
                    activeSessionBanner
                } else {
                    walkStatusCard
                    actionButtons
                }

                // ── Expanded content (revealed by dragging to .large) ─────

                Divider()
                    .padding(.vertical, 4)

                // Curator commentary (all users — published only)
                if !(authManager.isCurator && curatorModeActive) {
                    CuratorCommentaryView(commentary: curatorService.commentary)
                }

                notesSection

                tagsSection

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

                suggestedPhotosSection

                PhotoCarousel(
                    photos: mergedPhotos,
                    likedPhotoIds: photoLikeService.likedPhotoIds,
                    userId: authManager.userId,
                    failedPhotoIDs: failedPhotoIDs,
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

                if stairway.geocodeSource == "urban_hiker",
                   let lat = stairway.lat,
                   let lng = stairway.lng,
                   let url = URL(string: "https://www.google.com/maps/d/viewer?mid=1F4TY3dl4yiG6VBqigpnrFvhsbK_FYcsW&ll=\(lat),\(lng)&z=18") {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "safari")
                            Text("View on Urban Hiker SF Map")
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
        .overlay(alignment: .top) {
            if let msg = toastMessage {
                Text(msg)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray2))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: toastMessage)
        .task(id: toastMessage) {
            guard toastMessage != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            toastMessage = nil
        }
        .alert("Cancel this walk?", isPresented: $showCancelWalkAlert) {
            Button("Cancel Walk", role: .destructive) { activeWalkManager.cancelWalk() }
            Button("Keep Walking", role: .cancel) { }
        } message: {
            Text("Your progress won't be saved.")
        }
        .alert("Mark as walked?", isPresented: $showHardModeAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Mark Anyway") { markWalked(proximityVerified: false) }
        } message: {
            Text("You're not near this stairway. You can still log it, but it won't count as proximity-verified.")
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker { imageData in addPhoto(imageData: imageData) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { imageData in addPhoto(imageData: imageData) }
                .ignoresSafeArea()
        }
        .onAppear {
            notesText = walkRecord?.notes ?? ""
            editingNotes = false
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
        .task(id: walkRecord?.dateWalked) {
            guard let record = walkRecord, record.walked, let dateWalked = record.dateWalked else {
                return
            }
            suggestionService.fetch(
                dateWalked: dateWalked,
                addedPhotoAssetIDs: record.addedPhotoAssetIDs,
                dismissedPhotoIDs: record.dismissedPhotoIDs
            )
        }
        .onChange(of: curatorFocus) { _, newFocus in
            if newFocus == nil && curatorDirty { saveCuratorData() }
        }
        .onDisappear {
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
            Menu {
                Button { showCamera = true } label: {
                    Label("Take Photo", systemImage: "camera")
                }
                Button { showPhotoPicker = true } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.forestGreen)
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            if let verifiedStairs = currentOverride?.verifiedStepCount {
                verifiedStatText("\(verifiedStairs) stairs")
            } else if let steps = walkRecord?.stepCount, walkRecord?.walkStartTime != nil {
                // Only show HealthKit step count when it came from an active walk session.
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
            if let elevation = walkRecord?.elevationGain, walkRecord?.walkStartTime != nil {
                // Only show HealthKit elevation when it came from an active walk session.
                Text("\(Int(elevation)) ft gained")
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

    // MARK: - Active Session Banner

    private var activeSessionBanner: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Walking now")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.walkedGreen)
                    Text(formatElapsed(activeWalkManager.elapsedSeconds))
                        .font(.system(size: 36, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Menu {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                    }
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 44, height: 44)
                        .background(Color.forestGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button {
                    endWalkSession()
                } label: {
                    Text("End Walk")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.walkedGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button {
                    showCancelWalkAlert = true
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(Color.walkedGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
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
                        HStack(spacing: 4) {
                            Text("Walked")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.walkedGreen)
                            if walkRecord?.proximityVerified == false {
                                Image(systemName: "xmark.seal.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.brandAmber)
                            }
                        }
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
                    attemptMarkWalked()
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
        case .unwalked:
            HStack(spacing: 10) {
                ActionButton(title: "Start Walk", icon: "figure.walk", color: Color.forestGreen, action: startWalk)
                    .opacity(isStartWalkDisabled ? 0.4 : 1.0)
                    .disabled(isStartWalkDisabled)
                ActionButton(title: "Mark Walked", icon: "checkmark.circle", color: Color.walkedGreen, action: attemptMarkWalked)
            }
        case .walked:
            ActionButton(title: "Not Walked", icon: "arrow.uturn.backward", color: Color.brandAmber, action: removeRecord)
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

    // MARK: - Tags Section

    private var stairwayTags: [StairwayTag] {
        let assignedTagIDs = Set(allAssignments.filter { $0.stairwayID == stairway.id }.map(\.tagID))
        // Deduplicate by id (CloudKit + seed can create duplicates)
        var seen = Set<String>()
        return allTags
            .filter { assignedTagIDs.contains($0.id) && seen.insert($0.id).inserted }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.subheadline)
                .fontWeight(.medium)

            if stairwayTags.isEmpty {
                Text("No tags assigned.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(stairwayTags) { tag in
                        Text(tag.name)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(Color.forestGreen)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.forestGreen, lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Suggested Photos Section

    @ViewBuilder
    private var suggestedPhotosSection: some View {
        if isWalked,
           let record = walkRecord,
           let dateWalked = record.dateWalked,
           !suggestionService.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested from \(dateWalked.formatted(date: .long, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestionService.suggestions, id: \.localIdentifier) { asset in
                            SuggestedPhotoCard(
                                asset: asset,
                                isAdding: addingAssetID == asset.localIdentifier,
                                onAdd: { addSuggestedPhoto(asset: asset) },
                                onDismiss: { dismissSuggestedPhoto(asset: asset) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .transition(.opacity)
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

    private func attemptMarkWalked() {
        guard authManager.hardModeEnabled else {
            markWalked(proximityVerified: nil)
            return
        }
        let isWithinRange = locationManager.isWithinRadius(150, ofLatitude: stairway.lat ?? 0, longitude: stairway.lng ?? 0)
        if isWithinRange {
            markWalked(proximityVerified: true)
        } else {
            showHardModeAlert = true
        }
    }

    private func markWalked(proximityVerified: Bool? = nil) {
        if let record = walkRecord {
            record.walked = true
            record.dateWalked = record.dateWalked ?? Date()
            record.hardModeAtCompletion = authManager.hardModeEnabled
            record.proximityVerified = proximityVerified
            record.updatedAt = Date()
        } else {
            let record = WalkRecord(stairwayID: stairway.id, walked: true, dateWalked: Date())
            record.hardModeAtCompletion = authManager.hardModeEnabled
            record.proximityVerified = proximityVerified
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    private func startWalk() {
        if activeWalkManager.hasActiveSession && !activeWalkManager.isActive(for: stairway.id) {
            let name = activeWalkManager.activeStairwayName ?? "another stairway"
            toastMessage = "Finish your walk at \(name) first."
            return
        }
        // Create WalkRecord immediately so photos taken mid-walk have a record to attach to.
        if walkRecord == nil {
            let record = WalkRecord(stairwayID: stairway.id)
            modelContext.insert(record)
            try? modelContext.save()
        }
        activeWalkManager.startWalk(stairwayID: stairway.id, name: stairway.name)
    }

    private func endWalkSession() {
        guard let window = activeWalkManager.endWalk() else { return }
        Task {
            let stats = await HealthKitService.fetchWalkStats(from: window.startTime, to: window.endTime)
            await MainActor.run {
                finalizeActiveWalk(startTime: window.startTime, endTime: window.endTime, steps: stats.steps, elevation: stats.elevationFeet)
            }
        }
    }

    private func finalizeActiveWalk(startTime: Date, endTime: Date, steps: Int?, elevation: Double?) {
        let record: WalkRecord
        if let existing = walkRecord {
            record = existing
        } else {
            record = WalkRecord(stairwayID: stairway.id)
            modelContext.insert(record)
        }
        record.walked = true
        record.dateWalked = startTime
        record.walkStartTime = startTime
        record.walkEndTime = endTime
        record.hardModeAtCompletion = authManager.hardModeEnabled
        record.proximityVerified = authManager.hardModeEnabled ? true : nil
        if let steps { record.stepCount = steps }
        if let elevation { record.elevationGain = elevation }
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

        guard let userId = authManager.userId else {
            print("[StairwayBottomSheet] Photo upload skipped — user not authenticated")
            return
        }
        Task { @MainActor in
            do {
                try await photoLikeService.uploadPhoto(
                    stairwayId: stairway.id,
                    userId: userId,
                    imageData: imageData
                )
                // Upload succeeded — remove local copy to avoid duplicate in merged list
                modelContext.delete(photo)
                try? modelContext.save()
            } catch {
                // Local photo stays as offline fallback; mark as failed for badge UI
                failedPhotoIDs.insert(photo.persistentModelID)
                print("[StairwayBottomSheet] Supabase photo upload failed: \(error)")
            }
        }
    }

    private func addSuggestedPhoto(asset: PHAsset) {
        guard let record = walkRecord else { return }
        let id = asset.localIdentifier
        addingAssetID = id
        Task {
            defer { addingAssetID = nil }
            guard let imageData = await suggestionService.loadFullImage(asset: asset) else { return }
            withAnimation {
                suggestionService.removeSuggestion(withID: id)
            }
            record.addedPhotoAssetIDs.append(id)
            record.updatedAt = Date()
            addPhoto(imageData: imageData)
        }
    }

    private func dismissSuggestedPhoto(asset: PHAsset) {
        guard let record = walkRecord else { return }
        let id = asset.localIdentifier
        withAnimation {
            suggestionService.removeSuggestion(withID: id)
        }
        record.dismissedPhotoIDs.append(id)
        record.updatedAt = Date()
        try? modelContext.save()
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

// MARK: - Suggested Photo Card

private struct SuggestedPhotoCard: View {
    let asset: PHAsset
    let isAdding: Bool
    let onAdd: () -> Void
    let onDismiss: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.systemGray5)
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Dismiss button — top-right
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
            }
            .padding(4)
            .disabled(isAdding)

            if isAdding {
                ZStack {
                    Color.black.opacity(0.35)
                    ProgressView()
                        .tint(.white)
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Add button — bottom-left
                VStack {
                    Spacer()
                    HStack {
                        Button(action: onAdd) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .shadow(radius: 1)
                        }
                        .padding(4)
                        Spacer()
                    }
                }
                .frame(width: 100, height: 100)
            }
        }
        .frame(width: 100, height: 100)
        .task {
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            thumbnail = await withCheckedContinuation { continuation in
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: CGSize(width: 200, height: 200),
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    continuation.resume(returning: image)
                }
            }
        }
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
