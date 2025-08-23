import Foundation

@MainActor
class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()
    
    private let appConfig = AppConfiguration.shared
    
    lazy var bookRepository: BookRepository = createBookRepository()
    lazy var chatRepository: ChatRepository = createChatRepository()
    lazy var searchService = SearchService(repository: bookRepository)
    lazy var exportService = ExportService()
    lazy var ratingsService = RatingsService(
        networkService: NetworkService.shared,
        cacheService: CacheService.shared
    )
    lazy var onboardingService = OnboardingService()
    
    private init() {}
    
    private func createBookRepository() -> BookRepository {
        // Simplified - always use RemoteBookRepository (HybridBookRepository now just wraps it)
        return HybridBookRepository()
    }
    
    private func createChatRepository() -> ChatRepository {
        return RemoteChatRepository()
    }
    
    // For testing or manual switching
    func switchToRemoteRepository() {
        bookRepository = RemoteBookRepository()
        searchService = SearchService(repository: bookRepository)
        objectWillChange.send()
    }
    
    func switchToHybridRepository() {
        bookRepository = HybridBookRepository()
        searchService = SearchService(repository: bookRepository)
        objectWillChange.send()
    }
}