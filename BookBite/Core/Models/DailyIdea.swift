import Foundation

/// One key idea from one book, picked by the server for a date. Everyone sees the same idea that day.
struct DailyIdea: Codable {
    let date: String
    let book: Book
    let idea: KeyIdea
    let hook: String?

    /// Text for the share sheet, e.g. "Small habits compound." — Atomic Habits by James Clear
    var shareText: String {
        "\"\(idea.idea)\" — \(book.title) by \(book.formattedAuthors)\n\nFrom BookBite"
    }
}
