import SwiftUI
import SwiftData

struct ListTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var walkRecords: [WalkRecord]
    @State private var store = StairwayStore()
    @State private var searchText = ""
    @State private var listFilter: ListFilter = .all

    enum ListFilter: String, CaseIterable {
        case all = "All"
        case walked = "Walked"
        case todo = "To do"
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredGroups, id: \.name) { group in
                    Section {
                        ForEach(group.stairways) { stairway in
                            NavigationLink(destination: StairwayDetail(stairway: stairway)) {
                                StairwayRow(
                                    stairway: stairway,
                                    walkRecord: walkRecord(for: stairway)
                                )
                            }
                        }
                    } header: {
                        Text(group.name)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Stairways")
            .searchable(text: $searchText, prompt: "Search stairways...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Filter", selection: $listFilter) {
                        ForEach(ListFilter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
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
        case .todo:
            filtered = searchResults.filter { !walkedIDs.contains($0.id) }
        }

        let grouped = Dictionary(grouping: filtered, by: \.neighborhood)
        return grouped
            .map { (name: $0.key, stairways: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.name < $1.name }
    }

    private func walkRecord(for stairway: Stairway) -> WalkRecord? {
        walkRecords.first { $0.stairwayID == stairway.id }
    }
}
