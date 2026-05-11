import SwiftUI
import MapKit
import SwiftData

struct MapTab: View {
    @Query private var walkRecords: [WalkRecord]
    @Query private var overrides: [StairwayOverride]
    @Query private var allTags: [StairwayTag]
    @Query private var allTagAssignments: [TagAssignment]
    @Query private var deletions: [StairwayDeletion]
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.colorScheme) private var colorScheme
    @State private var store = StairwayStore()
    @State private var locationManager = LocationManager()
    @Environment(NeighborhoodStore.self) private var neighborhoodStore
    @State private var aroundMe = AroundMeManager()
    @State private var selectedStairway: Stairway?
    @State private var showNeighborhoodDetail = false
    @State private var neighborhoodDetailName = ""
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.76, longitude: -122.44),
            span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
        )
    )
    @State private var mapSpan: Double = 0.06
    @State private var filter: StairwayFilter = .all
    @State private var activeTagFilter: String? = nil
    @State private var showSettings: Bool = false
    @State private var showTagFilter: Bool = false
    @State private var toastMessage: String? = nil

    enum StairwayFilter: String, CaseIterable {
        case all = "All"
        case walked = "Walked"
        case nearby = "Nearby"
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                // Neighborhood polygon overlays (drawn first, beneath all annotations)
                ForEach(neighborhoodStore.neighborhoods) { hood in
                    let isDimmed = aroundMe.isDimmed(neighborhood: hood.name)
                    let isComplete = completedNeighborhoodNames.contains(hood.name)
                    let fillColor = isComplete ? Color.walkedGreen : hood.color
                    let fillOpacity = isDimmed ? 0.05 : (isComplete ? 0.35 : (colorScheme == .dark ? 0.20 : 0.30))
                    let strokeOpacity = isDimmed ? 0.10 : (isComplete ? 0.65 : (colorScheme == .dark ? 0.40 : 0.50))

                    ForEach(Array(hood.polygons.enumerated()), id: \.offset) { _, ring in
                        MapPolygon(coordinates: ring)
                            .foregroundStyle(fillColor.opacity(fillOpacity))
                            .stroke(fillColor.opacity(strokeOpacity), lineWidth: isComplete ? 1.5 : 1)
                    }
                }

                // Neighborhood centroid labels (visible at mid-to-close zoom; tap → NeighborhoodDetail)
                if mapSpan < 0.04 {
                    ForEach(neighborhoodStore.neighborhoods) { hood in
                        Annotation("", coordinate: hood.centroid, anchor: .center) {
                            Text(hood.name)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(Color.textSecondary.opacity(0.7))
                                .onTapGesture {
                                    neighborhoodDetailName = hood.name
                                    showNeighborhoodDetail = true
                                }
                        }
                    }
                }

                UserAnnotation()

                ForEach(filteredStairways) { stairway in
                    if let coord = stairway.coordinate {
                        Annotation(mapSpan <= 0.02 ? stairway.displayName : "", coordinate: coord, anchor: .bottom) {
                            StairwayAnnotation(
                                stairway: stairway,
                                walkRecord: walkRecord(for: stairway),
                                isSelected: selectedStairway?.id == stairway.id,
                                isDimmed: aroundMe.isDimmed(neighborhood: stairway.neighborhood),
                                scale: pinScale
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
            .onMapCameraChange(frequency: .onEnd) { context in
                mapSpan = context.region.span.latitudeDelta
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .overlay(alignment: .bottomTrailing) {
                ProgressCard(
                    walkedCount: walkedCount,
                    totalHeightFt: totalHeightFt,
                    neighborhoodsVisited: neighborhoodsVisited
                )
                .padding(.trailing, 12)
                .padding(.bottom, 24)
            }
            .overlay(alignment: .bottomLeading) {
                mapLegend
                    .padding(.leading, 12)
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
            StairwayBottomSheet(stairway: stairway, locationManager: locationManager)
                .presentationDetents([.height(390), .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(390)))
        }
        .sheet(isPresented: $showTagFilter) {
            TagFilterSheet(activeTagID: $activeTagFilter)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showNeighborhoodDetail) {
            NavigationStack {
                NeighborhoodDetail(neighborhoodName: neighborhoodDetailName)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { showNeighborhoodDetail = false }
                        }
                    }
            }
        }
        .onChange(of: coordinator.pendingStairway) { _, stairway in
            guard let stairway else { return }
            coordinator.pendingStairway = nil
            flyTo(stairway)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                selectedStairway = stairway
            }
        }
        .onChange(of: coordinator.pendingNeighborhood) { _, neighborhood in
            guard let neighborhood else { return }
            coordinator.pendingNeighborhood = nil
            flyToNeighborhood(neighborhood)
        }
        .onAppear {
            locationManager.requestPermission()
        }
        .onChange(of: activeTagFilter) { _, newTagID in
            showTagDroppedToastIfNeeded(for: newTagID)
        }
        .onChange(of: filter) { _, newValue in
            showTagDroppedToastIfNeeded(for: activeTagFilter)
            if newValue == .nearby, let location = locationManager.currentLocation {
                flyToUserLocation(location)
            }
        }
        .onAppear {
            store.applyDeletions(deletions.map(\.stairwayID))
        }
        .onChange(of: deletions) { _, d in
            store.applyDeletions(d.map(\.stairwayID))
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            // Stairs icon centered — decorative branding
            StairShape()
                .fill(Color.white)
                .frame(width: 20, height: 20)

            HStack {
                // Settings on the leading side
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }

                Spacer()

                // Around Me + Tag Filter on the trailing side
                HStack(spacing: 8) {
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

                    // Tag filter button — hidden, keep piping intact
                    // Button { showTagFilter = true } ...
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 6)
        .background(Color.topBarBackground)
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        HStack(spacing: 8) {
            ForEach(StairwayFilter.allCases, id: \.self) { f in
                FilterChip(title: f.rawValue, isActive: filter == f) {
                    withAnimation { filter = f }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
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
            if let errorMessage = aroundMe.activate(location: location, store: neighborhoodStore) {
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

    /// Static pin scale — no dynamic resizing for performance.
    private var pinScale: CGFloat { 1.0 }

    private var completedNeighborhoodNames: Set<String> {
        let walkedIDs = walkedStairwayIDs
        let grouped = Dictionary(grouping: store.stairways, by: \.neighborhood)
        return Set(grouped.compactMap { name, stairways in
            stairways.allSatisfy { walkedIDs.contains($0.id) } ? name : nil
        })
    }

    private var walkedStairwayIDs: Set<String> {
        Set(walkRecords.filter(\.walked).map(\.stairwayID))
    }

    private var walkedCount: Int { walkedStairwayIDs.count }

    private var neighborhoodsVisited: Int {
        let grouped = Dictionary(grouping: store.stairways, by: \.neighborhood)
        return grouped.filter { _, stairways in
            stairways.contains { walkedStairwayIDs.contains($0.id) }
        }.count
    }

    private var totalHeightFt: Double {
        store.stairways
            .filter { walkedStairwayIDs.contains($0.id) }
            .compactMap { store.resolvedHeightFt(for: $0, override: override(for: $0)) }
            .reduce(0, +)
    }

    private func override(for stairway: Stairway) -> StairwayOverride? {
        overrides.first { $0.stairwayID == stairway.id }
    }

    /// Stairways passing the state filter only (no tag filter applied).
    private var stateFilteredStairways: [Stairway] {
        let valid = store.stairways.filter { $0.hasValidCoordinate }
        switch filter {
        case .all:
            return valid
        case .walked:
            return valid.filter { walkedStairwayIDs.contains($0.id) }
        case .nearby:
            guard let location = locationManager.currentLocation else { return valid }
            return valid
                .filter { $0.distance(from: location) < 1500 }
                .sorted { $0.distance(from: location) < $1.distance(from: location) }
        }
    }

    /// Stairways passing both the state filter and the active tag filter (AND logic).
    /// If AND yields zero results the state filter is dropped and only the tag filter applies.
    private var filteredStairways: [Stairway] {
        let stateResult = stateFilteredStairways
        guard let activeTag = activeTagFilter else { return stateResult }

        let taggedIDs = Set(allTagAssignments.filter { $0.tagID == activeTag }.map(\.stairwayID))
        let combined = stateResult.filter { taggedIDs.contains($0.id) }

        if combined.isEmpty {
            // Drop state filter — show all stairways matching the tag
            return store.stairways.filter { $0.hasValidCoordinate && taggedIDs.contains($0.id) }
        }
        return combined
    }

    private func showTagDroppedToastIfNeeded(for tagID: String?) {
        guard let tagID, filter != .all else { return }
        let taggedIDs = Set(allTagAssignments.filter { $0.tagID == tagID }.map(\.stairwayID))
        let stateMatchCount = stateFilteredStairways.filter { taggedIDs.contains($0.id) }.count
        if stateMatchCount == 0 {
            let tagName = allTags.first(where: { $0.id == tagID })?.name ?? tagID
            toastMessage = "No \(filter.rawValue.lowercased()) stairways with \"\(tagName)\" — showing all tagged."
        }
    }

    private func walkRecord(for stairway: Stairway) -> WalkRecord? {
        walkRecords.first { $0.stairwayID == stairway.id }
    }

    // MARK: - Map Legend

    private var mapLegend: some View {
        VStack(alignment: .leading, spacing: 5) {
            legendRow(color: Color.walkedGreen, label: "Walked")
            legendRow(color: Color.brandAmber, label: "Not yet")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .allowsHitTesting(false)
    }

    private func legendRow(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 0.5))
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Progress Card

struct ProgressCard: View {
    let walkedCount: Int
    let totalHeightFt: Double
    let neighborhoodsVisited: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Stats")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.brandAmber)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(walkedCount) stairways")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(totalHeightFt > 0 ? "\(Int(totalHeightFt).formatted()) ft" : "0 ft")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if neighborhoodsVisited > 0 {
                    Text("\(neighborhoodsVisited) 'hoods")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 120)
        .background(.ultraThinMaterial)
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
