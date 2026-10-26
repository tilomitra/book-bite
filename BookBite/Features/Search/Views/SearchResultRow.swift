import SwiftUI

/// One book in a list: cover, title, author, year.
struct SearchResultRow: View {
    let book: Book

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            BookCoverView(book: book, size: .small)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)

                Text(book.formattedAuthors)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let year = book.publishedYear {
                    Text(String(year))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
