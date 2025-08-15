import Foundation
import Combine

protocol BookRepository {
    func fetchAllBooks() async throws -> [Book]
    func fetchFeaturedBooks() async throws -> [Book]
    func fetchBook(by id: String) async throws -> Book?
    func fetchSummary(for bookId: String) async throws -> Summary?
    func searchBooks(query: String) async throws -> [Book]
    func clearCache()
}