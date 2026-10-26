import Foundation

/// One book with its hook and one key idea, for Discover's editorial cards. From `GET summaries/highlights`.
struct Highlight: Codable, Identifiable {
    let book: Book
    let hook: String?
    let idea: KeyIdea

    var id: String { book.id }

    /// Ideas often start with a short label ("The Subconscious Mind: Programming your…");
    /// split it off so cards can set it as a heading. Nil when there is no label.
    var ideaLabel: String? {
        guard let range = idea.idea.range(of: ": "),
              idea.idea.distance(from: idea.idea.startIndex, to: range.lowerBound) <= 40 else { return nil }
        return String(idea.idea[..<range.lowerBound])
    }

    /// The idea without its label
    var ideaText: String {
        guard let label = ideaLabel else { return idea.idea }
        return String(idea.idea.dropFirst(label.count + 2))
    }

    /// Long enough to stand alone as a quote ("The Power of Tiny Changes" isn't)
    var isQuotable: Bool { ideaText.count >= 50 && ideaText.count <= 260 }
}

/// One page of the endless Discover feed
struct HighlightsPage: Codable {
    let items: [Highlight]
    let page: Int
    let hasMore: Bool
}
