import Foundation

@MainActor
class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()
    
    private let appConfig = AppConfiguration.shared
    
    lazy var bookRepository: BookRepository = createBookRepository()
    lazy var searchService = SearchService(repository: bookRepository)
    lazy var exportService = ExportService()
    
    private init() {}
    
    private func createBookRepository() -> BookRepository {
        // Simplified - always use RemoteBookRepository (HybridBookRepository now just wraps it)
        return HybridBookRepository()
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