import SwiftUI
import MapKit
import SwiftData

struct NeighborhoodDetail: View {
    let neighborhoodName: String

    @Environment(NeighborhoodStore.self) private var neighborhoodStore
    @Environment(\.modelContext) private var modelContext
    @Query private var allWalkRecords: [WalkRecord]
    @State private var store = StairwayStore()
    @State private var locationManager = LocationManager()
    @State private var selectedStairway: Stairway?
    @State private var selectedPhoto: WalkPhoto?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                progressSection
                mapSection
                if !neighborhoodPhotos.isEmpty {
                    photoSection
                }
                stairwayListSection
            }
            .padding()
        }
        .navigationTitle(neighborhoodName)
        .navigationBarTitleDisplayMode(.large)
        .onAppear { locationManager.requestPermission() }
        .sheet(item: $selectedStairway) { stairway in
            StairwayBottomSheet(stairway: stairway, locationManager: locationManager)
                .presentationDetents([.height(390), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoViewer(photo: photo, onDelete: {
                modelContext.delete(photo)
            })
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        let walkedCount = walkedStairways.count
        let total = neighborhoodStairways.count
        let fraction = total > 0 ? Double(walkedCount) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(walkedCount) of \(total) walked")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            ProgressView(value: fraction)
                .tint(Color.brandOrange)
        }
    }

    // MARK: - Embedded Map

    private var mapSection: some View {
        Map(initialPosition: .region(mapRegion)) {
            if let neighborhood = neighborhoodStore.neighborhood(named: neighborhoodName) {
                ForEach(Array(neighborhood.polygons.enumerated()), id: \.offset) { _, ring in
                    MapPolygon(coordinates: ring)
                        .foregroundStyle(neighborhood.color.opacity(0.30))
                        .stroke(neighborhood.color.opacity(0.60), lineWidth: 1)
                }
            }

            ForEach(neighborhoodStairways.filter(\.hasValidCoordinate)) { stairway in
                if let coord = stairway.coordinate {
                    Annotation("", coordinate: coord, anchor: .bottom) {
                        StairwayAnnotation(
                            stairway: stairway,
                            walkRecord: walkRecord(for: stairway)
                        )
                        .onTapGesture {
                            selectedStairway = stairway
                        }
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls { }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Photos

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photos")
                .font(.system(.subheadline, design: .rounded, weight: .medium))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(neighborhoodPhotos) { photo in
                        Button {
                            selectedPhoto = photo
                        } label: {
                            Group {
                                if let thumbnail = photo.thumbnailImage {
                                    Image(uiImage: thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Color(.systemGray5)
                                }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Stairway List

    private var stairwayListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Stairways")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .padding(.bottom, 10)

            if neighborhoodStairways.isEmpty {
                Text("No stairways in this neighborhood")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(sortedStairways.enumerated()), id: \.element.id) { index, stairway in
                    Button {
                        selectedStairway = stairway
                    } label: {
                        stairwayRow(stairway)
                    }
                    .buttonStyle(.plain)

                    if index < sortedStairways.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private func stairwayRow(_ stairway: Stairway) -> some View {
        let walked = walkRecord(for: stairway)?.walked ?? false

        return HStack(spacing: 12) {
            Image(systemName: walked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(walked ? Color.walkedGreen : Color.secondary)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                Text(stairway.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let height = stairway.heightFt {
                    Text("\(Int(height)) ft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Computed Properties

    private var neighborhoodStairways: [Stairway] {
        store.stairways(in: neighborhoodName)
    }

    private var walkedStairways: [Stairway] {
        let walkedIDs = Set(allWalkRecords.filter(\.walked).map(\.stairwayID))
        return neighborhoodStairways.filter { walkedIDs.contains($0.id) }
    }

    private var sortedStairways: [Stairway] {
        let walkedIDs = Set(allWalkRecords.filter(\.walked).map(\.stairwayID))
        let walked = neighborhoodStairways
            .filter { walkedIDs.contains($0.id) }
            .sorted {
                let dateA = walkRecord(for: $0)?.dateWalked ?? .distantPast
                let dateB = walkRecord(for: $1)?.dateWalked ?? .distantPast
                return dateA > dateB
            }
        let unwalked = neighborhoodStairways
            .filter { !walkedIDs.contains($0.id) }
            .sorted { $0.name < $1.name }
        return walked + unwalked
    }

    private var neighborhoodPhotos: [WalkPhoto] {
        let stairwayIDs = Set(neighborhoodStairways.map(\.id))
        return allWalkRecords
            .filter { stairwayIDs.contains($0.stairwayID) }
            .flatMap { $0.photoArray }
            .sorted { $0.takenAt > $1.takenAt }
    }

    private var mapRegion: MKCoordinateRegion {
        if let neighborhood = neighborhoodStore.neighborhood(named: neighborhoodName) {
            let allCoords = neighborhood.polygons.flatMap { $0 }
            if !allCoords.isEmpty {
                let minLat = allCoords.map(\.latitude).min()!
                let maxLat = allCoords.map(\.latitude).max()!
                let minLng = allCoords.map(\.longitude).min()!
                let maxLng = allCoords.map(\.longitude).max()!
                return MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: (minLat + maxLat) / 2,
                        longitude: (minLng + maxLng) / 2
                    ),
                    span: MKCoordinateSpan(
                        latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
                        longitudeDelta: max((maxLng - minLng) * 1.4, 0.01)
                    )
                )
            }
        }
        return store.region(for: neighborhoodName) ?? MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.76, longitude: -122.44),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    }

    private func walkRecord(for stairway: Stairway) -> WalkRecord? {
        allWalkRecords.first { $0.stairwayID == stairway.id }
    }
}
