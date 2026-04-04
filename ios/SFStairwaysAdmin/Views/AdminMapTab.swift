import SwiftUI
import SwiftData
import MapKit

// MARK: - Map Filter

enum AdminMapFilter: String, CaseIterable {
    case all = "All"
    case hasIssues = "Has Issues"
    case hasOverrides = "Has Overrides"
    case unwalked = "Unwalked"
    case walked = "Walked"
}

// MARK: - Admin Map Tab

struct AdminMapTab: View {
    @Query private var walkRecords: [WalkRecord]
    @Query private var overrides: [StairwayOverride]
    @Query private var deletions: [StairwayDeletion]

    @State private var store = StairwayStore()
    @State private var selectedStairway: Stairway?
    @State private var activeFilter: AdminMapFilter = .all
    @State private var showTagManager = false
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.76, longitude: -122.44),
            span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
        )
    )
    @State private var currentSpan: Double = 0.06

    // MARK: - Derived lookups

    private var walkedIDs: Set<String> {
        Set(walkRecords.filter(\.walked).map(\.stairwayID))
    }

    private var overrideByID: [String: StairwayOverride] {
        var dict: [String: StairwayOverride] = [:]
        for o in overrides { dict[o.stairwayID] = o }
        return dict
    }

    private var overrideIDs: Set<String> {
        Set(overrides.map(\.stairwayID))
    }

    // MARK: - Pin state helpers

    private func hasIssues(_ stairway: Stairway) -> Bool {
        let hasHeight = stairway.heightFt != nil || overrideByID[stairway.id]?.verifiedHeightFt != nil
        return !hasHeight || !stairway.hasValidCoordinate
    }

    private func pinColor(for stairway: Stairway) -> Color {
        if hasIssues(stairway) { return Color.red.opacity(0.8) }
        if overrideIDs.contains(stairway.id) { return Color.blue.opacity(0.8) }
        if walkedIDs.contains(stairway.id) { return Color.walkedGreen }
        return Color.brandAmber
    }

    // MARK: - Filtered stairways

    private var filteredStairways: [Stairway] {
        switch activeFilter {
        case .all:
            return store.stairways
        case .hasIssues:
            return store.stairways.filter { hasIssues($0) }
        case .hasOverrides:
            return store.stairways.filter { overrideIDs.contains($0.id) }
        case .unwalked:
            return store.stairways.filter { !walkedIDs.contains($0.id) }
        case .walked:
            return store.stairways.filter { walkedIDs.contains($0.id) }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                ForEach(filteredStairways) { stairway in
                    if let coordinate = stairway.coordinate {
                        Annotation("", coordinate: coordinate) {
                            AdminMapPin(
                                stairway: stairway,
                                color: pinColor(for: stairway),
                                isSelected: selectedStairway?.id == stairway.id,
                                showLabel: currentSpan < 0.02
                            )
                            .onTapGesture {
                                selectedStairway = stairway
                            }
                        }
                    }
                }
                UserAnnotation()
            }
            .mapStyle(.standard)
            .mapControls {
                MapUserLocationButton()
            }
            .onMapCameraChange { context in
                currentSpan = context.region.span.latitudeDelta
            }
            .navigationTitle("Admin Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showTagManager = true
                    } label: {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(Color.brandAmber)
                    }
                    .accessibilityLabel("Tag Manager")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(AdminMapFilter.allCases, id: \.self) { filter in
                            Button {
                                activeFilter = filter
                            } label: {
                                if activeFilter == filter {
                                    Label(filter.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(filter.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .symbolVariant(activeFilter == .all ? .none : .fill)
                    }
                    .accessibilityLabel("Filter pins")
                }
            }
            .sheet(item: $selectedStairway) { stairway in
                NavigationStack {
                    AdminDetailView(stairway: stairway)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { selectedStairway = nil }
                            }
                        }
                }
            }
            .sheet(isPresented: $showTagManager) {
                AdminTagManager()
            }
        }
        .onAppear {
            store.applyDeletions(deletions.map(\.stairwayID))
        }
        .onChange(of: deletions) { _, d in
            store.applyDeletions(d.map(\.stairwayID))
        }
    }
}

// MARK: - Admin Map Pin

private struct AdminMapPin: View {
    let stairway: Stairway
    let color: Color
    let isSelected: Bool
    let showLabel: Bool

    private var pinSize: CGFloat { isSelected ? 20 : 14 }

    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: pinSize, height: pinSize)

            if showLabel {
                Text(stairway.displayName)
                    .font(.system(.caption2, design: .rounded))
                    .opacity(0.6)
                    .fixedSize()
            }
        }
        .frame(width: max(44, pinSize), height: max(44, pinSize))
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
