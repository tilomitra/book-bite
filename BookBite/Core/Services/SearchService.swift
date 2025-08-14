import Foundation
import Combine

@MainActor
class SearchService: ObservableObject {
    private let repository: BookRepository
    private var searchTask: Task<Void, Never>?
    
    @Published var searchResults: [Book] = []
    @Published var isSearching = false
    @Published var searchError: Error?
    
    init(repository: BookRepository) {
        self.repository = repository
    }
    
    func search(query: String) {
        searchTask?.cancel()
        
        searchTask = Task {
            await performSearch(query: query)
        }
    }
    
    private func performSearch(query: String) async {
        isSearching = true
        searchError = nil
        
        do {
            let results = try await repository.searchBooks(query: query)
            
            if !Task.isCancelled {
                self.searchResults = results
            }
        } catch {
            if !Task.isCancelled {
                self.searchError = error
                self.searchResults = []
            }
        }
        
        isSearching = false
    }
    
    func loadAllBooks() async {
        isSearching = true
        searchError = nil
        
        do {
            let books = try await repository.fetchAllBooks()
            searchResults = books
        } catch {
            searchError = error
            searchResults = []
        }
        
        isSearching = false
    }
    
    func clearSearch() {
        searchTask?.cancel()
        searchResults = []
        searchError = nil
        isSearching = false
    }
}