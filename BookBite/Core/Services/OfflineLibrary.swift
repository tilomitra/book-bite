import Foundation

/// Decides what stays on the device for offline reading. Saved books are downloaded by the book page
/// (`downloadFavoriteForOffline`); this keeps every book opened in full (reader or Listen, guests too),
/// removes those copies some time after the book is finished, and refreshes old downloads while online.
@MainActor
final class OfflineLibrary {
    static let shared = OfflineLibrary()

    /// Downloads older than this are refreshed at launch
    static let refreshAge: TimeInterval = 7 * 24 * 60 * 60
    /// At most this many per launch, so a big library doesn't hold the network
    static let refreshLimit = 10

    private let storage: OfflineStorageService
    private let connectivity: ConnectivityChecking
    private var isMaintaining = false

    init(storage: OfflineStorageService = .shared, connectivity: ConnectivityChecking = ConnectivityMonitor.shared) {
        self.storage = storage
        self.connectivity = connectivity
    }

    /// Keeps a book opened in full on the device: text now, cover in the background
    func keepForReading(_ book: Book, summary: Summary?) {
        let storage = storage
        Task.detached(priority: .utility) {
            do {
                try storage.downloadBookForOffline(book, summary: summary, reason: .reading)
            } catch {
                if AppConfiguration.shared.isLoggingEnabled {
                    print("⚠️ OfflineLibrary: Couldn't keep \(book.id) for reading: \(error)")
                }
                return
            }
            if storage.offlineBook(id: book.id)?.hasCoverImage != true,
               let cover = book.coverAssetName, !cover.isEmpty {
                try? await storage.downloadCoverImage(from: cover, for: book.id)
            }
        }
    }

    /// At launch: removes reading copies that are done with, then refreshes the oldest downloads.
    /// `repository` must write fresh data into downloads, as `HybridBookRepository` does.
    func maintain(repository: BookRepository, progress: ReadingProgressStore = .shared) async {
        guard !isMaintaining else { return }
        isMaintaining = true
        defer { isMaintaining = false }

        prune(progress: progress)

        let stale = OfflineBook.stale(storage.getAllOfflineBooks(), maxAge: Self.refreshAge, limit: Self.refreshLimit)
        for entry in stale {
            guard connectivity.isOnline, !Task.isCancelled else { break }
            _ = try? await repository.fetchBook(by: entry.bookId)
            _ = try? await repository.fetchSummary(for: entry.bookId)
            if !entry.hasCoverImage,
               let cover = storage.getOfflineBook(id: entry.bookId)?.coverAssetName, !cover.isEmpty {
                try? await storage.downloadCoverImage(from: cover, for: entry.bookId)
            }
            storage.markRefreshed(bookId: entry.bookId)
        }
    }

    func prune(progress: ReadingProgressStore = .shared) {
        let finishedAt = Dictionary(progress.entries.map { ($0.book.id, $0.finishedAt) },
                                    uniquingKeysWith: { first, _ in first })
        for id in OfflineBook.expiredReadingCopies(storage.getAllOfflineBooks(), progress: finishedAt) {
            storage.removeOfflineBook(id)
        }
    }
}
