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
    /// The query the latest search was started for, so the empty state waits for the debounce
    @Published private var lastSearchedQuery = ""
    private var cancellables = Set<AnyCancellable>()
    
    init(searchService: SearchService) {
        self.searchService = searchService
        setupBindings()
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

        // Search as the user types
        $searchText
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                self.lastSearchedQuery = query
                if query.isEmpty {
                    self.searchService.clearSearch()
                } else {
                    self.searchService.search(query: query)
                }
            }
            .store(in: &cancellables)
    }
    
    func performSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        lastSearchedQuery = query
        searchService.search(query: query)
    }
    
    func loadMoreBooks() async {
        await searchService.loadMoreBooks()
    }
    
    // Check if we should load more books when a book appears
    func onBookAppear(_ book: Book) {
        if searchService.shouldLoadMore(for: book) {
            Task {
                await loadMoreBooks()
            }
        }
    }
    
    var isQueryEmpty: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// True while the user is typing and the debounced search has not started yet
    var isPending: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines) != lastSearchedQuery
    }
    
    var showEmptyState: Bool {
        !isSearching && !isPending && searchError == nil && searchResults.isEmpty && !isQueryEmpty
    }
}
