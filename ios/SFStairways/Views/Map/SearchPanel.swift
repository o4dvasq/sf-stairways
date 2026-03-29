import SwiftUI
import MapKit
import CoreLocation
import SwiftData

struct SearchPanel: View {
    let store: StairwayStore
    let walkRecords: [WalkRecord]
    let userLocation: CLLocation?
    let onSelectStairway: (Stairway) -> Void
    let onSelectNeighborhood: (String) -> Void
    var onDismiss: () -> Void = {}
    var isTabMode: Bool = false

    @Query private var allTags: [StairwayTag]
    @Query private var allAssignments: [TagAssignment]

    @State private var query: String = ""
    @State private var activeTab: SearchTab = .name
    @State private var selectedTag: StairwayTag? = nil
    @FocusState private var isSearchFocused: Bool

    enum SearchTab: String, CaseIterable {
        case name = "Name"
        case street = "Street"
        case neighborhood = "Neighborhood"
        case tags = "Tags"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search stairways...", text: $query)
                        .focused($isSearchFocused)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Tab pills
                HStack(spacing: 8) {
                    ForEach(SearchTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation { activeTab = tab }
                        } label: {
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(activeTab == tab ? Color.forestGreen : Color(.systemBackground))
                                .foregroundStyle(activeTab == tab ? .white : .secondary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(activeTab == tab ? Color.clear : Color(.separator), lineWidth: 0.5)
                                )
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Divider()

                // Results
                if activeTab == .neighborhood {
                    neighborhoodResults
                } else if activeTab == .tags {
                    tagsResults
                } else {
                    stairwayResults
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isTabMode {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel", action: onDismiss)
                    }
                }
            }
        }
        .onAppear {
            if !isTabMode { isSearchFocused = true }
        }
        .onChange(of: activeTab) { _, _ in
            selectedTag = nil
            query = ""
        }
    }

    // MARK: - Stairway Results (Name / Street tabs)

    private var stairwayResults: some View {
        let results = query.isEmpty ? [] : store.searchByName(query)
        return List(results) { stairway in
            Button {
                onSelectStairway(stairway)
            } label: {
                StairwaySearchRow(
                    stairway: stairway,
                    userLocation: userLocation
                )
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .overlay {
            if query.isEmpty {
                ContentUnavailableView(
                    "Search stairways",
                    systemImage: "magnifyingglass",
                    description: Text("Type a name to find stairways")
                )
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    // MARK: - Neighborhood Results

    private var neighborhoodResults: some View {
        let groups = store.searchByNeighborhood(query)
        return List(groups, id: \.name) { group in
            Button {
                onSelectNeighborhood(group.name)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("\(group.stairways.count) stairways")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .overlay {
            if groups.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    // MARK: - Tags Results

    @ViewBuilder
    private var tagsResults: some View {
        if let tag = selectedTag {
            tagStairwayList(for: tag)
        } else {
            tagPillGrid
        }
    }

    private var tagPillGrid: some View {
        let tagsWithAssignments = allTags
            .filter { tag in allAssignments.contains(where: { $0.tagID == tag.id }) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }

        return ScrollView {
            if tagsWithAssignments.isEmpty {
                ContentUnavailableView(
                    "No tags yet",
                    systemImage: "tag",
                    description: Text("Tag stairways from their detail view")
                )
                .padding(.top, 40)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(tagsWithAssignments) { tag in
                        let count = allAssignments.filter { $0.tagID == tag.id }.count
                        Button {
                            selectedTag = tag
                        } label: {
                            VStack(spacing: 2) {
                                Text(tag.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .foregroundStyle(.primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }

    private func tagStairwayList(for tag: StairwayTag) -> some View {
        let taggedIDs = Set(allAssignments.filter { $0.tagID == tag.id }.map(\.stairwayID))
        let stairways = store.stairways
            .filter { taggedIDs.contains($0.id) }
            .sorted { $0.name < $1.name }

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                selectedTag = nil
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text(tag.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(Color.forestGreen)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            List(stairways) { stairway in
                Button {
                    onSelectStairway(stairway)
                } label: {
                    StairwaySearchRow(stairway: stairway, userLocation: userLocation)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .overlay {
                if stairways.isEmpty {
                    ContentUnavailableView("No stairways tagged", systemImage: "tag")
                }
            }
        }
    }
}

// MARK: - Stairway Search Row

private struct StairwaySearchRow: View {
    let stairway: Stairway
    let userLocation: CLLocation?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(stairway.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(stairway.neighborhood)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let dist = distanceString {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(dist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var distanceString: String? {
        guard let location = userLocation else { return nil }
        let dist = stairway.distance(from: location)
        if dist < 1000 {
            return "\(Int(dist)) m"
        } else {
            return String(format: "%.1f km", dist / 1000)
        }
    }
}
