import Foundation

/// A book to push on the Discover tab's navigation stack. Wrapped so it can't collide with
/// other `navigationDestination(for: Book.self)` registrations.
struct BookRoute: Hashable {
    let book: Book
}

/// Opens books from outside the app: `bookbite://` links (shared links, the widget), Spotlight results
/// and App Intents. `RootView` consumes `pending` by switching to Discover and pushing the book.
@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    /// The next book to show. `RootView` sets it back to nil once it has navigated.
    @Published var pending: BookRoute?

    private var openTask: Task<Void, Never>?

    private init() {}

    /// Shows the book with this id. Fetches the full record first (links carry only title, author and
    /// cover); falls back to `partial` if the fetch fails or takes too long.
    func open(bookId: String, partial: Book?) {
        openTask?.cancel()
        openTask = Task {
            let full = await fetchBook(id: bookId)
            guard !Task.isCancelled else { return }
            if let book = full ?? partial {
                pending = BookRoute(book: book)
            }
        }
    }

    /// Shows a book the app already has in full (e.g. from `ReadingProgressStore`).
    func open(_ book: Book) {
        openTask?.cancel()
        pending = BookRoute(book: book)
    }

    private func fetchBook(id: String) async -> Book? {
        let repository = DependencyContainer.shared.bookRepository
        return await withTaskGroup(of: Book?.self) { group in
            group.addTask { try? await repository.fetchBook(by: id) }
            group.addTask {
                try? await Task.sleep(for: .seconds(5))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
