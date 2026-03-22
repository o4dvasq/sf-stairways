import SwiftUI
import SwiftData

struct ProgressTab: View {
    @Query private var walkRecords: [WalkRecord]
    @State private var store = StairwayStore()

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
            .compactMap(\.heightFt)
            .reduce(0) { $0 + Int($1) }
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

    private var neighborhoodProgress: [(name: String, walked: Int, total: Int)] {
        let walkedIDs = Set(walkedRecords.map(\.stairwayID))
        let grouped = Dictionary(grouping: store.stairways, by: \.neighborhood)

        return grouped
            .map { neighborhood, stairways in
                let walked = stairways.filter { walkedIDs.contains($0.id) }.count
                return (name: neighborhood, walked: walked, total: stairways.count)
            }
            .filter { $0.walked > 0 }
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
            .navigationTitle("Progress")
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

            if neighborhoodProgress.isEmpty {
                Text("Walk some stairways to see neighborhood progress!")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 12)
            } else {
                ForEach(neighborhoodProgress, id: \.name) { item in
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
