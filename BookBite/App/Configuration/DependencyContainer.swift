import Foundation

@MainActor
class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()
    
    lazy var bookRepository: BookRepository = LocalBookRepository()
    lazy var searchService = SearchService(repository: bookRepository)
    lazy var exportService = ExportService()
    
    private init() {}
}