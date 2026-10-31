import SwiftUI
import UIKit

/// Books the app knows in full, for showing covers on the pass shelf (the pass stores only ids)
@MainActor
enum PassBooks {
    static func lookup() -> [String: Book] {
        var books: [String: Book] = [:]
        for book in RecentBooksStore.shared.books { books[book.id.lowercased()] = book }
        for entry in ReadingProgressStore.shared.entries { books[entry.book.id.lowercased()] = entry.book }
        return books
    }
}

/// The reading pass as a bookshelf: a row of five places per allowance, each book opened in full
/// standing in its place as a small cover. Empty places are dashed outlines. Colour comes only from covers.
struct PassShelf: View {
    let rows: [ReadingPass.ShelfRow]
    let books: [String: Book]
    var coverWidth: CGFloat = 46

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 8) {
                    Text(row.title.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(Array(row.bookIds.enumerated()), id: \.offset) { _, bookId in
                            place(bookId)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 4)
                    // The shelf board
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.primary.opacity(0.7)).frame(height: 1.5)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: row))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func place(_ bookId: String?) -> some View {
        if let bookId, let book = books[bookId] {
            EditorialCover(book: book, width: coverWidth)
        } else if bookId != nil {
            // Opened on another device: no cover here
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.primary.opacity(0.75))
                .frame(width: coverWidth, height: coverWidth * 1.5)
        } else {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: coverWidth, height: coverWidth * 1.5)
        }
    }

    private func accessibilityLabel(for row: ReadingPass.ShelfRow) -> String {
        let read = row.bookIds.compactMap { $0 }
        let titles = read.compactMap { books[$0]?.shelfTitle }
        let free = row.bookIds.count - read.count
        var label = "\(row.title): \(read.count) read, \(free) free"
        if !titles.isEmpty { label += ". " + titles.joined(separator: ", ") }
        return label
    }
}

/// Library's reading pass line: a row of five spines (the shelf row being filled) and what's left.
/// Opens the pass sheet. Hidden for subscribers.
struct ReadingPassRow: View {
    @ObservedObject private var store = ReadingPassStore.shared

    var body: some View {
        if !store.hasUnlimited {
            Button {
                store.isPresentingPass = true
            } label: {
                HStack(spacing: 16) {
                    if let row = store.pass.currentShelfRow {
                        MiniShelf(row: row)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        Text("Give a friend 5 books, get 5 more")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 0.5) }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 0.5) }
            .padding(.horizontal, 20)
            .accessibilityHint("Shows your reading pass and invite code")
        }
    }

    private var title: String {
        if store.newFriends > 0 {
            return store.newFriends == 1 ? "A friend joined: 5 more books" : "\(store.newFriends) friends joined: \(store.newFriends * 5) more books"
        }
        if store.pendingInviteCode != nil && !store.isSignedIn {
            return "A friend gave you 5 books"
        }
        let left = store.pass.remaining
        return left == 1 ? "1 free book left" : "\(left) free books left"
    }
}

/// Five spines in a row: filled for books opened, outlined for places still free
private struct MiniShelf: View {
    let row: ReadingPass.ShelfRow

    /// Uneven heights, like real spines
    private static let heights: [CGFloat] = [26, 22, 28, 24, 26]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(row.bookIds.prefix(5).enumerated()), id: \.offset) { index, bookId in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(bookId == nil ? Color.clear : Color.primary.opacity(0.8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 1.5).strokeBorder(Color.primary.opacity(bookId == nil ? 0.3 : 0), lineWidth: 1)
                    }
                    .frame(width: 7, height: Self.heights[index])
            }
        }
        .padding(.bottom, 2)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.7)).frame(height: 1) }
        .accessibilityHidden(true)
    }
}

/// End of the reader: give a friend 5 books, with the book just finished in the message.
/// Shown only when the reader has an invite code (signed in).
struct GiftBookButton: View {
    let book: Book
    let style: ReaderStyle

    @ObservedObject private var store = ReadingPassStore.shared

    var body: some View {
        if let invite = store.accountPass?.invite {
            ShareLink(
                item: invite.url,
                subject: Text("5 free books on Bookgist"),
                message: Text(InviteMessage.text(code: invite.code, url: invite.url, book: book))
            ) {
                Label("Give a friend 5 books", systemImage: "gift")
                    .font(.system(size: style.size * 0.85, design: style.typeface.design))
                    .foregroundStyle(style.theme.ink)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 44)
                    .overlay(Capsule().strokeBorder(style.theme.rule, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("You both get 5 more books when they join")
        }
    }
}
