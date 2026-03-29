import SwiftUI
import SwiftData

struct ProgressTab: View {
    @Environment(SyncStatusManager.self) private var syncManager
    @Query private var walkRecords: [WalkRecord]
    @Query private var overrides: [StairwayOverride]
    @State private var store = StairwayStore()
    @State private var showSyncDetails = false
    @State private var expandedNeighborhoods: Set<String> = []

    private struct NeighborhoodData: Identifiable {
        var id: String { name }
        let name: String
        let walked: Int
        let total: Int
        let walks: [WalkItem]

        struct WalkItem: Identifiable {
            var id: String { stairwayID }
            let stairwayID: String
            let name: String
            let stepCount: Int?
            let date: Date?
        }
    }

    private var walkedRecords: [WalkRecord] {
        walkRecords.filter(\.walked)
    }

    private var totalStairways: Int {
        store.stairways.count
    }

    private var walkedCount: Int {
        walkedRecords.count
    }

    private var completionFraction: Double {
        guard totalStairways > 0 else { return 0 }
        return Double(walkedCount) / Double(totalStairways)
    }

    private var totalHeightClimbed: Int {
        let walkedIDs = Set(walkedRecords.map(\.stairwayID))
        return store.stairways
            .filter { walkedIDs.contains($0.id) }
            .compactMap { stairway in
                store.resolvedHeightFt(for: stairway, override: override(for: stairway))
            }
            .reduce(0) { $0 + Int($1) }
    }

    private func override(for stairway: Stairway) -> StairwayOverride? {
        overrides.first { $0.stairwayID == stairway.id }
    }

    private var totalSteps: Int {
        walkedRecords.compactMap(\.stepCount).reduce(0, +)
    }

    private var neighborhoodsVisited: Int {
        let walkedIDs = Set(walkedRecords.map(\.stairwayID))
        let neighborhoods = Set(
            store.stairways.filter { walkedIDs.contains($0.id) }.map(\.neighborhood)
        )
        return neighborhoods.count
    }

    private var totalNeighborhoods: Int {
        Set(store.stairways.map(\.neighborhood)).count
    }

    private var walkDays: Int {
        let calendar = Calendar.current
        let days = Set(
            walkedRecords.compactMap(\.dateWalked).map {
                calendar.startOfDay(for: $0)
            }
        )
        return days.count
    }

    private var neighborhoodData: [NeighborhoodData] {
        let walkedIDs = Set(walkedRecords.map(\.stairwayID))
        let grouped = Dictionary(grouping: store.stairways, by: \.neighborhood)

        return grouped
            .compactMap { neighborhood, stairways -> NeighborhoodData? in
                let walkedStairways = stairways.filter { walkedIDs.contains($0.id) }
                guard !walkedStairways.isEmpty else { return nil }

                let walkItems = walkedStairways.compactMap { stairway -> NeighborhoodData.WalkItem? in
                    guard let record = walkedRecords.first(where: { $0.stairwayID == stairway.id }) else { return nil }
                    let steps = override(for: stairway)?.verifiedStepCount ?? record.stepCount
                    return NeighborhoodData.WalkItem(
                        stairwayID: stairway.id,
                        name: stairway.name,
                        stepCount: steps,
                        date: record.dateWalked
                    )
                }
                .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

                return NeighborhoodData(
                    name: neighborhood,
                    walked: walkedStairways.count,
                    total: stairways.count,
                    walks: walkItems
                )
            }
            .sorted { Double($0.walked) / Double($0.total) > Double($1.walked) / Double($1.total) }
    }

