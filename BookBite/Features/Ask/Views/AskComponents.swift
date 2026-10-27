import SwiftUI

/// Where a conversation starts: a new question, or one from history.
struct AskRoute: Hashable, Identifiable {
    let id = UUID()
    var question: String?
    var conversation: AskConversation?
}

/// "Your questions". A value, like every screen on Ask's stack: mixing destination links with a path breaks pushes from them.
struct AskHistoryRoute: Hashable {}

/// Three covers fanned out, the first in front. Fewer books fan fewer covers.
struct CoverFan: View {
    let books: [Book]
    /// Width of the front cover; the others are 80% of it
    let width: CGFloat

    var body: some View {
        let side = width * 0.8
        let spread = width * 0.62
        ZStack {
            if books.count > 2 {
                EditorialCover(book: books[2], width: side)
                    .rotationEffect(.degrees(9))
                    .offset(x: spread, y: width * 0.16)
            }
            if books.count > 1 {
                EditorialCover(book: books[1], width: side)
                    .rotationEffect(.degrees(-9))
                    .offset(x: -spread, y: width * 0.16)
            }
            if let front = books.first {
                EditorialCover(book: front, width: width)
            }
        }
        .frame(width: width + spread * 2 + side * 0.25, height: width * 1.5 + width * 0.3)
        .accessibilityHidden(true)
    }
}

/// Small overlapping covers in a row, for "Read 3 books"
struct CoverStack: View {
    let books: [Book]
    var width: CGFloat = 18

    var body: some View {
        HStack(spacing: -width * 0.4) {
            ForEach(books.prefix(4)) { book in
                EditorialCover(book: book, width: width)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.paper, lineWidth: 1.5)
                    )
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// iOS 26 Liquid Glass behind the content, or a material on older systems. Behind, not on: glass
    /// applied to the content itself renders it with vibrancy, which greys out the black send button.
    func askGlass<S: Shape>(in shape: S) -> some View {
        background {
            if #available(iOS 26, *) {
                Color.clear.glassEffect(.regular, in: shape)
            } else {
                shape.fill(.ultraThinMaterial)
            }
        }
    }
}

/// The send arrow in a filled circle
struct AskSendButton: View {
    var size: CGFloat = 40
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(Color.paper)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.primary.opacity(enabled ? 1 : 0.25)))
        }
        .disabled(!enabled)
        .accessibilityLabel("Ask")
    }
}

/// Turns a timestamp into "Today", "Yesterday" or "Oct 19"
enum AskDates {
    static func short(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
