import Foundation

class RatingsService: ObservableObject {
    private let networkService: NetworkService
    private let cacheService: CacheService
    private let ratingsCache = NSCache<NSString, BookRating>()
    
    init(networkService: NetworkService, cacheService: CacheService) {
        self.networkService = networkService
        self.cacheService = cacheService
        
        // Configure cache
        ratingsCache.countLimit = 200 // Cache up to 200 ratings
        ratingsCache.totalCostLimit = 1024 * 1024 // 1MB limit
    }
    
    func fetchRating(for bookId: String) async -> BookRating? {
        // Check memory cache first
        let cacheKey = NSString(string: "rating_\(bookId)")
        if let cachedRating = ratingsCache.object(forKey: cacheKey) {
            return cachedRating
        }
        
        // Fetch from network
        do {
            let response: BookRatingResponse = try await networkService.get(endpoint: "books/\(bookId)/ratings")
            let rating = response.rating
            
            // Cache the result in memory
            ratingsCache.setObject(rating, forKey: cacheKey)
            
            return rating
        } catch {
            print("Failed to fetch rating for book \(bookId): \(error)")
            return nil
        }
    }
    
    func fetchRatingByISBN(_ isbn: String) async -> BookRating? {
        // Check memory cache first
        let cacheKey = NSString(string: "isbn_rating_\(isbn)")
        if let cachedRating = ratingsCache.object(forKey: cacheKey) {
            return cachedRating
        }
        
        // Fetch from network
        do {
            let response: BookRatingResponse = try await networkService.get(endpoint: "isbn/\(isbn)/ratings")
            let rating = response.rating
            
            // Cache the result in memory
            ratingsCache.setObject(rating, forKey: cacheKey)
            
            return rating
        } catch {
            print("Failed to fetch rating for ISBN \(isbn): \(error)")
            return nil
        }
    }
    
    func clearCache() {
        ratingsCache.removeAllObjects()
    }
    
    // Extension to add ratings support to existing repositories
    func getRatingForBook(_ book: Book) async -> BookRating? {
        // Try to fetch by book ID first
        if let rating = await fetchRating(for: book.id) {
            return rating
        }
        
        // If no rating found by ID, try ISBN13, then ISBN10
        if let isbn13 = book.isbn13 {
            if let rating = await fetchRatingByISBN(isbn13) {
                return rating
            }
        }
        
        if let isbn10 = book.isbn10 {
            if let rating = await fetchRatingByISBN(isbn10) {
                return rating
            }
        }
        
        return nil
    }
}