import SwiftUI
import UIKit

/// The snippet Siri and Shortcuts show for "Today's idea": a pull quote in the reader's serif,
/// with the book's cover and byline. Quiet, like the Discover card it mirrors.
struct DailyIdeaSnippetView: View {
    let idea: DailyIdea
    let cover: UIImage?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            coverView
                .frame(width: 56, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("IDEA OF THE DAY")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                Text(idea.idea.idea)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(byline)
                    .font(.system(.footnote, design: .serif).italic())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private var byline: String {
        let author = idea.book.shelfAuthor
        return author.isEmpty ? idea.book.shelfTitle : "\(idea.book.shelfTitle), \(author)"
    }

    @ViewBuilder
    private var coverView: some View {
        if let cover {
            Image(uiImage: cover)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            TypographicCover(title: idea.book.shelfTitle, author: idea.book.shelfAuthor)
        }
    }
}
