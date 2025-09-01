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
}

protocol SummaryGenerationCapable {
    func generateSummary(for bookId: String, style: Summary.SummaryStyle) async throws -> SummaryGenerationJob
    func checkSummaryGenerationJob(jobId: String) async throws -> SummaryGenerationJob
}