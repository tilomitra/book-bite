import Foundation
import Combine

@MainActor
class SearchService: ObservableObject {
    private let repository: BookRepository
    private var searchTask: Task<Void, Never>?
    
    @Published var searchResults: [Book] = []
    @Published var isSearching = false
    @Published var isLoadingMore = false
    @Published var searchError: Error?
    @Published var hasMore = false
    
    private var currentPage = 1
    private var currentQuery = ""
    private let pageSize = 20
    
    init(repository: BookRepository) {
        self.repository = repository
    }
    
    func search(query: String) {
        searchTask?.cancel()
        
        // Reset pagination for new search
        currentPage = 1
        currentQuery = query
        searchResults = []
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Load initial books when no search query
            searchTask = Task {
                await loadInitialBooks()
            }
            return
        }
        
        searchTask = Task {
            await performSearch(query: query, page: 1, isNewSearch: true)
        }
    }
    
    private func performSearch(query: String, page: Int, isNewSearch: Bool = false) async {
        if isNewSearch {
            isSearching = true
        } else {
            isLoadingMore = true
        }
        searchError = nil
        
        do {
            // Use the search API endpoint which now supports pagination
            guard let url = URL(string: "\(AppConfiguration.shared.baseServerURL)/books/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&page=\(page)&limit=\(pageSize)") else {
                throw URLError(.badURL)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(PaginatedSearchResponse.self, from: data)
            
            if !Task.isCancelled {
                if isNewSearch {
                    searchResults = response.results
                } else {
                    searchResults.append(contentsOf: response.results)
                }
                hasMore = response.pagination?.hasMore ?? false
                currentPage = response.pagination?.page ?? page
            }
        } catch {
            if !Task.isCancelled {
                searchError = error
                if isNewSearch {
                    searchResults = []
                }
            }
        }
        
        isSearching = false
        isLoadingMore = false
    }
    
    func loadInitialBooks() async {
        isSearching = true
        searchError = nil
        currentQuery = ""
        currentPage = 1
        
        do {
            // Use the search endpoint with no query to get all books
            guard let url = URL(string: "\(AppConfiguration.shared.baseServerURL)/books/search?page=1&limit=\(pageSize)") else {
                throw URLError(.badURL)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(PaginatedSearchResponse.self, from: data)
            
            if !Task.isCancelled {
                searchResults = response.results
                hasMore = response.pagination?.hasMore ?? false
                currentPage = response.pagination?.page ?? 1
            }
        } catch {
            if !Task.isCancelled {
                searchError = error
                searchResults = []
            }
        }
        
        isSearching = false
    }
    
    func loadMoreBooks() async {
        guard hasMore && !isLoadingMore && !isSearching else { return }
        
        let nextPage = currentPage + 1
        
        if currentQuery.isEmpty {
            // Loading more from all books
            await loadMoreAllBooks(page: nextPage)
        } else {
            // Loading more search results
            await performSearch(query: currentQuery, page: nextPage, isNewSearch: false)
        }
    }
    
    private func loadMoreAllBooks(page: Int) async {
        isLoadingMore = true
        searchError = nil
        
        do {
            guard let url = URL(string: "\(AppConfiguration.shared.baseServerURL)/books/search?page=\(page)&limit=\(pageSize)") else {
                throw URLError(.badURL)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(PaginatedSearchResponse.self, from: data)
            
            if !Task.isCancelled {
                searchResults.append(contentsOf: response.results)
                hasMore = response.pagination?.hasMore ?? false
                currentPage = response.pagination?.page ?? page
            }
        } catch {
            if !Task.isCancelled {
                searchError = error
            }
        }
        
        isLoadingMore = false
    }
    
    func performSearchAsync(query: String) async {
        await performSearch(query: query, page: 1, isNewSearch: true)
    }
    
    func clearSearch() {
        searchTask?.cancel()
        searchResults = []
        searchError = nil
        isSearching = false
        isLoadingMore = false
        hasMore = false
        currentPage = 1
        currentQuery = ""
    }
    
    // Helper to check if we should load more when user scrolls to a book
    func shouldLoadMore(for book: Book) -> Bool {
        guard hasMore, !isLoadingMore, !isSearching else { return false }
        
        // Load more when user reaches the last 5 items
        guard let index = searchResults.firstIndex(where: { $0.id == book.id }) else { return false }
        return index >= searchResults.count - 5
    }
}