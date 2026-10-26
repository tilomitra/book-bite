import Foundation

class HybridBookRepository: BookRepository, SummaryGenerationCapable, FavoriteRepository, DailyIdeaProviding, RecommendationsProviding {
    private let remoteRepository = RemoteBookRepository()
    private let offlineStorage = OfflineStorageService.shared

    init() {
        // Simplified - no network monitoring needed
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
    
    func fetchBook(by id: String) async throws -> Book? {
        // Try remote first
        do {
            return try await remoteRepository.fetchBook(by: id)
        } catch {
            // Fall back to offline storage if available
            if let offlineBook = offlineStorage.getOfflineBook(id: id) {
                if AppConfiguration.shared.isLoggingEnabled {
                    print("📖 HybridBookRepository: Using offline book for \(id)")
                }
                return offlineBook
            }
            throw error
        }
    }

    func fetchSummary(for bookId: String) async throws -> Summary? {
        // Try remote first
        do {
            return try await remoteRepository.fetchSummary(for: bookId)
        } catch {
            // Fall back to offline storage if available
            if let offlineSummary = offlineStorage.getOfflineSummary(bookId: bookId) {
                if AppConfiguration.shared.isLoggingEnabled {
                    print("📖 HybridBookRepository: Using offline summary for book \(bookId)")
                }
                return offlineSummary
            }
            throw error
        }
    }
    
    func fetchDailyIdea(for date: String) async throws -> DailyIdea? {
        return try await remoteRepository.fetchDailyIdea(for: date)
    }

    func fetchRecommendations(_ request: RecommendationRequest) async throws -> Recommendations {
        return try await remoteRepository.fetchRecommendations(request)
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