    private var recentWalks: [(record: WalkRecord, stairway: Stairway?)] {
        walkedRecords
            .sorted { ($0.dateWalked ?? .distantPast) > ($1.dateWalked ?? .distantPast) }
            .prefix(5)
            .map { record in
                (record: record, stairway: store.stairway(for: record.stairwayID))
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    completionRing
                    statsGrid
                    neighborhoodSection
                    recentWalksSection
                }
                .padding(16)
            }
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSyncDetails = true
                    } label: {
                        Image(systemName: syncIconName)
                            .foregroundStyle(syncIconColor)
                    }
                    .accessibilityLabel("iCloud sync status")
                }
            }
            .sheet(isPresented: $showSyncDetails) {
                SyncStatusSheet(manager: syncManager)
                    .presentationDetents([.fraction(0.3)])
            }
        }
    }

    private var syncIconName: String {
        switch syncManager.state {
        case .unknown:              return "cloud"
        case .syncing:              return "arrow.clockwise.icloud"
        case .synced:               return "checkmark.icloud"
        case .unavailable:          return "icloud.slash"
        case .error:                return "exclamationmark.icloud"
        }
    }

    private var syncIconColor: Color {
        switch syncManager.state {
        case .unknown:              return .secondary
        case .syncing:              return .blue
        case .synced:               return Color.walkedGreen
        case .unavailable, .error:  return .red
        }
    }

    // MARK: - Completion Ring

    private var completionRing: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 10)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: completionFraction)
                    .stroke(
                        Color.walkedGreen,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: completionFraction)

                VStack(spacing: 0) {
                    Text("\(walkedCount)")
                        .font(.system(size: 36, weight: .medium))
                    Text("of \(totalStairways)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("\(Int(completionFraction * 100))% complete")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            StatCard(label: "Total height climbed", value: "\(totalHeightClimbed) ft")
            StatCard(label: "Total steps", value: totalSteps > 0 ? "\(totalSteps)" : "—")
            StatCard(label: "Neighborhoods", value: "\(neighborhoodsVisited) / \(totalNeighborhoods)")
            StatCard(label: "Walk days", value: "\(walkDays)")
        }
    }

    // MARK: - Neighborhood Breakdown

    private var neighborhoodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By neighborhood")
                .font(.subheadline)
                .fontWeight(.medium)

            if neighborhoodData.isEmpty {
                Text("Walk some stairways to see neighborhood progress!")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 12)
            } else {
                ForEach(neighborhoodData) { item in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedNeighborhoods.contains(item.name) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedNeighborhoods.insert(item.name)
                                } else {
                                    expandedNeighborhoods.remove(item.name)
                                }
                            }
                        )
                    ) {
                        VStack(spacing: 6) {
                            ForEach(item.walks) { walk in
                                HStack {
                                    Text(walk.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if let steps = walk.stepCount {
                                        Text("\(steps)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("—")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let date = walk.date {
                                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 44, alignment: .trailing)
                                    }
                                }
                                .padding(.leading, 8)
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        VStack(spacing: 4) {
                            HStack {
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(item.walked) / \(item.total)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.walkedGreen)
                                        .frame(
                                            width: geo.size.width * Double(item.walked) / Double(item.total),
                                            height: 6
                                        )
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Walks

    private var recentWalksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent walks")
                .font(.subheadline)
                .fontWeight(.medium)

            if recentWalks.isEmpty {
                Text("Your completed walks will appear here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 12)
            } else {
                ForEach(recentWalks, id: \.record.stairwayID) { item in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.walkedGreen.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.walkedGreen)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.stairway?.name ?? item.record.stairwayID)
                                .font(.subheadline)
                            Text(item.stairway?.neighborhood ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let date = item.record.dateWalked {
                            HStack(spacing: 4) {
                                if item.record.hardModeAtCompletion {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.forestGreen)
                                }
                                Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sync Status Sheet

struct SyncStatusSheet: View {
    let manager: SyncStatusManager

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .presentationDragIndicator(.visible)
    }

    private var iconName: String {
        switch manager.state {
        case .unknown:              return "cloud"
        case .syncing:              return "arrow.clockwise.icloud"
        case .synced:               return "checkmark.icloud.fill"
        case .unavailable:          return "icloud.slash.fill"
        case .error:                return "exclamationmark.icloud.fill"
        }
    }

    private var iconColor: Color {
        switch manager.state {
        case .unknown:              return .secondary
        case .syncing:              return .blue
        case .synced:               return .green
        case .unavailable, .error:  return .red
        }
    }

    private var title: String {
        switch manager.state {
        case .unknown:              return "iCloud Sync"
        case .syncing:              return "Syncing…"
        case .synced:               return "Up to date"
        case .unavailable:          return "Sync unavailable"
        case .error:                return "Sync error"
        }
    }

    private var detail: String {
        switch manager.state {
        case .unknown:
            return "Waiting for first sync event"
        case .syncing:
            return "Uploading or downloading changes"
        case .synced(let date):
            let formatter = RelativeDateTimeFormatter()
            return "Last synced \(formatter.localizedString(for: date, relativeTo: Date()))"
        case .unavailable(let reason):
            return reason
        case .error(let message):
            return message
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
