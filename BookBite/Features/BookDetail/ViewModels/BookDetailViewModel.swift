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
    @Published var isGeneratingSummary = false
    @Published var generationMessage = "Generating summary..."
    @Published var isFavorite = false
    @Published var isLoadingFavorite = false
    @Published var isDownloadingForOffline = false
    @Published var isAvailableOffline = false
    
    private let repository: BookRepository
    private var pollingTask: Task<Void, Never>?
    
    init(book: Book, repository: BookRepository) {
        self.book = book
        self.repository = repository
        // Here, not in a task: a book read before is on the page in the first frame, and refreshes behind it
        summary = (try? CacheService.shared.getCachedSummary(bookId: book.id))
            ?? OfflineStorageService.shared.getOfflineSummary(bookId: book.id)

        Task {
            async let summaryLoad: Void = loadSummary()
            async let favoriteLoad: Void = loadFavoriteStatus()
            _ = await (summaryLoad, favoriteLoad)
            loadOfflineStatus()
        }
    }
    
    deinit {
        pollingTask?.cancel()
    }
    
    func loadSummary() async {
        // With a cached summary on the page, this is a quiet refresh
        let hasCachedSummary = summary != nil
        isLoadingSummary = !hasCachedSummary
        summaryError = nil
        
        do {
            if let fresh = try await repository.fetchSummary(for: book.id) {
                summary = fresh
            }
        } catch let error as NetworkError {
            if case .clientError(404, _) = error {
                // 404 means no summary exists, this is not an error state
                // We'll show the generate button instead
                summaryError = nil
            } else if !hasCachedSummary {
                summaryError = error
            }
        } catch {
            if !hasCachedSummary { summaryError = error }
        }
        
        isLoadingSummary = false
    }
    
    func generateSummary() async {
        if AppConfiguration.shared.isLoggingEnabled {
            print("📚 BookDetailViewModel: generateSummary called for book \(book.id)")
        }
        await triggerSummaryGeneration()
    }
    
    func regenerateSummary() async {
        isLoadingSummary = true
        
        await triggerSummaryGeneration()
    }
    
    private func triggerSummaryGeneration() async {
        if AppConfiguration.shared.isLoggingEnabled {
            print("📚 BookDetailViewModel: triggerSummaryGeneration started")
        }
        
        // Check if repository supports summary generation (both RemoteBookRepository and HybridBookRepository do)
        guard let summaryRepository = repository as? (any SummaryGenerationCapable) else {
            if AppConfiguration.shared.isLoggingEnabled {
                print("❌ BookDetailViewModel: Repository does not support SummaryGenerationCapable")
            }
            summaryError = SummaryError.generationFailed
            isLoadingSummary = false
            return
        }
        
        if AppConfiguration.shared.isLoggingEnabled {
            print("✅ BookDetailViewModel: Repository supports SummaryGenerationCapable")
        }
        
        isLoadingSummary = true
        isGeneratingSummary = true
        generationMessage = "Generating summary..."
        summaryError = nil
        
        do {
            if AppConfiguration.shared.isLoggingEnabled {
                print("📚 BookDetailViewModel: Calling generateSummary API for book \(book.id)")
            }
            let job = try await summaryRepository.generateSummary(for: book.id, style: .full)
            if AppConfiguration.shared.isLoggingEnabled {
                print("✅ BookDetailViewModel: Got job ID \(job.id), starting polling")
            }
            if job.status == .completed {
                // Summary already exists: load it directly instead of polling
                summary = try await repository.fetchSummary(for: book.id)
                isLoadingSummary = false
                isGeneratingSummary = false
            } else {
                await pollForSummaryCompletion(jobId: job.id)
            }
        } catch {
            if AppConfiguration.shared.isLoggingEnabled {
                print("❌ BookDetailViewModel: Error generating summary: \(error)")
            }
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
    
    /// "2018 · 12 min read": the year, plus the summary's read time once it has loaded
    var metadataLine: String {
        var parts: [String] = []
        if let year = book.publishedYear {
            parts.append(String(year))
        }
        if let summary = summary {
            parts.append("\(summary.summaryReadTimeMinutes) min read")
        }
        return parts.joined(separator: " · ")
    }
    
    // MARK: - Favorite Management
    
    func loadFavoriteStatus() async {
        guard let favoriteRepository = repository as? FavoriteRepository else {
            // If repository doesn't support favorites, assume not favorite
            isFavorite = false
            return
        }
        
        isLoadingFavorite = true
        
        do {
            isFavorite = try await favoriteRepository.checkFavoriteStatus(for: book.id)
        } catch {
            // On error, assume not favorite
            isFavorite = false
            if AppConfiguration.shared.isLoggingEnabled {
                print("❌ Error loading favorite status: \(error)")
            }
        }
        
        isLoadingFavorite = false
    }
    
    /// After signing in from the Save prompt: saves the book, unless the account has it already
    func saveAfterSignIn() async {
        await loadFavoriteStatus()
        if !isFavorite {
            await toggleFavorite()
        }
    }

    func toggleFavorite() async {
        guard let favoriteRepository = repository as? FavoriteRepository else {
            if AppConfiguration.shared.isLoggingEnabled {
                print("❌ Repository does not support FavoriteRepository protocol")
            }
            return
        }

        let previousState = isFavorite
        isLoadingFavorite = true

        do {
            if isFavorite {
                try await favoriteRepository.removeFromFavorites(book.id)
                isFavorite = false
                if AppConfiguration.shared.isLoggingEnabled {
                    print("✅ Removed book \(book.title) from favorites")
                }
                // Note: We intentionally do NOT remove offline data when unfavoriting
                // User may re-favorite later
            } else {
                try await favoriteRepository.addToFavorites(book.id)
                isFavorite = true
                Analytics.capture(.bookSaved(book))
                if AppConfiguration.shared.isLoggingEnabled {
                    print("✅ Added book \(book.title) to favorites")
                }

                // Trigger offline download in background (don't block/fail the favorite action)
                let bookToDownload = book
                Task {
                    await downloadForOffline(book: bookToDownload, favoriteRepository: favoriteRepository)
                }
            }
        } catch {
            // Revert state on error
            isFavorite = previousState
            if AppConfiguration.shared.isLoggingEnabled {
                print("❌ Error toggling favorite status: \(error)")
            }
        }

        isLoadingFavorite = false
    }

    // MARK: - Offline Management

    func loadOfflineStatus() {
        isAvailableOffline = OfflineStorageService.shared.isBookDownloadedForOffline(book.id)
    }

    private func downloadForOffline(book: Book, favoriteRepository: FavoriteRepository) async {
        isDownloadingForOffline = true

        do {
            try await favoriteRepository.downloadFavoriteForOffline(book)
            isAvailableOffline = true
            if AppConfiguration.shared.isLoggingEnabled {
                print("✅ Book \(book.title) downloaded for offline access")
            }
        } catch {
            // Log but don't fail - offline download is a nice-to-have
            if AppConfiguration.shared.isLoggingEnabled {
                print("⚠️ Failed to download book for offline: \(error)")
            }
        }

        isDownloadingForOffline = false
    }
}