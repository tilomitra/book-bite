import Foundation

/// The Library tab's saved (favorites) and downloaded books. Recently opened books come from `RecentBooksStore`.
@MainActor
final class MyLibraryViewModel: ObservableObject {
    @Published var savedBooks: [Book] = []
    @Published var downloadedBooks: [Book] = []
    @Published var savedError: Error?

    private let repository: BookRepository
    private let offlineStorage: OfflineStorageService
    private let cache: CacheService

    init(repository: BookRepository, offlineStorage: OfflineStorageService = .shared, cache: CacheService = .shared) {
        self.repository = repository
        self.offlineStorage = offlineStorage
        self.cache = cache
    }

    /// `userId` keeps one account's saved books from showing on another's Library
    func load(isSignedIn: Bool, userId: String? = nil) async {
        downloadedBooks = offlineStorage.getAllOfflineBooks()
            .sorted { $0.downloadedAt > $1.downloadedAt }
            .compactMap { offlineStorage.getOfflineBook(id: $0.bookId) }

        guard isSignedIn, let favorites = repository as? FavoriteRepository else {
            savedBooks = []
            return
        }
        let snapshotKey = userId.map { "favorites-\($0)" }
        if savedBooks.isEmpty, let snapshotKey {
            savedBooks = cache.snapshot([Book].self, key: snapshotKey) ?? []
        }
        do {
            let books = try await favorites.fetchFavorites()
            savedBooks = books
            savedError = nil
            if let snapshotKey {
                let cache = cache
                Task.detached(priority: .utility) {
                    cache.saveSnapshot(books, key: snapshotKey)
                }
            }
        } catch {
            if !(error is CancellationError) { savedError = error }
        }
    }
}
