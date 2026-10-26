import Foundation

/// The Library tab's saved (favorites) and downloaded books. Recently opened books come from `RecentBooksStore`.
@MainActor
final class MyLibraryViewModel: ObservableObject {
    @Published var savedBooks: [Book] = []
    @Published var downloadedBooks: [Book] = []
    @Published var savedError: Error?

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
