import SwiftUI

/// An answer as plain serif text, no bubble: the direct answer, points with a chip for the book each
/// comes from, "This week" and the other side.
struct AskAnswerView: View {
    let answer: AskAnswer
    /// Numbered from 1, as the answer cites them
    let sources: [Book]
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(answer.lead)
                .font(.system(size: 23, weight: .regular, design: .serif))
                .tracking(-0.3)
                .lineSpacing(2)

            ForEach(Array(answer.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph).modifier(AnswerBody())
            }

            ForEach(Array(answer.points.enumerated()), id: \.offset) { _, point in
                VStack(alignment: .leading, spacing: 10) {
                    if point.lead.isEmpty {
                        Text(point.body).modifier(AnswerBody())
                    } else {
                        Text("\(Text(point.lead).fontWeight(.semibold).foregroundStyle(.primary)) \(point.body)")
                            .modifier(AnswerBody())
                    }
                    SourceChips(books: point.sources.compactMap { sources[safe: $0 - 1] })
                }
            }

            if answer.points.isEmpty {
                SourceChips(books: answer.proseSources.compactMap { sources[safe: $0 - 1] })
            }

            if let week = answer.thisWeek, !week.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This week".uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    Text(week)
                        .font(.system(size: 20, design: .serif))
                        .lineSpacing(2)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.primary.opacity(0.05)))
            }

            if let other = answer.otherSide, !other.isEmpty {
                Text(other)
                    .font(.system(size: 17, design: .serif).italic())
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
        }
        .textSelection(.enabled)
        .animation(isStreaming ? nil : .default, value: answer)
    }
}

private struct AnswerBody: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 18, design: .serif))
            .foregroundStyle(.primary.opacity(0.88))
            .lineSpacing(4)
    }
}

/// Small cover + title of each cited book; opens the book
private struct SourceChips: View {
    let books: [Book]

    var body: some View {
        if !books.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { chips }
                VStack(alignment: .leading, spacing: 8) { chips }
            }
        }
    }

    private var chips: some View {
        ForEach(books) { book in
            NavigationLink(value: BookRoute(book: book)) {
                HStack(spacing: 7) {
                    EditorialCover(book: book, width: 14)
                    Text(book.shelfTitle)
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                }
                .padding(.leading, 8)
                .padding(.trailing, 11)
                .frame(height: 30)
                .background(Capsule().fill(Color.primary.opacity(0.055)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(book.title)")
        }
    }
}
