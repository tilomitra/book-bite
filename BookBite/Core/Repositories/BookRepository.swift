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
    /// A random book and key idea, different on every call; bookId is a book to skip
    func fetchRandomIdea(excluding bookId: String?) async throws -> DailyIdea?
}

protocol HighlightsProviding {
    /// Books with a summary, each with its hook and one key idea. page starts at 1. seed (1...Int32.max,
    /// new per visit) mixes the order and the idea per book; the same seed gives the same pages.
    func fetchHighlights(page: Int, limit: Int, seed: Int) async throws -> HighlightsPage
}

/// Ask: answers to personal questions from ideas across the catalogue (`ask/*` endpoints)
protocol AskProviding {
    /// `date` is the local day, yyyy-MM-dd
    func fetchAskHome(date: String) async throws -> AskHome
    /// Books that look like they answer a half-typed question
    func fetchAskMatches(for question: String) async throws -> [Book]
    func ask(_ request: AskRequest) -> AsyncThrowingStream<AskStreamEvent, Error>
}

/// Free books left, books opened in full and the invite code. Signed-in only (`/user/reading-pass`).
protocol ReadingPassProviding {
    func fetchReadingPass() async throws -> ReadingPass
    /// Opens books while books are left; the returned pass lists the ones that are unlocked
    func unlockBooks(_ bookIds: [String]) async throws -> ReadingPass
    /// Joins with a friend's code. Throws `ReadingPassError.rejected` with a message to show.
    func redeemInviteCode(_ code: String) async throws -> ReadingPass
}

protocol RecommendationsProviding {
    func fetchRecommendations(_ request: RecommendationRequest) async throws -> Recommendations
}

protocol SummaryGenerationCapable {
    func generateSummary(for bookId: String, style: Summary.SummaryStyle) async throws -> SummaryGenerationJob
    func checkSummaryGenerationJob(jobId: String) async throws -> SummaryGenerationJob
}