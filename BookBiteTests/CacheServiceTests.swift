import Testing
import Foundation
@testable import BookBite

struct CacheServiceTests {
    
    func createTestBook(id: String = "test-book") -> Book {
        return Book(
            id: id,
            title: "Test Book",
            subtitle: "A Test Subtitle",
            authors: ["Test Author"],
            isbn10: nil,
            isbn13: nil,
            publishedYear: 2023,
            publisher: "Test Publisher",
            categories: ["Test Category"],
            coverAssetName: nil,
            description: "Test description",
            sourceAttribution: ["Test Source"]
        )
    }
    
    func createTestSummary(bookId: String = "test-book") -> Summary {
        return Summary(
            id: "test-summary",
            bookId: bookId,
            oneSentenceHook: "Test hook",
            keyIdeas: [],
            howToApply: [],
            commonPitfalls: ["Pitfall 1"],
            critiques: ["Critique 1"],
            whoShouldRead: "Everyone",
            limitations: "None",
            citations: [],
            readTimeMinutes: 10,
            style: .full,
            extendedSummary: "Extended test summary"
        )
    }
    
    @Test("CacheService should cache and retrieve books")
    func testBookCaching() throws {
        let cacheService = CacheService.shared
        let testBook = createTestBook()
        let books = [testBook]
        
        // Clear cache first
        cacheService.clearAllCache()
        
        // Cache books
        try cacheService.cacheBooks(books)
        
        // Retrieve cached books
        let cachedBooks = try cacheService.getCachedBooks()
        #expect(cachedBooks?.count == 1)
        #expect(cachedBooks?.first?.id == testBook.id)
        #expect(cachedBooks?.first?.title == testBook.title)
    }
    
    @Test("CacheService should cache and retrieve individual book")
    func testIndividualBookCaching() throws {
        let cacheService = CacheService.shared
        let testBook = createTestBook(id: "individual-book")
        
        // Clear cache first
        cacheService.clearAllCache()
        
        // Cache individual book
        try cacheService.cacheBook(testBook)
        
        // Check if book is cached
        #expect(cacheService.isBookCached(id: testBook.id))
        
        // Retrieve cached book
        let cachedBook = try cacheService.getCachedBook(id: testBook.id)
        #expect(cachedBook?.id == testBook.id)
        #expect(cachedBook?.title == testBook.title)
    }
    
    @Test("CacheService should handle book removal")
    func testBookRemoval() throws {
        let cacheService = CacheService.shared
        let testBook = createTestBook(id: "removable-book")
        
        // Cache book first
        try cacheService.cacheBook(testBook)
        #expect(cacheService.isBookCached(id: testBook.id))
        
        // Remove cached book
        cacheService.removeCachedBook(id: testBook.id)
        #expect(!cacheService.isBookCached(id: testBook.id))
        
        // Verify book is not retrievable
        let cachedBook = try cacheService.getCachedBook(id: testBook.id)
        #expect(cachedBook == nil)
    }
    
    @Test("CacheService should cache and retrieve featured books")
    func testFeaturedBooksCaching() throws {
        let cacheService = CacheService.shared
        let featuredBooks = [createTestBook(id: "featured-1"), createTestBook(id: "featured-2")]
        
        // Clear cache first
        cacheService.clearAllCache()
        
        // Cache featured books
        try cacheService.cacheFeaturedBooks(featuredBooks)
        
        // Retrieve cached featured books
        let cachedFeaturedBooks = try cacheService.getCachedFeaturedBooks()
        #expect(cachedFeaturedBooks?.count == 2)
        #expect(cachedFeaturedBooks?.first?.id == featuredBooks.first?.id)
    }
    
    @Test("CacheService should cache and retrieve NYT bestseller books")
    func testNYTBestsellerBooksCaching() throws {
        let cacheService = CacheService.shared
        let nytBooks = [createTestBook(id: "nyt-1"), createTestBook(id: "nyt-2")]
        
        // Clear cache first
        cacheService.clearAllCache()
        
        // Cache NYT bestseller books
        try cacheService.cacheNYTBestsellerBooks(nytBooks)
        
        // Retrieve cached NYT bestseller books
        let cachedNYTBooks = try cacheService.getCachedNYTBestsellerBooks()
        #expect(cachedNYTBooks?.count == 2)
        #expect(cachedNYTBooks?.first?.id == nytBooks.first?.id)
    }
    
