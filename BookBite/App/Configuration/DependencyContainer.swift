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
        switch appConfig.currentDataSource {
        case .local:
            return LocalBookRepository()
        case .remote:
            return RemoteBookRepository()
        case .hybrid:
            return HybridBookRepository()
        }
    }
    
    // For testing or manual switching
    func switchToLocalRepository() {
        bookRepository = LocalBookRepository()
        searchService = SearchService(repository: bookRepository)
        objectWillChange.send()
    }
    
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