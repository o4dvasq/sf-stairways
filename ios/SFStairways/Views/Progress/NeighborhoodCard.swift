import SwiftUI

struct NeighborhoodCard: View {
    let name: String
    let walked: Int
    let total: Int

    private var fraction: Double { total > 0 ? Double(walked) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)

            Text("\(walked) / \(total)")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.forestGreen)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.brandOrange)
                        .frame(width: geo.size.width * fraction, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
