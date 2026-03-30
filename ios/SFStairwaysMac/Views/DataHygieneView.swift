import SwiftUI
import SwiftData

// MARK: - Issue Types

struct HygieneIssue: Identifiable {
    let id = UUID()
    let stairwayID: String
    let stairwayName: String
    let neighborhood: String
    let issueType: IssueType
    let detail: String

    enum IssueType: String, CaseIterable {
        case missingHeight = "Missing Height"
        case missingCoordinates = "Missing Coordinates"
        case promotionCandidate = "Promotion Candidate"
        case unverifiedProximity = "Proximity Unverified"

        var systemImage: String {
            switch self {
            case .missingHeight:        return "ruler"
            case .missingCoordinates:   return "location.slash"
            case .promotionCandidate:   return "doc.text"
            case .unverifiedProximity:  return "mappin.slash"
            }
        }

        var color: Color {
            switch self {
            case .missingHeight, .missingCoordinates:   return Color.brandAmber
            case .unverifiedProximity:                  return .orange
            case .promotionCandidate:                   return .blue
            }
        }
    }
}

// MARK: - View

struct DataHygieneView: View {
    let stairways: [Stairway]
    let walkRecords: [WalkRecord]
    let overrides: [StairwayOverride]
    let walkPhotos: [WalkPhoto]

    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: HygieneIssue.IssueType? = nil

    private var walkedRecordByID: [String: WalkRecord] {
        var dict: [String: WalkRecord] = [:]
        for r in walkRecords where r.walked { dict[r.stairwayID] = r }
        return dict
    }

    private var overrideByID: [String: StairwayOverride] {
        var dict: [String: StairwayOverride] = [:]
        for o in overrides { dict[o.stairwayID] = o }
        return dict
    }

    private var allIssues: [HygieneIssue] {
        var issues: [HygieneIssue] = []

        for stairway in stairways {
            let walkRecord = walkedRecordByID[stairway.id]
            let override = overrideByID[stairway.id]

            // Missing height data
            let hasHeight = (override?.verifiedHeightFt != nil) || (stairway.heightFt != nil)
            if !hasHeight {
                issues.append(HygieneIssue(
                    stairwayID: stairway.id,
                    stairwayName: stairway.name,
                    neighborhood: stairway.neighborhood,
                    issueType: .missingHeight,
                    detail: "No height in catalog or curator overrides"
                ))
            }

            // Missing coordinates
            if !stairway.hasValidCoordinate {
                issues.append(HygieneIssue(
                    stairwayID: stairway.id,
                    stairwayName: stairway.name,
                    neighborhood: stairway.neighborhood,
                    issueType: .missingCoordinates,
                    detail: "Cannot be displayed on map"
                ))
            }

            // Notes with no curator description (promotion candidates)
            if let record = walkRecord,
               let notes = record.notes,
               !notes.isEmpty {
                let hasDescription = override?.stairwayDescription.map { !$0.isEmpty } ?? false
                if !hasDescription {
                    issues.append(HygieneIssue(
                        stairwayID: stairway.id,
                        stairwayName: stairway.name,
                        neighborhood: stairway.neighborhood,
                        issueType: .promotionCandidate,
                        detail: "Has notes but no curator description — ready to promote"
                    ))
                }
            }

            // Proximity unverified
            if let record = walkRecord,
               record.walked,
               record.proximityVerified == false {
                issues.append(HygieneIssue(
                    stairwayID: stairway.id,
                    stairwayName: stairway.name,
                    neighborhood: stairway.neighborhood,
                    issueType: .unverifiedProximity,
                    detail: "Walk recorded but location was not near stairway"
                ))
            }
        }

        return issues
    }

    private var filteredIssues: [HygieneIssue] {
        guard let type = selectedType else { return allIssues }
        return allIssues.filter { $0.issueType == type }
    }

    private var countByType: [HygieneIssue.IssueType: Int] {
        Dictionary(grouping: allIssues, by: \.issueType).mapValues(\.count)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            issueList
        }
        .navigationTitle("Data Hygiene")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedType) {
            Label {
                HStack {
                    Text("All Issues")
                    Spacer()
                    Text("\(allIssues.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            .tag(nil as HygieneIssue.IssueType?)

            Divider()

            ForEach(HygieneIssue.IssueType.allCases, id: \.self) { type in
                let count = countByType[type] ?? 0
                Label {
                    HStack {
                        Text(type.rawValue)
                        Spacer()
                        Text("\(count)")
                            .font(.caption)
                            .foregroundStyle(count > 0 ? type.color : .secondary)
                    }
                } icon: {
                    Image(systemName: type.systemImage)
                        .foregroundStyle(count > 0 ? type.color : .secondary)
                }
                .tag(type as HygieneIssue.IssueType?)
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
    }

    // MARK: - Issue List

    @ViewBuilder
    private var issueList: some View {
        if filteredIssues.isEmpty {
            ContentUnavailableView(
                "No Issues",
                systemImage: "checkmark.circle",
                description: Text(selectedType == nil
                    ? "All stairways look good."
                    : "No issues of this type found.")
            )
        } else {
            Table(filteredIssues) {
                TableColumn("Stairway") { issue in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(issue.stairwayName)
                            .font(.system(size: 12).bold())
                        Text(issue.neighborhood)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .width(min: 180)

                TableColumn("Issue") { issue in
                    Label(issue.issueType.rawValue, systemImage: issue.issueType.systemImage)
                        .font(.system(size: 12))
                        .foregroundStyle(issue.issueType.color)
                }
                .width(160)

                TableColumn("Detail") { issue in
                    Text(issue.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(selectedType?.rawValue ?? "All Issues")
            .navigationSubtitle("\(filteredIssues.count) issues")
        }
    }
}
