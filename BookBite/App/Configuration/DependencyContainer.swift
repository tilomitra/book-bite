import Foundation

@MainActor
class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()
    
    private let appConfig = AppConfiguration.shared
    
    lazy var bookRepository: BookRepository = createBookRepository()
    lazy var chatRepository: ChatRepository = createChatRepository()
    lazy var searchService = SearchService(repository: bookRepository)
    lazy var sharingService = SharingService.shared
    lazy var authService = SupabaseAuthService()
    
    private init() {}
    
    private func createBookRepository() -> BookRepository {
        // Simplified - always use RemoteBookRepository (HybridBookRepository now just wraps it)
        return HybridBookRepository()
    }
    
    private func createChatRepository() -> ChatRepository {
        return RemoteChatRepository()
    }
}
