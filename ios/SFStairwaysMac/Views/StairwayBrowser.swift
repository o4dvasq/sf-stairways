import SwiftUI
import SwiftData

// MARK: - Supporting Types

enum WalkFilter: String, CaseIterable {
    case all = "All"
    case walked = "Walked"
    case unwalked = "Unwalked"
}

/// Flattened row type for the stairway Table — combines catalog, walk, and override data.
struct StairwayRow: Identifiable {
    let stairway: Stairway
    let walkRecord: WalkRecord?
    let override: StairwayOverride?
    let photoCount: Int

    var id: String { stairway.id }
    var name: String { stairway.name }
    var neighborhood: String { stairway.neighborhood }
    var walked: Bool { walkRecord?.walked ?? false }

    // Curator-verified height takes precedence over catalog height.
    var heightFt: Double? { override?.verifiedHeightFt ?? stairway.heightFt }

    // Curator-verified step count (HealthKit steps are in elevationGain context; this is curated).
    var verifiedStepCount: Int? { override?.verifiedStepCount }

    // HealthKit steps recorded during the walk.
    var hkStepCount: Int? { walkRecord?.stepCount }

    var elevationGain: Double? { walkRecord?.elevationGain }
    var dateWalked: Date? { walkRecord?.dateWalked }
    var hasNotes: Bool {
        guard let notes = walkRecord?.notes, !notes.isEmpty else { return false }
        return true
    }
    var hasCuratorDescription: Bool {
        guard let desc = override?.stairwayDescription, !desc.isEmpty else { return false }
        return true
    }
    var notesPreview: String? {
        guard let notes = walkRecord?.notes, !notes.isEmpty else { return nil }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(30)) + (trimmed.count > 30 ? "…" : "")
    }
}

// MARK: - Main Browser

