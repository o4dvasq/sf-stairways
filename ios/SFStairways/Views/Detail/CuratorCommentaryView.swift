import SwiftUI

/// Displays published curator commentary for a stairway. Hidden when no published record exists.
struct CuratorCommentaryView: View {
    let commentary: CuratorCommentary?

    var body: some View {
        if let text = commentary?.commentary, !text.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                Text("\u{201C}")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.forestGreen)
                    .frame(width: 24)
                    .offset(y: -6)

                Text(text)
                    .font(.subheadline)
                    .italic()
                    .fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
