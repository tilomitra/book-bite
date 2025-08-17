import Foundation
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [Book] = []
    @Published var isSearching = false
    @Published var isLoadingMore = false
    @Published var searchError: Error?
    @Published var hasMore = false
    
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
        
        searchService.$isLoadingMore
            .assign(to: &$isLoadingMore)
        
        searchService.$hasMore
            .assign(to: &$hasMore)
        
        searchService.$searchError
            .assign(to: &$searchError)
    }
    
    private func loadInitialBooks() async {
        await searchService.loadInitialBooks()
    }
    
    func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await searchService.loadInitialBooks()
            return
        }
        searchService.search(query: searchText)
    }
    
    func loadMoreBooks() async {
        await searchService.loadMoreBooks()
    }
    
    func clearSearch() {
        searchText = ""
        searchService.clearSearch()
        Task {
            await loadInitialBooks()
        }
    }
    
    // Check if we should load more books when a book appears
    func onBookAppear(_ book: Book) {
        if searchService.shouldLoadMore(for: book) {
            Task {
                await loadMoreBooks()
            }
        }
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