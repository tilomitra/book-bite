import Foundation
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [Book] = []
    @Published var isSearching = false
    @Published var searchError: Error?
    
    private let searchService: SearchService
    private var cancellables = Set<AnyCancellable>()
    
    init(searchService: SearchService) {
        self.searchService = searchService
        setupBindings()
        
        Task {
            await loadInitialBooks()
        }
    }
    
    private func setupBindings() {
        searchService.$searchResults
            .assign(to: &$searchResults)
        
        searchService.$isSearching
            .assign(to: &$isSearching)
        
        searchService.$searchError
            .assign(to: &$searchError)
    }
    
    private func loadInitialBooks() async {
        await searchService.loadAllBooks()
    }
    
    func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchService.clearSearch()
            return
        }
        await searchService.performSearchAsync(query: searchText)
    }
    
    func clearSearch() {
        searchText = ""
        searchService.clearSearch()
    }
    
    var hasResults: Bool {
        !searchResults.isEmpty
    }
    
    var showEmptyState: Bool {
        !isSearching && searchResults.isEmpty && !searchText.isEmpty
    }
    
    var showInitialState: Bool {
        !isSearching && searchResults.isEmpty && searchText.isEmpty
    }
}