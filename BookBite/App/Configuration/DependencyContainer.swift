import Foundation

@MainActor
class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()
    
    private let appConfig = AppConfiguration.shared
    
    lazy var bookRepository: BookRepository = createBookRepository()
    lazy var searchService = SearchService(repository: bookRepository)
    lazy var sharingService = SharingService.shared
    lazy var authService = SupabaseAuthService()
    
    private init() {}
    
    private func createBookRepository() -> BookRepository {
        // Wraps RemoteBookRepository and reads the copies on the device when offline
        return HybridBookRepository()
    }
}
