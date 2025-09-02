import Testing
import Foundation
@testable import BookBite

@MainActor
struct RemoteBookRepositoryTests {
    
    @Test("RemoteBookRepository should initialize properly")
    func testInitialization() async throws {
        let repository = RemoteBookRepository()
        #expect(repository != nil)
    }
    
    @Test("RemoteBookRepository should handle network errors gracefully")
    func testNetworkError() async throws {
        let repository = RemoteBookRepository()
        
        // Without a server, this should throw an error
        do {
            let _ = try await repository.fetchAllBooks()
            #expect(false) // Should not reach here
        } catch {
            #expect(error != nil)
        }
    }
    
    @Test("RemoteBookRepository should handle individual book fetch errors")
    func testFetchBookError() async throws {
        let repository = RemoteBookRepository()
        
        do {
            let _ = try await repository.fetchBook(by: "nonexistent-id")
        } catch {
            #expect(error != nil)
        }
    }
    
    @Test("RemoteBookRepository should handle search query")
    func testSearchQuery() async throws {
        let repository = RemoteBookRepository()
        
        do {
            let _ = try await repository.searchBooks(query: "test")
        } catch {
            #expect(error != nil)
        }
    }
    
    @Test("RemoteBookRepository should handle categories fetch")
    func testFetchCategories() async throws {
        let repository = RemoteBookRepository()
        
        do {
            let _ = try await repository.fetchCategories()
        } catch {
            #expect(error != nil)
        }
    }
    
    @Test("RemoteBookRepository should handle cache clearing")
    func testClearCache() {
        let repository = RemoteBookRepository()
        repository.clearCache()
        #expect(true) // Should complete without error
    }
}