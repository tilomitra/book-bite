import SwiftUI

/// "Idea of the day": one short idea at the top of the Discover tab. Tap to open the book.
struct DailyIdeaCard: View {
    let dailyIdea: DailyIdea

    var body: some View {
        NavigationLink(destination: BookDetailView(book: dailyIdea.book)) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Idea of the day")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Text(dailyIdea.idea.idea)
                    .font(.system(.title3, design: .serif))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    EnhancedBookCover(coverURL: dailyIdea.book.coverAssetName)
                        .frame(width: 32, height: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(dailyIdea.book.title)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text(dailyIdea.book.formattedAuthors)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}
