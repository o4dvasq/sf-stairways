import SwiftUI
import SwiftData

struct ProgressTab: View {
    @Environment(SyncStatusManager.self) private var syncManager
    @Environment(NeighborhoodStore.self) private var neighborhoodStore
    @Query private var walkRecords: [WalkRecord]
    @Query private var overrides: [StairwayOverride]
    @Query private var deletions: [StairwayDeletion]
    @State private var store = StairwayStore()
    @State private var showSyncDetails = false
    @AppStorage("progress.undiscovered.collapsed") private var undiscoveredCollapsed = true
    @State private var nuggets = NuggetProvider()

    private struct NeighborhoodCardData: Identifiable {
        var id: String { name }
        let name: String
        let walked: Int
        let total: Int
        let lastWalked: Date?

        var fraction: Double { total > 0 ? Double(walked) / Double(total) : 0 }
    }

    // MARK: - Computed Properties

    private var validStairwayIDs: Set<String> {
        Set(store.stairways.map(\.id))
    }

    private var walkedRecords: [WalkRecord] {
        let valid = validStairwayIDs
        return walkRecords.filter { $0.walked && valid.contains($0.stairwayID) }
    }

    private var verifiedCount: Int {
        let valid = validStairwayIDs
        return walkRecords.filter { $0.proximityVerified == true && valid.contains($0.stairwayID) }.count
    }

    private var totalStairways: Int { store.stairways.count }
    private var walkedCount: Int { walkedRecords.count }

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

    private var dailyNugget: String? {
        let seed = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return nuggets.globalFact(seed: seed)
    }

    private var allNeighborhoodCards: [NeighborhoodCardData] {
        let walkedIDs = Set(walkedRecords.map(\.stairwayID))
        let grouped = Dictionary(grouping: store.stairways, by: \.neighborhood)
        return grouped.map { name, stairways in
            let walkedInHood = stairways.filter { walkedIDs.contains($0.id) }
            let lastWalked = walkedInHood
                .compactMap { s in walkRecords.first { $0.stairwayID == s.id }?.dateWalked }
                .max()
            return NeighborhoodCardData(
                name: name,
                walked: walkedInHood.count,
                total: stairways.count,
                lastWalked: lastWalked
            )
        }
    }

    private var activeNeighborhoodCards: [NeighborhoodCardData] {
        allNeighborhoodCards
            .filter { $0.walked > 0 }
            .sorted {
                if $0.fraction != $1.fraction { return $0.fraction > $1.fraction }
                return ($0.lastWalked ?? .distantPast) > ($1.lastWalked ?? .distantPast)
            }
    }

    private var undiscoveredNeighborhoodNames: [String] {
        allNeighborhoodCards
            .filter { $0.walked == 0 }
            .map(\.name)
            .sorted()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    compactSummary
                    if let nugget = dailyNugget {
                        Text(nugget)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .padding(.top, -8)
                    }
                    Divider()
                    yourNeighborhoodsSection
                    undiscoveredSection
                }
                .padding(16)
            }
            .onAppear {
                store.applyDeletions(deletions.map(\.stairwayID))
            }
            .onChange(of: deletions) { _, d in
                store.applyDeletions(d.map(\.stairwayID))
            }
            .navigationTitle("Progress")
            .navigationDestination(for: String.self) { neighborhoodName in
                NeighborhoodDetail(neighborhoodName: neighborhoodName)
            }
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

    // MARK: - Compact Summary

    private var compactSummary: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: completionFraction)
                    .stroke(
                        Color.brandOrange,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: completionFraction)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(walkedCount) of \(totalStairways)")
                    .font(.system(.title3, design: .rounded, weight: .medium))
                Text("\(Int(completionFraction * 100))% · \(totalHeightClimbed.formatted()) ft")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                let n = activeNeighborhoodCards.count
                let neighborhoodLine = verifiedCount > 0
                    ? "\(n) neighborhood\(n == 1 ? "" : "s") · \(verifiedCount) verified"
                    : "\(n) neighborhood\(n == 1 ? "" : "s")"
                Text(neighborhoodLine)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Your Neighborhoods

    private var yourNeighborhoodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your neighborhoods")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)

            if activeNeighborhoodCards.isEmpty {
                Text("Walk some stairways to see neighborhood progress!")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ], spacing: 10) {
                    ForEach(activeNeighborhoodCards) { card in
                        NavigationLink(value: card.name) {
                            NeighborhoodCard(name: card.name, walked: card.walked, total: card.total)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Undiscovered

    private var undiscoveredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    undiscoveredCollapsed.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Undiscovered")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        let n = undiscoveredNeighborhoodNames.count
                        Text("\(n) neighborhood\(n == 1 ? "" : "s")")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: undiscoveredCollapsed ? "chevron.down" : "chevron.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !undiscoveredCollapsed {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(undiscoveredNeighborhoodNames.enumerated()), id: \.element) { index, name in
                        NavigationLink(value: name) {
                            HStack {
                                Text(name)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)

                        if index < undiscoveredNeighborhoodNames.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sync Icon

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
