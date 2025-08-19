import Foundation
import Combine

enum SummaryError: LocalizedError {
    case notAvailable
    case generationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Summary not available for this book yet"
        case .generationFailed:
            return "Failed to generate summary. Please try again."
        }
    }
}

@MainActor
class BookDetailViewModel: ObservableObject {
    @Published var book: Book
    @Published var summary: Summary?
    @Published var isLoadingSummary = false
    @Published var summaryError: Error?
    @Published var selectedTab = 0
    @Published var rating: BookRating?
    @Published var isLoadingRating = false
    @Published var isGeneratingSummary = false
    @Published var generationMessage = "Generating summary..."
    
    private let repository: BookRepository
    private let ratingsService: RatingsService
    private var pollingTask: Task<Void, Never>?
    
    init(book: Book, repository: BookRepository) {
        self.book = book
        self.repository = repository
        self.ratingsService = DependencyContainer.shared.ratingsService
        
        Task {
            await loadSummary()
            await loadRating()
        }
    }
    
    deinit {
        pollingTask?.cancel()
    }
    
    func loadSummary() async {
        isLoadingSummary = true
        summaryError = nil
        
        do {
            summary = try await repository.fetchSummary(for: book.id)
            if summary == nil {
                await triggerSummaryGeneration()
            }
        } catch let error as NetworkError {
            if case .clientError(404, _) = error {
                await triggerSummaryGeneration()
            } else {
                summaryError = error
                isLoadingSummary = false
            }
        } catch {
            summaryError = error
            isLoadingSummary = false
        }
        
        if summary != nil {
            isLoadingSummary = false
        }
    }
    
    func regenerateSummary() async {
        isLoadingSummary = true
        
        await triggerSummaryGeneration()
    }
    
    private func triggerSummaryGeneration() async {
        // Check if repository supports summary generation (both RemoteBookRepository and HybridBookRepository do)
        guard let summaryRepository = repository as? (any SummaryGenerationCapable) else {
            summaryError = SummaryError.generationFailed
            isLoadingSummary = false
            return
        }
        
        isGeneratingSummary = true
        generationMessage = "Generating summary..."
        
        do {
            let job = try await summaryRepository.generateSummary(for: book.id, style: .full)
            await pollForSummaryCompletion(jobId: job.id)
        } catch {
            summaryError = SummaryError.generationFailed
            isLoadingSummary = false
            isGeneratingSummary = false
        }
    }
    
    private func pollForSummaryCompletion(jobId: String) async {
        guard let summaryRepository = repository as? (any SummaryGenerationCapable) else {
            summaryError = SummaryError.generationFailed
            isLoadingSummary = false
            isGeneratingSummary = false
            return
        }
        
        pollingTask?.cancel()
        pollingTask = Task {
            var attempts = 0
            let maxAttempts = 60 // 5 minutes max (5 second intervals)
            
            while attempts < maxAttempts && !Task.isCancelled {
                do {
                    let job = try await summaryRepository.checkSummaryGenerationJob(jobId: jobId)
                    
                    switch job.status {
                    case .completed:
                        generationMessage = "Summary generated successfully!"
                        try? await Task.sleep(nanoseconds: 500_000_000) // Brief delay to show success message
                        
                        // Fetch the newly generated summary
                        do {
                            summary = try await repository.fetchSummary(for: book.id)
                            isLoadingSummary = false
                            isGeneratingSummary = false
                            summaryError = nil
                        } catch {
                            summaryError = SummaryError.generationFailed
                            isLoadingSummary = false
                            isGeneratingSummary = false
                        }
                        return
                        
                    case .failed:
                        summaryError = SummaryError.generationFailed
                        isLoadingSummary = false
                        isGeneratingSummary = false
                        return
                        
                    case .processing:
                        generationMessage = "Processing book content..."
                        
                    case .pending:
                        generationMessage = "Queued for processing..."
                    }
                    
                    attempts += 1
                    try await Task.sleep(nanoseconds: 5_000_000_000) // Wait 5 seconds
                    
                } catch {
                    attempts += 1
                    if attempts >= maxAttempts {
                        summaryError = SummaryError.generationFailed
                        isLoadingSummary = false
                        isGeneratingSummary = false
                        return
                    }
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                }
            }
            
            // Timeout case
            if !Task.isCancelled {
                summaryError = SummaryError.generationFailed
                isLoadingSummary = false
                isGeneratingSummary = false
            }
        }
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