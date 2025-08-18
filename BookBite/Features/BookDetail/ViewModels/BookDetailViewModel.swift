import Foundation
import Combine

@MainActor
class BookDetailViewModel: ObservableObject {
    @Published var book: Book
    @Published var summary: Summary?
    @Published var isLoadingSummary = false
    @Published var summaryError: Error?
    @Published var selectedTab = 0
    @Published var rating: BookRating?
    @Published var isLoadingRating = false
    
    private let repository: BookRepository
    private let ratingsService: RatingsService
    
    init(book: Book, repository: BookRepository) {
        self.book = book
        self.repository = repository
        self.ratingsService = DependencyContainer.shared.ratingsService
        
        Task {
            await loadSummary()
            await loadRating()
        }
    }
    
    func loadSummary() async {
        isLoadingSummary = true
        summaryError = nil
        
        do {
            summary = try await repository.fetchSummary(for: book.id)
        } catch {
            summaryError = error
        }
        
        isLoadingSummary = false
    }
    
    func regenerateSummary() async {
        isLoadingSummary = true
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await loadSummary()
    }
    
    func loadRating() async {
        isLoadingRating = true
        
        rating = await ratingsService.getRatingForBook(book)
        
        isLoadingRating = false
    }
    
    var readingTime: String {
        guard let summary = summary else { return "Calculating..." }
        return "\(summary.readTimeMinutes) min read"
    }
    
    var publicationInfo: String {
        var info = book.publishedYear.map { "\($0)" } ?? "Unknown"
        if let publisher = book.publisher {
            info += " • \(publisher)"
        }
        return info
    }
}