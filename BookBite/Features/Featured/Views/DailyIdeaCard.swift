import SwiftUI

/// One short idea, a new one each time the app opens, on a card near the top of the Discover tab.
/// Tap to open the book.
struct DailyIdeaCard: View {
    let dailyIdea: DailyIdea
    @Namespace private var zoom

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionTitle("An idea for you")

            NavigationLink {
                BookDetailView(book: dailyIdea.book)
                    .navigationTransition(.zoom(sourceID: dailyIdea.book.id, in: zoom))
            } label: {
                VStack(alignment: .leading, spacing: 18) {
                    Text("“\(dailyIdea.idea.idea)”")
                        .font(.system(size: 22, design: .serif))
                        .lineSpacing(3)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        EditorialCover(book: dailyIdea.book, width: 30)
                            .zoomSource(id: dailyIdea.book.id, in: zoom)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(dailyIdea.book.shelfTitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text(dailyIdea.book.shelfAuthor)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.paperRaised, in: .rect(cornerRadius: 16))
                .contentShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }
}
