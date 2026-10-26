import Foundation

/// Books the user opened recently, newest first. Stored on device (UserDefaults), so it works without sign-in.
@MainActor
final class RecentBooksStore: ObservableObject {
    static let shared = RecentBooksStore()

    @Published private(set) var books: [Book] = []

    private let defaults: UserDefaults
    private let key = "recentBooks"
    private let limit = 20

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? NetworkService.makeDecoder().decode([Book].self, from: data) {
            books = saved
        }
    }

    func record(_ book: Book) {
        var updated = books.filter { $0.id != book.id }
        updated.insert(book, at: 0)
        books = Array(updated.prefix(limit))
        if let data = try? JSONEncoder().encode(books) {
            defaults.set(data, forKey: key)
        }
    }

    func clear() {
        books = []
        defaults.removeObject(forKey: key)
    }
}
