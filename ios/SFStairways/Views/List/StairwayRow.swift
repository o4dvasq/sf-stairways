import SwiftUI

struct StairwayRow: View {
    let stairway: Stairway
    let walkRecord: WalkRecord?
    var override: StairwayOverride? = nil

    private var isWalked: Bool {
        walkRecord?.walked ?? false
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(stairway.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .strikethrough(stairway.closed, color: Color.closedRed)
                    if stairway.closed {
                        Text("Closed")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.closedRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.closedRed.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    // Stair count: verified overrides pedometer steps
                    if let verifiedStairs = override?.verifiedStepCount {
                        verifiedStatText("\(verifiedStairs) stairs")
                    } else if let steps = walkRecord?.stepCount {
                        Text("\(steps) steps")
                    }

                    // Height: verified overrides catalog
                    if let verifiedHeight = override?.verifiedHeightFt {
                        verifiedStatText("\(Int(verifiedHeight)) ft")
                    } else if let height = stairway.heightFt {
                        Text("\(Int(height)) ft")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                let photos = walkRecord?.photoArray ?? []
                if !photos.isEmpty {
                    Text("\(photos.count) photo\(photos.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }

                if isWalked {
                    if walkRecord?.proximityVerified == false {
                        Image(systemName: "xmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.brandAmber)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.walkedGreen)
                    }
                } else {
                    Circle()
                        .stroke(Color(.separator), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func verifiedStatText(_ text: String) -> some View {
        HStack(spacing: 2) {
            Text(text)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 8))
                .foregroundStyle(Color.forestGreen)
        }
    }
}
