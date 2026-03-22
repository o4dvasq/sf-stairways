import SwiftUI
import MapKit
import SwiftData

struct MapTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var walkRecords: [WalkRecord]
    @State private var store = StairwayStore()
    @State private var locationManager = LocationManager()
    @State private var selectedStairway: Stairway?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.76, longitude: -122.44),
            span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
        )
    )
    @State private var filter: StairwayFilter = .all

    enum StairwayFilter: String, CaseIterable {
        case all = "All"
        case walked = "Walked"
        case todo = "To do"
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
                                isSelected: selectedStairway?.id == stairway.id
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
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StairwayFilter.allCases, id: \.self) { f in
                        FilterChip(title: f.rawValue, isActive: filter == f) {
                            withAnimation { filter = f }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .sheet(item: $selectedStairway) { stairway in
            StairwayBottomSheet(
                stairway: stairway,
                walkRecord: walkRecord(for: stairway),
                onToggleWalk: { toggleWalk(for: stairway) }
            )
            .presentationDetents([.height(320), .medium])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .height(320)))
        }
        .onAppear {
            locationManager.requestPermission()
        }
    }

    private var filteredStairways: [Stairway] {
        let valid = store.stairways.filter { $0.hasValidCoordinate }
        switch filter {
        case .all:
            return valid
        case .walked:
            let walkedIDs = Set(walkRecords.filter(\.walked).map(\.stairwayID))
            return valid.filter { walkedIDs.contains($0.id) }
        case .todo:
            let walkedIDs = Set(walkRecords.filter(\.walked).map(\.stairwayID))
            return valid.filter { !walkedIDs.contains($0.id) && !$0.closed }
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

    private func toggleWalk(for stairway: Stairway) {
        if let record = walkRecord(for: stairway) {
            record.toggleWalked()
        } else {
            let record = WalkRecord(stairwayID: stairway.id, walked: true, dateWalked: Date())
            modelContext.insert(record)
        }
        try? modelContext.save()
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
                .background(isActive ? Color.forestGreen : Color(.systemBackground))
                .foregroundStyle(isActive ? .white : .secondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isActive ? Color.clear : Color(.separator), lineWidth: 0.5)
                )
        }
    }
}
