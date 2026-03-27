import SwiftUI
import MapKit
import SwiftData

struct MapTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var walkRecords: [WalkRecord]
    @State private var store = StairwayStore()
    @State private var locationManager = LocationManager()
    @State private var aroundMe = AroundMeManager()
    @State private var selectedStairway: Stairway?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.76, longitude: -122.44),
            span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
        )
    )
    @State private var filter: StairwayFilter = .all
    @State private var showSearch: Bool = false
    @State private var toastMessage: String? = nil

    enum StairwayFilter: String, CaseIterable {
        case all = "All"
        case saved = "Saved"
        case walked = "Walked"
        case nearby = "Nearby"
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                UserAnnotation()

                ForEach(filteredStairways) { stairway in
                    if let coord = stairway.coordinate {
                        Annotation(stairway.name, coordinate: coord, anchor: .bottom) {
                            StairwayAnnotation(
                                stairway: stairway,
                                walkRecord: walkRecord(for: stairway),
                                isSelected: selectedStairway?.id == stairway.id,
                                isDimmed: aroundMe.isDimmed(neighborhood: stairway.neighborhood)
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedStairway = stairway
                                }
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .preferredColorScheme(.dark)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .overlay(alignment: .bottomTrailing) {
                ProgressCard(
                    walkedCount: walkedCount,
                    totalHeightFt: totalHeightFt,
                    totalSteps: totalSteps
                )
                .padding(.trailing, 12)
                .padding(.bottom, 24)
            }

            // Top bar + filter pills + neighborhood chip stacked from the top
            VStack(spacing: 0) {
                topBar
                filterRow

                if aroundMe.isActive, let name = aroundMe.currentNeighborhood {
                    Text("You're in \(name)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.forestGreen.opacity(0.9))
                        .clipShape(Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
        }
        .toast(message: $toastMessage)
        .sheet(item: $selectedStairway) { stairway in
            StairwayBottomSheet(
                stairway: stairway,
                walkRecord: walkRecord(for: stairway),
                locationManager: locationManager,
                onSave: { saveStairway(stairway) },
                onMarkWalked: { markWalked(stairway) },
                onUnmarkWalk: { unmarkWalk(stairway) },
                onRemove: { removeRecord(stairway) },
                onToggleHardMode: { enabled in toggleHardMode(stairway, enabled: enabled) }
            )
            .presentationDetents([.height(390), .medium])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .height(390)))
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchPanel(
                store: store,
                walkRecords: walkRecords,
                userLocation: locationManager.currentLocation,
                onSelectStairway: { stairway in
                    showSearch = false
                    flyTo(stairway)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        selectedStairway = stairway
                    }
                },
                onSelectNeighborhood: { neighborhood in
                    showSearch = false
                    flyToNeighborhood(neighborhood)
                },
                onDismiss: { showSearch = false }
            )
        }
        .onAppear {
            locationManager.requestPermission()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("SF Stairways")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.white)

            Spacer()

            // TODO: Add standalone staircase logo asset (28×28pt) centered here.
            // iOS does not support rendering the app icon via Image("AppIcon").

            // Search button
            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }

            // Around Me button
            Button {
                toggleAroundMe()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(aroundMe.isActive ? Color.white.opacity(0.35) : Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.topBarBackground)
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StairwayFilter.allCases, id: \.self) { f in
                    FilterChip(title: f.rawValue, isActive: filter == f) {
                        withAnimation { filter = f }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Around Me

    private func toggleAroundMe() {
        if aroundMe.isActive {
            withAnimation { aroundMe.deactivate() }
            return
        }

        guard let location = locationManager.currentLocation else {
            withAnimation { toastMessage = "Enable location in Settings to use Around Me" }
            return
        }

        withAnimation {
            if let errorMessage = aroundMe.activate(location: location) {
                toastMessage = errorMessage
            } else {
                flyToUserLocation(location)
            }
        }
    }

    private func flyToUserLocation(_ location: CLLocation) {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        )
        withAnimation { cameraPosition = .region(region) }
    }

    // MARK: - Navigation

    private func flyTo(_ stairway: Stairway) {
        guard let coord = stairway.coordinate else { return }
        let region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        withAnimation { cameraPosition = .region(region) }
    }

    private func flyToNeighborhood(_ neighborhood: String) {
        guard let region = store.region(for: neighborhood) else { return }
        withAnimation { cameraPosition = .region(region) }
    }

    // MARK: - Computed Properties

    private var savedStairwayIDs: Set<String> {
        Set(walkRecords.filter { !$0.walked }.map(\.stairwayID))
    }

    private var walkedStairwayIDs: Set<String> {
        Set(walkRecords.filter(\.walked).map(\.stairwayID))
    }

    private var walkedCount: Int { walkedStairwayIDs.count }

    private var totalHeightFt: Double {
        store.stairways
            .filter { walkedStairwayIDs.contains($0.id) }
            .compactMap(\.heightFt)
            .reduce(0, +)
    }

    private var totalSteps: Int {
        walkRecords.filter(\.walked).compactMap(\.stepCount).reduce(0, +)
    }

    private var filteredStairways: [Stairway] {
        let valid = store.stairways.filter { $0.hasValidCoordinate }
        switch filter {
        case .all:
            return valid
        case .saved:
            return valid.filter { savedStairwayIDs.contains($0.id) }
        case .walked:
            return valid.filter { walkedStairwayIDs.contains($0.id) }
        case .nearby:
            guard let location = locationManager.currentLocation else { return valid }
            return valid
                .filter { $0.distance(from: location) < 1500 }
                .sorted { $0.distance(from: location) < $1.distance(from: location) }
        }
    }

    private func walkRecord(for stairway: Stairway) -> WalkRecord? {
        walkRecords.first { $0.stairwayID == stairway.id }
    }

    // MARK: - Walk Record Actions

    private func saveStairway(_ stairway: Stairway) {
        guard walkRecord(for: stairway) == nil else { return }
        let record = WalkRecord(stairwayID: stairway.id, walked: false)
        modelContext.insert(record)
        try? modelContext.save()
    }

    private func markWalked(_ stairway: Stairway) {
        if let record = walkRecord(for: stairway) {
            record.walked = true
            record.dateWalked = record.dateWalked ?? Date()
            if record.hardMode {
                record.proximityVerified = true
            }
            record.updatedAt = Date()
        } else {
            let record = WalkRecord(stairwayID: stairway.id, walked: true, dateWalked: Date())
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    private func unmarkWalk(_ stairway: Stairway) {
        guard let record = walkRecord(for: stairway) else { return }
        record.walked = false
        record.updatedAt = Date()
        try? modelContext.save()
    }

    private func toggleHardMode(_ stairway: Stairway, enabled: Bool) {
        if let record = walkRecord(for: stairway) {
            if enabled && record.walked {
                record.proximityVerified = false
            }
            record.hardMode = enabled
            record.updatedAt = Date()
        } else if enabled {
            let record = WalkRecord(stairwayID: stairway.id, walked: false)
            record.hardMode = true
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    private func removeRecord(_ stairway: Stairway) {
        guard let record = walkRecord(for: stairway) else { return }
        modelContext.delete(record)
        try? modelContext.save()
        if selectedStairway?.id == stairway.id {
            selectedStairway = nil
        }
    }
}

// MARK: - Progress Card

struct ProgressCard: View {
    let walkedCount: Int
    let totalHeightFt: Double
    let totalSteps: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Progress")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.brandOrange)

            VStack(alignment: .leading, spacing: 2) {
                Text(walkedCount > 0 ? "\(walkedCount) stairways" : "—")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(totalHeightFt > 0 ? "\(Int(totalHeightFt).formatted()) ft" : "—")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(totalSteps > 0 ? "\(totalSteps.formatted()) steps" : "—")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 120, alignment: .leading)
            .background(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isActive ? Color.pillActive : Color.pillInactive)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
    }
}
