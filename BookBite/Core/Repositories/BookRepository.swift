import Foundation
import Combine

protocol BookRepository {
    func fetchAllBooks() async throws -> [Book]
    func fetchFeaturedBooks() async throws -> [Book]
    func fetchNYTBestsellerBooks() async throws -> [Book]
    func fetchBook(by id: String) async throws -> Book?
    func fetchSummary(for bookId: String) async throws -> Summary?
    func searchBooks(query: String) async throws -> [Book]
    func fetchCategories() async throws -> [BookCategory]
    func fetchBooksByCategory(_ category: String, page: Int, limit: Int) async throws -> [Book]
    func clearCache()
}

protocol FavoriteRepository {
    func checkFavoriteStatus(for bookId: String) async throws -> Bool
    func addToFavorites(_ bookId: String) async throws
    func removeFromFavorites(_ bookId: String) async throws
    func fetchFavorites() async throws -> [Book]
    func downloadFavoriteForOffline(_ book: Book) async throws
}

protocol DailyIdeaProviding {
    /// date is the user's local day as YYYY-MM-DD
    func fetchDailyIdea(for date: String) async throws -> DailyIdea?
}

protocol HighlightsProviding {
    /// Books with a summary, most read first, each with its hook and one key idea. page starts at 1.
    func fetchHighlights(page: Int, limit: Int) async throws -> HighlightsPage
}

/// Ask: answers to personal questions from ideas across the catalogue (`ask/*` endpoints)
protocol AskProviding {
    /// `date` is the local day, yyyy-MM-dd
    func fetchAskHome(date: String) async throws -> AskHome
    /// Books that look like they answer a half-typed question
    func fetchAskMatches(for question: String) async throws -> [Book]
    func ask(_ request: AskRequest) -> AsyncThrowingStream<AskStreamEvent, Error>
}

protocol RecommendationsProviding {
    func fetchRecommendations(_ request: RecommendationRequest) async throws -> Recommendations
}

protocol SummaryGenerationCapable {
    func generateSummary(for bookId: String, style: Summary.SummaryStyle) async throws -> SummaryGenerationJob
    func checkSummaryGenerationJob(jobId: String) async throws -> SummaryGenerationJob
}