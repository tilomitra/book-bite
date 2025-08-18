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