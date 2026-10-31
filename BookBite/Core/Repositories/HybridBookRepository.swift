import Foundation

class HybridBookRepository: BookRepository, SummaryGenerationCapable, FavoriteRepository, DailyIdeaProviding, RecommendationsProviding, HighlightsProviding, AskProviding, ReadingPassProviding {
    private let remoteRepository = RemoteBookRepository()
    private let offlineStorage = OfflineStorageService.shared
    private let cache = CacheService.shared
    private let connectivity: ConnectivityChecking

    init(connectivity: ConnectivityChecking = ConnectivityMonitor.shared) {
        self.connectivity = connectivity
    }
    
    // MARK: - BookRepository Implementation
    
    func fetchAllBooks() async throws -> [Book] {
        return try await remoteRepository.fetchAllBooks()
    }
    
    func fetchFeaturedBooks() async throws -> [Book] {
        return try await remoteRepository.fetchFeaturedBooks()
    }
    
    func fetchNYTBestsellerBooks() async throws -> [Book] {
        return try await remoteRepository.fetchNYTBestsellerBooks()
    }
    
    /// Online: the server, then the copy on the device if the request fails. Offline: the copy first, without waiting.
    func fetchBook(by id: String) async throws -> Book? {
        if !connectivity.isOnline, let local = localBook(id: id) {
            return local
        }
        do {
            return try await remoteRepository.fetchBook(by: id)
        } catch {
            if let local = localBook(id: id) {
                if AppConfiguration.shared.isLoggingEnabled {
                    print("📖 HybridBookRepository: Using the book on the device for \(id)")
                }
                return local
            }
            throw error
        }
    }

    func fetchSummary(for bookId: String) async throws -> Summary? {
        if !connectivity.isOnline, let local = localSummary(bookId: bookId) {
            return local
        }
        do {
            return try await remoteRepository.fetchSummary(for: bookId)
        } catch {
            if let local = localSummary(bookId: bookId) {
                if AppConfiguration.shared.isLoggingEnabled {
                    print("📖 HybridBookRepository: Using the summary on the device for book \(bookId)")
                }
                return local
            }
            throw error
        }
    }

    // A download is kept until removed; the cache is newer (every fetch writes it) but iOS can purge it
    private func localBook(id: String) -> Book? {
        (try? cache.getCachedBook(id: id)) ?? offlineStorage.getOfflineBook(id: id)
    }

    private func localSummary(bookId: String) -> Summary? {
        (try? cache.getCachedSummary(bookId: bookId)) ?? offlineStorage.getOfflineSummary(bookId: bookId)
    }
    
    func fetchDailyIdea(for date: String) async throws -> DailyIdea? {
        return try await remoteRepository.fetchDailyIdea(for: date)
    }

    func fetchRandomIdea(excluding bookId: String?) async throws -> DailyIdea? {
        return try await remoteRepository.fetchRandomIdea(excluding: bookId)
    }

    func fetchHighlights(page: Int, limit: Int, seed: Int) async throws -> HighlightsPage {
        return try await remoteRepository.fetchHighlights(page: page, limit: limit, seed: seed)
    }

    func fetchRecommendations(_ request: RecommendationRequest) async throws -> Recommendations {
        return try await remoteRepository.fetchRecommendations(request)
    }

    func fetchAskHome(date: String) async throws -> AskHome {
        return try await remoteRepository.fetchAskHome(date: date)
    }

    func fetchAskMatches(for question: String) async throws -> [Book] {
        return try await remoteRepository.fetchAskMatches(for: question)
    }

    func ask(_ request: AskRequest) -> AsyncThrowingStream<AskStreamEvent, Error> {
        return remoteRepository.ask(request)
    }

    func fetchReadingPass() async throws -> ReadingPass {
        return try await remoteRepository.fetchReadingPass()
    }

    func unlockBooks(_ bookIds: [String]) async throws -> ReadingPass {
        return try await remoteRepository.unlockBooks(bookIds)
    }

    func redeemInviteCode(_ code: String) async throws -> ReadingPass {
        return try await remoteRepository.redeemInviteCode(code)
    }

    func searchBooks(query: String) async throws -> [Book] {
        return try await remoteRepository.searchBooks(query: query)
    }
    
    func fetchCategories() async throws -> [BookCategory] {
        return try await remoteRepository.fetchCategories()
    }
    
    func fetchBooksByCategory(_ category: String, page: Int, limit: Int) async throws -> [Book] {
        return try await remoteRepository.fetchBooksByCategory(category, page: page, limit: limit)
    }
    
    // MARK: - Additional Remote Features
    
    func generateSummary(for bookId: String, style: Summary.SummaryStyle = .full) async throws -> SummaryGenerationJob {
        return try await remoteRepository.generateSummary(for: bookId, style: style)
    }
    
    func checkSummaryGenerationJob(jobId: String) async throws -> SummaryGenerationJob {
        return try await remoteRepository.checkSummaryGenerationJob(jobId: jobId)
    }
    
    func importBook(isbn: String) async throws -> Book {
        return try await remoteRepository.importBook(isbn: isbn)
    }
    
    func refreshBook(_ bookId: String) async throws -> Book? {
        return try await remoteRepository.refreshBook(bookId)
    }
    
    func refreshSummary(bookId: String) async throws -> Summary? {
        return try await remoteRepository.refreshSummary(bookId: bookId)
    }
    
    // MARK: - FavoriteRepository Implementation
    
    func checkFavoriteStatus(for bookId: String) async throws -> Bool {
        return try await remoteRepository.checkFavoriteStatus(for: bookId)
    }
    
    func addToFavorites(_ bookId: String) async throws {
        try await remoteRepository.addToFavorites(bookId)
    }
    
    func removeFromFavorites(_ bookId: String) async throws {
        try await remoteRepository.removeFromFavorites(bookId)
    }
    
    func fetchFavorites() async throws -> [Book] {
        return try await remoteRepository.fetchFavorites()
    }

    func downloadFavoriteForOffline(_ book: Book) async throws {
        try await remoteRepository.downloadFavoriteForOffline(book)
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        remoteRepository.clearCache()
    }
}