import Foundation

/// The Library tab's saved (favorites), downloaded and newly added books. Recently opened books come from `RecentBooksStore`.
@MainActor
final class MyLibraryViewModel: ObservableObject {
    @Published var savedBooks: [Book] = []
    @Published var downloadedBooks: [Book] = []
    @Published var savedError: Error?
    /// Newest books in the catalogue; nil until loaded or if loading fails
    @Published var newBooks: NewBooks?

    private let repository: BookRepository
    private let offlineStorage: OfflineStorageService

    init(repository: BookRepository, offlineStorage: OfflineStorageService = .shared) {
        self.repository = repository
        self.offlineStorage = offlineStorage
    }

    func load(isSignedIn: Bool) async {
        downloadedBooks = offlineStorage.getAllOfflineBooks()
            .sorted { $0.downloadedAt > $1.downloadedAt }
            .compactMap { offlineStorage.getOfflineBook(id: $0.bookId) }

        if let provider = repository as? NewBooksProviding {
            // A failure keeps the last list (or hides the shelf)
            if let latest = try? await provider.fetchNewBooks(limit: 24) { newBooks = latest }
        }

        guard isSignedIn, let favorites = repository as? FavoriteRepository else {
            savedBooks = []
            return
        }
        do {
            savedBooks = try await favorites.fetchFavorites()
            savedError = nil
        } catch {
            if !(error is CancellationError) { savedError = error }
        }
    }
}
