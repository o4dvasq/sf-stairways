import SwiftUI
import SwiftData

// MARK: - Filter / Sort Types

enum AdminFilter: String, CaseIterable {
    case all = "All"
    case walked = "Walked"
    case unwalked = "Unwalked"
    case hasOverride = "Has Override"
    case hasIssues = "Has Issues"
}

enum AdminSortOrder: String, CaseIterable {
    case name = "Name"
    case neighborhood = "Neighborhood"
    case dateWalked = "Date Walked"
}

// MARK: - Admin Browser

struct AdminBrowser: View {
    @Query private var walkRecords: [WalkRecord]
    @Query private var overrides: [StairwayOverride]
    @Query private var tagAssignments: [TagAssignment]
    @Query private var deletions: [StairwayDeletion]

    @State private var store = StairwayStore()
    @State private var searchText = ""
    @State private var activeFilter: AdminFilter = .all
    @State private var sortOrder: AdminSortOrder = .name
    @State private var showTagManager = false
    @State private var showRemovedStairways = false

    // MARK: - Derived lookups

    private var walkedIDs: Set<String> {
        Set(walkRecords.filter(\.walked).map(\.stairwayID))
    }

    private var overrideByID: [String: StairwayOverride] {
        var dict: [String: StairwayOverride] = [:]
        for o in overrides { dict[o.stairwayID] = o }
        return dict
    }

    private var tagCountByID: [String: Int] {
        var dict: [String: Int] = [:]
        for a in tagAssignments {
            dict[a.stairwayID, default: 0] += 1
        }
        return dict
    }

    private var walkedDateByID: [String: Date] {
        var dict: [String: Date] = [:]
        for r in walkRecords where r.walked {
            if let d = r.dateWalked { dict[r.stairwayID] = d }
        }
        return dict
    }

    // MARK: - Filtered + sorted stairways

    private var filteredStairways: [Stairway] {
        var result = store.stairways

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) || $0.neighborhood.lowercased().contains(q)
            }
        }

        switch activeFilter {
        case .all:
            break
        case .walked:
            result = result.filter { walkedIDs.contains($0.id) }
        case .unwalked:
            result = result.filter { !walkedIDs.contains($0.id) }
        case .hasOverride:
            let overrideIDs = Set(overrides.map(\.stairwayID))
            result = result.filter { overrideIDs.contains($0.id) }
        case .hasIssues:
            result = result.filter { stairway in
                let hasHeight = stairway.heightFt != nil || overrideByID[stairway.id]?.verifiedHeightFt != nil
                return !hasHeight || !stairway.hasValidCoordinate
            }
        }

        switch sortOrder {
        case .name:
            result.sort { $0.name < $1.name }
        case .neighborhood:
            result.sort { $0.neighborhood == $1.neighborhood ? $0.name < $1.name : $0.neighborhood < $1.neighborhood }
        case .dateWalked:
            result.sort {
                let a = walkedDateByID[$0.id]
                let b = walkedDateByID[$1.id]
                switch (a, b) {
                case (nil, nil): return $0.name < $1.name
                case (nil, _): return false
                case (_, nil): return true
                case let (da?, db?): return da > db
                }
            }
        }

        return result
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChips
                stairwayList
            }
            .navigationTitle("Admin")
            .searchable(text: $searchText, prompt: "Search stairways")
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
                    Button {
                        showRemovedStairways = true
                    } label: {
                        Image(systemName: "archivebox")
                    }
                    .accessibilityLabel("Removed Stairways")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(AdminSortOrder.allCases, id: \.self) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                if sortOrder == order {
                                    Label(order.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(order.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Sort order")
                }
            }
            .sheet(isPresented: $showTagManager) {
                AdminTagManager()
            }
            .sheet(isPresented: $showRemovedStairways) {
                RemovedStairwaysView(store: store)
            }
        }
        .onAppear {
            store.applyDeletions(deletions.map(\.stairwayID))
        }
        .onChange(of: deletions) { _, d in
            store.applyDeletions(d.map(\.stairwayID))
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AdminFilter.allCases, id: \.self) { filter in
                    Button {
                        activeFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(activeFilter == filter ? Color.forestGreen : Color(.systemGray5))
                            .foregroundStyle(activeFilter == filter ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Stairway List

    private var stairwayList: some View {
        List {
            ForEach(filteredStairways) { stairway in
                NavigationLink {
                    AdminDetailView(stairway: stairway)
                } label: {
                    AdminStairwayRow(
                        stairway: stairway,
                        isWalked: walkedIDs.contains(stairway.id),
                        hasOverride: overrideByID[stairway.id] != nil,
                        tagCount: tagCountByID[stairway.id] ?? 0
                    )
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if filteredStairways.isEmpty {
                ContentUnavailableView(
                    "No Stairways",
                    systemImage: "figure.hiking",
                    description: Text("No stairways match the current filter.")
                )
            }
        }
    }
}

// MARK: - Admin Stairway Row

private struct AdminStairwayRow: View {
    let stairway: Stairway
    let isWalked: Bool
    let hasOverride: Bool
    let tagCount: Int

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stairway.name)
                    .font(.body)
                Text(stairway.neighborhood)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                if isWalked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.walkedGreen)
                        .font(.system(size: 14))
                }
                if hasOverride {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(Color.brandAmber)
                        .font(.system(size: 14))
                }
                if tagCount > 0 {
                    Label("\(tagCount)", systemImage: "tag.fill")
                        .font(.caption)
                        .foregroundStyle(Color.brandAmber)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brandAmber.opacity(0.15), in: Capsule())
                }
            }
        }
        .padding(.vertical, 2)
    }
}
