import Foundation

/// The newest books with a summary, newest first, for the "Newly added" shelves in Discover and
/// Library. From `GET books/new`.
struct NewBooks: Codable {
    let books: [Book]
    /// Books with a summary added in the last 7 days
    let addedThisWeek: Int

    /// "12 added this week"; nil in a week without new books
    var caption: String? {
        addedThisWeek > 0 ? "\(addedThisWeek) added this week" : nil
    }
}
