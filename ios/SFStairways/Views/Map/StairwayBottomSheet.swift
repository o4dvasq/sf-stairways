import SwiftUI
import SwiftData
import Photos

struct StairwayBottomSheet: View {
    let stairway: Stairway
    let locationManager: LocationManager

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
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

    @State private var store = StairwayStore()

    @State private var triggerCuratorPromote = false
    @State private var showHardModeAlert = false
    @State private var showRemoveWalkAlert = false
    @State private var toastMessage: String? = nil
    @State private var failedPhotoIDs: Set<PersistentIdentifier> = []
    @State private var showNeighborhoodDetail = false
    @State private var showTagEditor = false
    @State private var showPhotoWalkedAlert = false
    @State private var photoWalkedPromptShown = false
    @State private var shareImage: UIImage? = nil
    @State private var showShareSheet = false
    @State private var celebrationTrigger = 0

    private enum CuratorField: Hashable {
        case height, description
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

    private enum StairwayState { case unwalked, walked }

    private var state: StairwayState {
        isWalked ? .walked : .unwalked
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Collapsed content (fits at .height(390)) ──────────────

                if isWalked {
                    walkedBanner
                        .padding(.horizontal, -20)
                        .padding(.top, -20)
                        .transition(.move(edge: .top).combined(with: .opacity))

                    walkedIconsRow

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
                } else {
                    headerSection
                    statsRow
                    Text("Not yet walked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
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
        .animation(.easeInOut(duration: 0.4), value: isWalked)
        .background(Color(.systemBackground).ignoresSafeArea())
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
        .alert("Mark as walked?", isPresented: $showHardModeAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Mark Anyway") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    markWalked(proximityVerified: false)
                }
            }
        } message: {
            Text("You're not near this stairway. You can still log it, but it won't count as proximity-verified.")
        }
        .alert("Mark as Not Walked?", isPresented: $showRemoveWalkAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) { removeRecord() }
        } message: {
            Text("This will remove the walk record for this stairway.")
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker { imageData in addPhoto(imageData: imageData) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { imageData in addPhoto(imageData: imageData) }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showTagEditor) {
            TagEditorSheet(stairwayID: stairway.id)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ActivityShareSheet(activityItems: [
                    image,
                    "Climb every stair in SF — sfstairways.app"
                ])
                .presentationDetents([.medium, .large])
            }
        }
        .alert("Mark as Walked?", isPresented: $showPhotoWalkedAlert) {
            Button("Mark Walked") { attemptMarkWalked() }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("You just added a photo. Would you like to mark this stairway as walked?")
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
        .sheet(isPresented: $showNeighborhoodDetail) {
            NavigationStack {
                NeighborhoodDetail(neighborhoodName: stairway.neighborhood)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { showNeighborhoodDetail = false }
                        }
                    }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stairway.name)
                    .font(.title3)
                    .fontWeight(.medium)
                Button {
                    showNeighborhoodDetail = true
                } label: {
                    HStack(spacing: 3) {
                        Text(stairway.neighborhood)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.secondary.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                if stairway.closed {
                    Text("Closed")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.closedRed)
                        .padding(.top, 2)
                }
            }
            Spacer()
            if isWalked {
                Button {
                    generateShareCard()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.brandOrange)
                }
            }
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
                    .padding(.leading, 8)
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            if let verifiedHeight = currentOverride?.verifiedHeightFt {
                verifiedStatText("\(Int(verifiedHeight)) ft")
            } else if let height = stairway.heightFt {
                Text("\(Int(height)) ft")
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

    // MARK: - Walked Banner

    private var walkedBanner: some View {
        let neighborhoodIDs = Set(store.stairways(in: stairway.neighborhood).map(\.id))
        let total = neighborhoodIDs.count
        let walkedCount = walkRecords.filter { neighborhoodIDs.contains($0.stairwayID) && $0.walked }.count

        return Button {
            showRemoveWalkAlert = true
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stairway.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    if total > 1 {
                        Text("\(stairway.neighborhood) · \(walkedCount) of \(total)")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    } else {
                        Text(stairway.neighborhood)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
                Spacer()
                HStack(spacing: 6) {
                    if walkRecord?.proximityVerified == false {
                        Image(systemName: "xmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.brandAmber)
                    }
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: celebrationTrigger)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.walkedGreen)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Walked Icons Row

    private var walkedIconsRow: some View {
        HStack(spacing: 16) {
            Button {
                generateShareCard()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brandOrange)
            }
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
            Button {
                editingDate = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statsRow
        }
    }

    // MARK: - Neighborhood Progress Line

    @ViewBuilder
    private var neighborhoodProgressLine: some View {
        let neighborhoodIDs = Set(store.stairways(in: stairway.neighborhood).map(\.id))
        let total = neighborhoodIDs.count
        let walkedCount = walkRecords.filter { neighborhoodIDs.contains($0.stairwayID) && $0.walked }.count
        if total > 1 {
            Text("\(walkedCount) of \(total) in \(stairway.neighborhood)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch state {
        case .unwalked:
            ActionButton(title: "Mark Walked", icon: "checkmark.circle", color: Color.walkedGreen, action: attemptMarkWalked)
        case .walked:
            EmptyView()
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if authManager.isCurator && curatorModeActive && !notesText.isEmpty {
                HStack {
                    Spacer()
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
            FlowLayout(spacing: 8) {
                ForEach(stairwayTags) { tag in
                    Text(tag.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(.white)
                        .background(Color.tagPalette[tag.colorIndex % Color.tagPalette.count])
                        .clipShape(Capsule())
                }
                Button {
                    showTagEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Add Tag")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundStyle(Color.forestGreen.opacity(0.7))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.forestGreen.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain)
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

    // MARK: - Share Card

    @MainActor
    private func generateShareCard() {
        let photoImage = walkRecord?.photoArray.first.flatMap { UIImage(data: $0.imageData ?? Data()) }
        let heightFt = currentOverride?.verifiedHeightFt ?? stairway.heightFt

        let neighborhoodIDs = Set(store.stairways(in: stairway.neighborhood).map(\.id))
        let neighborhoodTotal = neighborhoodIDs.count
        let neighborhoodWalked = walkRecords.filter { neighborhoodIDs.contains($0.stairwayID) && $0.walked }.count

        let cardView = ShareCardView(
            stairwayName: stairway.name,
            neighborhood: stairway.neighborhood,
            heightFt: heightFt,
            photoImage: photoImage,
            neighborhoodWalked: neighborhoodWalked,
            neighborhoodTotal: neighborhoodTotal
        )

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0

        guard let image = renderer.uiImage else { return }
        shareImage = image
        showShareSheet = true
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

        // Fire celebration after save so the animation context is clean of any SwiftData update.
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.4)) {
            celebrationTrigger += 1
        }
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

        if !isWalked && !photoWalkedPromptShown {
            photoWalkedPromptShown = true
            showPhotoWalkedAlert = true
        }

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
        curatorHeightText = o.verifiedHeightFt.map { "\($0)" } ?? ""
        curatorDescription = o.stairwayDescription ?? ""
    }

    private func saveCuratorData() {
        curatorDirty = false
        let height = Double(curatorHeightText)
        let desc = curatorDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let descValue: String? = desc.isEmpty ? nil : desc

        if height == nil && descValue == nil {
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
