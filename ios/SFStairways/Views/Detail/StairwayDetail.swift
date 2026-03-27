import SwiftUI
import SwiftData
import MapKit

struct StairwayDetail: View {
    let stairway: Stairway
    let locationManager: LocationManager

    @Environment(\.modelContext) private var modelContext
    @Query private var walkRecords: [WalkRecord]
    @Query private var overrides: [StairwayOverride]

    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedPhoto: WalkPhoto?
    @State private var editingNotes = false
    @State private var notesText = ""
    @State private var editingDate = false

    // Curator fields
    @State private var curatorStepCountText: String = ""
    @State private var curatorHeightText: String = ""
    @State private var curatorDescription: String = ""
    @State private var curatorDirty = false
    @FocusState private var curatorFocus: CuratorField?

    private enum CuratorField: Hashable {
        case stepCount, height, description
    }

    private var walkRecord: WalkRecord? {
        walkRecords.first { $0.stairwayID == stairway.id }
    }

    private var currentOverride: StairwayOverride? {
        overrides.first { $0.stairwayID == stairway.id }
    }

    private var isWalked: Bool {
        walkRecord?.walked ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Focused map showing stairway location
                detailMap

                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    header

                    // Stats
                    statsRow

                    // Walk status
                    walkStatusCard

                    // Curator data (walked stairways only)
                    curatorSection

                    // Hard Mode toggle
                    hardModeSection

                    // Notes
                    notesSection

                    // Photos grid
                    photosSection

                    // Source link
                    if let urlString = stairway.sourceURL,
                       let url = URL(string: urlString) {
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
                .padding(16)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(stairway.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if walkRecord == nil {
                        Button("Save") {
                            saveStairway()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brandOrange)
                    }
                    Menu {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                        Button {
                            showPhotoPicker = true
                        } label: {
                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        Image(systemName: "camera")
                    }
                }
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker { imageData in
                addPhoto(imageData: imageData)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { imageData in
                addPhoto(imageData: imageData)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoViewer(photo: photo, onDelete: {
                deletePhoto(photo)
            })
        }
        .onAppear {
            notesText = walkRecord?.notes ?? ""
            initCuratorFields()
        }
        .onChange(of: curatorFocus) { _, newFocus in
            if newFocus == nil && curatorDirty {
                saveCuratorData()
            }
        }
        .onDisappear {
            if curatorDirty {
                saveCuratorData()
            }
        }
    }

    // MARK: - Detail Map

    @ViewBuilder
    private var detailMap: some View {
        if let lat = stairway.lat, let lng = stairway.lng {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            let region = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
            )
            Map(initialPosition: .region(region)) {
                Marker(stairway.name, coordinate: coord)
                    .tint(Color.brandOrange)
            }
            .frame(height: 200)
            .allowsHitTesting(false)
        } else {
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 200)
                Text("Location unavailable")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stairway.name)
                    .font(.title2)
                    .fontWeight(.medium)
                Text(stairway.neighborhood)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if stairway.closed {
                Text("Closed")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.closedRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.closedRed.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            // Stair count: verified curator value overrides pedometer steps
            if let verifiedStairs = currentOverride?.verifiedStepCount {
                statItem(value: "\(verifiedStairs)", label: "stairs", verified: true)
                Divider().frame(height: 30)
            } else if let steps = walkRecord?.stepCount {
                statItem(value: "\(steps)", label: "steps")
                Divider().frame(height: 30)
            }

            // Height: verified curator value overrides catalog
            if let verifiedHeight = currentOverride?.verifiedHeightFt {
                statItem(value: "\(Int(verifiedHeight))", label: "feet", verified: true)
                Divider().frame(height: 30)
            } else if let height = stairway.heightFt {
                statItem(value: "\(Int(height))", label: "feet")
                Divider().frame(height: 30)
            }

            let photoCount = walkRecord?.photoArray.count ?? 0
            statItem(value: "\(photoCount)", label: photoCount == 1 ? "photo" : "photos")
        }
    }

    private func statItem(value: String, label: String, verified: Bool = false) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .top, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.medium)
                if verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.forestGreen)
                        .padding(.top, 4)
                }
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Hard Mode

    private var isWalkToggleDisabled: Bool {
        guard walkRecord?.hardMode == true else { return false }
        return !locationManager.isWithinRadius(150, ofLatitude: stairway.lat ?? 0, longitude: stairway.lng ?? 0)
    }

    private var hardModeBinding: Binding<Bool> {
        Binding(
            get: { walkRecord?.hardMode ?? false },
            set: { newValue in
                if let record = walkRecord {
                    if newValue && record.walked {
                        record.proximityVerified = false
                    }
                    record.hardMode = newValue
                    record.updatedAt = Date()
                } else if newValue {
                    let record = WalkRecord(stairwayID: stairway.id, walked: false)
                    record.hardMode = true
                    modelContext.insert(record)
                }
                try? modelContext.save()
            }
        )
    }

    @ViewBuilder
    private var hardModeSection: some View {
        if !stairway.closed {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(Color.forestGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hard Mode")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Require proximity to mark walked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: hardModeBinding)
                        .labelsHidden()
                }
                if walkRecord?.hardMode == true && locationManager.currentLocation == nil {
                    Text("Location required for Hard Mode")
                        .font(.caption2)
                        .foregroundColor(Color.unwalkedSlate)
                }
            }
        }
    }

    // MARK: - Walk Status

    private var walkStatusCard: some View {
        VStack(spacing: 10) {
            Button {
                toggleWalk()
            } label: {
                HStack {
                    Image(systemName: isWalked ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isWalked ? Color.walkedGreen : .secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isWalked ? "Walked" : "Not yet walked")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(isWalked ? Color.walkedGreen : .primary)
                        if isWalked, let date = walkRecord?.dateWalked {
                            Text(date.formatted(date: .long, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if isWalked {
                        Button {
                            editingDate = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(14)
                .background(isWalked ? Color.walkedGreen.opacity(0.1) : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .opacity(isWalkToggleDisabled ? 0.4 : 1.0)
            .disabled(isWalkToggleDisabled)

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

    // MARK: - Curator Section

    @ViewBuilder
    private var curatorSection: some View {
        if isWalked {
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

                // Stair count
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

                // Height
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

                // Description
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

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notes")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button {
                    editingNotes.toggle()
                    if !editingNotes {
                        saveNotes()
                    }
                } label: {
                    Image(systemName: editingNotes ? "checkmark" : "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if editingNotes {
                TextEditor(text: $notesText)
                    .font(.subheadline)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text(notesText.isEmpty ? "Tap to add notes..." : notesText)
                    .font(.subheadline)
                    .foregroundStyle(notesText.isEmpty ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture {
                        editingNotes = true
                    }
            }
        }
    }

    // MARK: - Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photos")
                .font(.subheadline)
                .fontWeight(.medium)

            let photos = walkRecord?.photoArray ?? []
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6)
            ], spacing: 6) {
                ForEach(photos) { photo in
                    if let thumb = photo.thumbnailImage {
                        Image(uiImage: thumb)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture {
                                selectedPhoto = photo
                            }
                    }
                }

                // Add photo button
                Button {
                    showPhotoPicker = true
                } label: {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .foregroundStyle(.tertiary)
                        .aspectRatio(1, contentMode: .fill)
                        .overlay {
                            VStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.title3)
                                Text("Add")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.tertiary)
                        }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveStairway() {
        guard walkRecord == nil else { return }
        let record = WalkRecord(stairwayID: stairway.id, walked: false)
        modelContext.insert(record)
        try? modelContext.save()
    }

    private func toggleWalk() {
        if let record = walkRecord {
            record.toggleWalked()
            if !record.walked {
                editingDate = false
            }
        } else {
            let record = WalkRecord(stairwayID: stairway.id, walked: true, dateWalked: Date())
            modelContext.insert(record)
        }
        try? modelContext.save()
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
        if record.photos == nil {
            record.photos = []
        }
        record.photos?.append(photo)
        try? modelContext.save()
    }

    private func deletePhoto(_ photo: WalkPhoto) {
        modelContext.delete(photo)
        try? modelContext.save()
        selectedPhoto = nil
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

    // MARK: - Curator Actions

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

        // All fields cleared → delete override
        if stepCount == nil && height == nil && descValue == nil {
            if let existing = currentOverride {
                modelContext.delete(existing)
                try? modelContext.save()
            }
            return
        }

        // Update or create
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
