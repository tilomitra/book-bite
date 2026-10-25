import SwiftUI

struct ConfidenceBadge: View {
    let confidence: Confidence

    var badgeColor: Color {
        switch confidence {
        case .high:
            return DesignSystem.Colors.badgeGreen
        case .medium:
            return DesignSystem.Colors.badgeOrange
        case .low:
            return DesignSystem.Colors.badgeYellow
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(badgeColor)
                .frame(width: 8, height: 8)

            Text(confidence.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(badgeColor.opacity(0.15))
        .clipShape(Capsule())
    }
}