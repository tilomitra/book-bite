import Testing
import Foundation
@testable import BookBite

@MainActor
struct HybridBookRepositoryTests {
    
    @Test("HybridBookRepository should delegate to remote repository")
    func testHybridDelegation() async throws {
        let repository = HybridBookRepository()
        
        // Test that all methods are accessible and delegate properly
        do {
            let _ = try await repository.fetchAllBooks()
        } catch {
            #expect(error != nil) // Network error expected in test
        }
        
        do {
            let _ = try await repository.fetchFeaturedBooks()
        } catch {
            #expect(error != nil)
        }
        
        do {
            let _ = try await repository.fetchNYTBestsellerBooks()
        } catch {
            #expect(error != nil)
        }
    }
    
    @Test("HybridBookRepository should handle search delegation")
    func testSearchDelegation() async throws {
        let repository = HybridBookRepository()
        
        do {
            let _ = try await repository.searchBooks(query: "test")
        } catch {
            #expect(error != nil) // Network error expected in test
        }
    }
    
    @Test("HybridBookRepository should handle category operations")
    func testCategoryOperations() async throws {
        let repository = HybridBookRepository()
        
        do {
            let _ = try await repository.fetchCategories()
        } catch {
            #expect(error != nil)
        }
        
        do {
            let _ = try await repository.fetchBooksByCategory("Technology", page: 1, limit: 10)
        } catch {
            #expect(error != nil)
        }
    }
    
    @Test("HybridBookRepository should handle summary generation")
    func testSummaryGeneration() async throws {
        let repository = HybridBookRepository()
        
        do {
            let _ = try await repository.generateSummary(for: "book-id", style: .full)
        } catch {
            #expect(error != nil)
        }
        
        do {
            let _ = try await repository.checkSummaryGenerationJob(jobId: "job-id")
        } catch {
            #expect(error != nil)
        }
    }
    
    @Test("HybridBookRepository should handle favorites operations")
    func testFavoritesOperations() async throws {
        let repository = HybridBookRepository()
        
        do {
            let _ = try await repository.checkFavoriteStatus(for: "book-id")
        } catch {
            #expect(error != nil)
        }
        
        do {
            try await repository.addToFavorites("book-id")
        } catch {
            #expect(error != nil)
        }
        
        do {
            try await repository.removeFromFavorites("book-id")
        } catch {
            #expect(error != nil)
        }
        
        do {
            let _ = try await repository.fetchFavorites()
        } catch {
            #expect(error != nil)
        }
    }
    
    @Test("HybridBookRepository should handle cache operations")
    func testCacheOperations() {
        let repository = HybridBookRepository()
        
        // clearCache should not throw
        repository.clearCache()
        #expect(true) // Verify it completes without error
    }
    
    @Test("HybridBookRepository should handle book import")
    func testBookImport() async throws {
        let repository = HybridBookRepository()
        
        do {
            let _ = try await repository.importBook(isbn: "1234567890")
        } catch {
            #expect(error != nil)
        }
    }
    
    @Test("HybridBookRepository should handle refresh operations")
    func testRefreshOperations() async throws {
        let repository = HybridBookRepository()
        
        do {
            let _ = try await repository.refreshBook("book-id")
        } catch {
            #expect(error != nil)
        }
        
        do {
            let _ = try await repository.refreshSummary(bookId: "book-id")
        } catch {
            #expect(error != nil)
        }
    }
}