    @Test("CacheService should cache and retrieve summaries")
    func testSummaryCaching() throws {
        let cacheService = CacheService.shared
        let testSummary = createTestSummary()
        
        // Clear cache first
        cacheService.clearAllCache()
        
        // Cache summary
        try cacheService.cacheSummary(testSummary)
        
        // Check if summary is cached
        #expect(cacheService.isSummaryCached(bookId: testSummary.bookId))
        
        // Retrieve cached summary
        let cachedSummary = try cacheService.getCachedSummary(bookId: testSummary.bookId)
        #expect(cachedSummary?.id == testSummary.id)
        #expect(cachedSummary?.bookId == testSummary.bookId)
        #expect(cachedSummary?.oneSentenceHook == testSummary.oneSentenceHook)
    }
    
    @Test("CacheService should handle summary removal")
    func testSummaryRemoval() throws {
        let cacheService = CacheService.shared
        let testSummary = createTestSummary(bookId: "removable-summary")
        
        // Cache summary first
        try cacheService.cacheSummary(testSummary)
        #expect(cacheService.isSummaryCached(bookId: testSummary.bookId))
        
        // Remove cached summary
        cacheService.removeCachedSummary(bookId: testSummary.bookId)
        #expect(!cacheService.isSummaryCached(bookId: testSummary.bookId))
        
        // Verify summary is not retrievable
        let cachedSummary = try cacheService.getCachedSummary(bookId: testSummary.bookId)
        #expect(cachedSummary == nil)
    }
    
    @Test("CacheService should clear all cache")
    func testClearAllCache() throws {
        let cacheService = CacheService.shared
        let testBook = createTestBook()
        let testSummary = createTestSummary()
        
        // Cache some data
        try cacheService.cacheBook(testBook)
        try cacheService.cacheSummary(testSummary)
        
        // Verify data is cached
        #expect(cacheService.isBookCached(id: testBook.id))
        #expect(cacheService.isSummaryCached(bookId: testSummary.bookId))
        
        // Clear all cache
        cacheService.clearAllCache()
        
        // Verify cache is cleared
        #expect(!cacheService.isBookCached(id: testBook.id))
        #expect(!cacheService.isSummaryCached(bookId: testSummary.bookId))
    }
    
    @Test("CacheService should provide cache info")
    func testCacheInfo() throws {
        let cacheService = CacheService.shared
        
        // Clear cache first
        cacheService.clearAllCache()
        
        // Get initial cache info
        let initialInfo = cacheService.getCacheInfo()
        #expect(initialInfo.fileCount == 0)
        #expect(initialInfo.sizeInBytes == 0)
        
        // Cache some data
        let testBook = createTestBook()
        try cacheService.cacheBook(testBook)
        
        // Get updated cache info
        let updatedInfo = cacheService.getCacheInfo()
        #expect(updatedInfo.fileCount > 0)
        #expect(updatedInfo.sizeInBytes > 0)
        #expect(updatedInfo.formattedSize != "")
    }
    
    @Test("CacheService should handle missing cache files gracefully")
    func testMissingCacheFiles() throws {
        let cacheService = CacheService.shared
        
        // Clear cache first
        cacheService.clearAllCache()
        
        // Try to get non-existent cached data
        let cachedBooks = try cacheService.getCachedBooks()
        let cachedBook = try cacheService.getCachedBook(id: "nonexistent")
        let cachedSummary = try cacheService.getCachedSummary(bookId: "nonexistent")
        let cachedFeatured = try cacheService.getCachedFeaturedBooks()
        let cachedNYT = try cacheService.getCachedNYTBestsellerBooks()
        
        // All should return nil without throwing
        #expect(cachedBooks == nil)
        #expect(cachedBook == nil)
        #expect(cachedSummary == nil)
        #expect(cachedFeatured == nil)
        #expect(cachedNYT == nil)
        
        // Cache status checks should return false
        #expect(!cacheService.isBookCached(id: "nonexistent"))
        #expect(!cacheService.isSummaryCached(bookId: "nonexistent"))
    }
}