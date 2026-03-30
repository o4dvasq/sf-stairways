import SwiftUI
import SwiftData

struct ListTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var walkRecords: [WalkRecord]
    @Query private var overrides: [StairwayOverride]
    @Query private var deletions: [StairwayDeletion]
    @State private var store = StairwayStore()
    @State private var locationManager = LocationManager()
    @State private var searchText = ""
    @State private var listFilter: ListFilter = .all
    @State private var selectedStairway: Stairway?

    enum ListFilter: String, CaseIterable {
        case all = "All"
        case walked = "Walked"
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredGroups, id: \.name) { group in
                    Section {
                        ForEach(group.stairways) { stairway in
                            Button {
                                selectedStairway = stairway
                            } label: {
                                StairwayRow(
                                    stairway: stairway,
                                    walkRecord: walkRecord(for: stairway),
                                    override: override(for: stairway)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        NavigationLink(value: group.name) {
                            HStack {
                                Text(group.name)
                                    .font(.system(.subheadline, design: .rounded))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Stairways")
            .searchable(text: $searchText, prompt: "Search stairways...")
            .navigationDestination(for: String.self) { name in
                NeighborhoodDetail(neighborhoodName: name)
            }
            .sheet(item: $selectedStairway) { stairway in
                StairwayBottomSheet(stairway: stairway, locationManager: locationManager)
                    .presentationDetents([.height(390), .large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                store.applyDeletions(deletions.map(\.stairwayID))
            }
            .onChange(of: deletions) { _, d in
                store.applyDeletions(d.map(\.stairwayID))
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Filter", selection: $listFilter) {
                        ForEach(ListFilter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
            }
        }
    }

    private var filteredGroups: [(name: String, stairways: [Stairway])] {
        let walkedIDs = Set(walkRecords.filter(\.walked).map(\.stairwayID))
        let searchResults = store.search(searchText)

        let filtered: [Stairway]
        switch listFilter {
        case .all:
            filtered = searchResults
        case .walked:
            filtered = searchResults.filter { walkedIDs.contains($0.id) }
        }

        let grouped = Dictionary(grouping: filtered, by: \.neighborhood)
        return grouped
            .map { (name: $0.key, stairways: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.name < $1.name }
    }

    private func walkRecord(for stairway: Stairway) -> WalkRecord? {
        walkRecords.first { $0.stairwayID == stairway.id }
    }

    private func override(for stairway: Stairway) -> StairwayOverride? {
        overrides.first { $0.stairwayID == stairway.id }
    }
}