struct StairwayBrowser: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var walkRecords: [WalkRecord]
    @Query private var overrides: [StairwayOverride]
    @Query private var tags: [StairwayTag]
    @Query private var tagAssignments: [TagAssignment]

    @State private var stairwayStore = StairwayStore()
    @State private var selectedNeighborhood: String? = nil
    @State private var filter: WalkFilter = .all
    @State private var searchText: String = ""
    @State private var selectedIDs: Set<String> = []
    @State private var showHygiene = false
    @State private var showBulkOps = false
    @State private var sortOrder: [KeyPathComparator<StairwayRow>] = [
        .init(\.name, order: .forward)
    ]

    // MARK: - Derived Data

    private var walkedRecordByID: [String: WalkRecord] {
        var dict: [String: WalkRecord] = [:]
        for record in walkRecords where record.walked {
            dict[record.stairwayID] = record
        }
        return dict
    }

    private var overrideByID: [String: StairwayOverride] {
        var dict: [String: StairwayOverride] = [:]
        for o in overrides { dict[o.stairwayID] = o }
        return dict
    }

    private var photoCountByID: [String: Int] {
        var dict: [String: Int] = [:]
        for record in walkRecords {
            let count = record.photoArray.count
            if count > 0 { dict[record.stairwayID] = count }
        }
        return dict
    }

    private var filteredStairways: [Stairway] {
        var result = stairwayStore.stairways

        if let hood = selectedNeighborhood {
            result = result.filter { $0.neighborhood == hood }
        }

        switch filter {
        case .all:
            break
        case .walked:
            let ids = Set(walkedRecordByID.keys)
            result = result.filter { ids.contains($0.id) }
        case .unwalked:
            let ids = Set(walkedRecordByID.keys)
            result = result.filter { !ids.contains($0.id) }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) || $0.neighborhood.lowercased().contains(q)
            }
        }

        return result
    }

    private var rows: [StairwayRow] {
        filteredStairways.map { stairway in
            StairwayRow(
                stairway: stairway,
                walkRecord: walkedRecordByID[stairway.id],
                override: overrideByID[stairway.id],
                photoCount: photoCountByID[stairway.id] ?? 0
            )
        }
    }

    private var sortedRows: [StairwayRow] {
        rows.sorted(using: sortOrder)
    }

    private var neighborhoodCounts: [(name: String, total: Int, walked: Int)] {
        let walkedIDs = Set(walkedRecordByID.keys)
        return stairwayStore.neighborhoodGroups.map { group in
            let walked = group.stairways.filter { walkedIDs.contains($0.id) }.count
            return (name: group.name, total: group.stairways.count, walked: walked)
        }
    }

    // The single stairway to show in the detail column (only when exactly one row is selected).
    private var detailRow: StairwayRow? {
        guard selectedIDs.count == 1, let id = selectedIDs.first else { return nil }
        return rows.first { $0.id == id }
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } content: {
            stairwayTable
                .navigationSplitViewColumnWidth(min: 400, ideal: 550)
        } detail: {
            detailColumn
        }
        .searchable(text: $searchText, prompt: "Search stairways")
        .toolbar { toolbarItems }
        .sheet(isPresented: $showHygiene) {
            DataHygieneView(
                stairways: stairwayStore.stairways,
                walkRecords: walkRecords,
                overrides: overrides,
                walkPhotos: []
            )
        }
        .sheet(isPresented: $showBulkOps) {
            let selected = stairwayStore.stairways.filter { selectedIDs.contains($0.id) }
            BulkOperationsSheet(
                selectedStairways: selected,
                allRows: rows,
                tags: tags,
                tagAssignments: tagAssignments
            )
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        List(selection: $selectedNeighborhood) {
            let walkedCount = walkedRecordByID.count
            let totalCount = stairwayStore.stairways.count

            Label {
                HStack {
                    Text("All Stairways")
                    Spacer()
                    Text("\(walkedCount)/\(totalCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "map")
            }
            .tag(nil as String?)

            Section("Neighborhoods") {
                ForEach(neighborhoodCounts, id: \.name) { item in
                    HStack {
                        Text(item.name)
                            .font(.system(size: 12))
                        Spacer()
                        Text("\(item.walked)/\(item.total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(item.name as String?)
                }
            }
        }
        .navigationTitle("SF Stairways")
    }

    // MARK: - Stairway Table

    @ViewBuilder
    private var stairwayTable: some View {
        Table(sortedRows, selection: $selectedIDs, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { row in
                HStack(spacing: 6) {
                    if row.walked {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.walkedGreen)
                            .font(.system(size: 11))
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(Color.secondary)
                            .font(.system(size: 11))
                    }
                    Text(row.name)
                        .foregroundStyle(row.walked ? Color.primary : Color.secondary)
                }
            }
            .width(min: 160)

            TableColumn("Height") { row in
                if let h = row.heightFt {
                    Text("\(Int(h)) ft")
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .width(65)

            TableColumn("Steps") { row in
                if let s = row.verifiedStepCount {
                    Text("\(s)")
                } else if let s = row.hkStepCount {
                    Text("\(s)").foregroundStyle(.secondary)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .width(60)

            TableColumn("Elev. Gain") { row in
                if let e = row.elevationGain {
                    Text("\(Int(e)) ft")
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .width(75)

            TableColumn("Photos") { row in
                if row.photoCount > 0 {
                    Label("\(row.photoCount)", systemImage: "photo")
                        .font(.system(size: 11))
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .width(60)

            TableColumn("Notes") { row in
                if row.hasNotes && row.hasCuratorDescription {
                    Label {
                        Text(row.notesPreview ?? "")
                            .font(.system(size: 11))
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.walkedGreen)
                    }
                } else if let preview = row.notesPreview {
                    Label {
                        Text(preview)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.brandAmber)
                    }
                } else if row.hasCuratorDescription {
                    Label {
                        Text("Curated")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.walkedGreen)
                    }
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .width(150)

            TableColumn("Date Walked") { row in
                if let date = row.dateWalked {
                    Text(date, style: .date)
                        .font(.system(size: 11))
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .width(95)
        }
        .navigationTitle(selectedNeighborhood ?? "All Stairways")
        .navigationSubtitle("\(sortedRows.count) stairways · \(sortedRows.filter(\.walked).count) walked")
    }

    // MARK: - Detail Column

    @ViewBuilder
    private var detailColumn: some View {
        if let row = detailRow {
            StairwayDetailPanel(
                stairway: row.stairway,
                walkRecord: row.walkRecord,
                override: row.override,
                tags: tags,
                tagAssignments: tagAssignments
            )
        } else if selectedIDs.count > 1 {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("\(selectedIDs.count) stairways selected")
                    .font(.title3)
                Button("Bulk Actions…") { showBulkOps = true }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "Select a Stairway",
                systemImage: "figure.hiking",
                description: Text("Choose a stairway from the list to view details.")
            )
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Picker("Filter", selection: $filter) {
                ForEach(WalkFilter.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }

        ToolbarItem {
            Button {
                showHygiene = true
            } label: {
                Label("Data Hygiene", systemImage: "exclamationmark.triangle")
            }
        }

        if !selectedIDs.isEmpty {
            ToolbarItem {
                Button {
                    showBulkOps = true
                } label: {
                    Label("Bulk Actions (\(selectedIDs.count))", systemImage: "checklist")
                }
            }
        }
    }
}
