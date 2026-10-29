import SwiftUI

/// One short idea, a new one each time the app opens, at the top of the Discover tab, set as a pull quote
/// between two rules. Tap to open the book.
struct DailyIdeaCard: View {
    let dailyIdea: DailyIdea
    @Namespace private var zoom

    var body: some View {
        NavigationLink {
            BookDetailView(book: dailyIdea.book)
                .navigationTransition(.zoom(sourceID: dailyIdea.book.id, in: zoom))
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                Text("An idea for you")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Text("“\(dailyIdea.idea.idea)”")
                    .font(.system(size: 25, design: .serif))
                    .lineSpacing(3)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    EditorialCover(book: dailyIdea.book, width: 34)
                        .zoomSource(id: dailyIdea.book.id, in: zoom)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(dailyIdea.book.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text(dailyIdea.book.formattedAuthors)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.primary).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}
