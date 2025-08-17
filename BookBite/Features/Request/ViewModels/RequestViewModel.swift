import Foundation
import Combine

@MainActor
class RequestViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var requestState = RequestState.idle
    @Published var searchError: String?
    
    private let networkService: NetworkService
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    
    init(networkService: NetworkService = NetworkService.shared) {
        self.networkService = networkService
    }
    
    func searchBooks(query: String) {
        // Cancel any existing search
        searchTask?.cancel()
        
        // Clear previous error
        searchError = nil
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            requestState = .idle
            return
        }
        
        requestState = .searching
        
        searchTask = Task {
            do {
                let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                let encodedQuery = trimmedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedQuery
                
                let response: GoogleBookSearchResponse = try await networkService.get(
                    endpoint: "search/books?q=\(encodedQuery)"
                )
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                requestState = .searchResults(response.results)
                
            } catch {
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                let errorMessage = handleNetworkError(error)
                searchError = errorMessage
                requestState = .error(errorMessage)
            }
        }
    }
    
    func requestBook(_ searchResult: GoogleBookSearchResult) {
        // Prevent requesting if already in database
        guard !searchResult.inDatabase else {
            searchError = "This book is already in the database"
            return
        }
        
        requestState = .requestingBook(searchResult)
        searchError = nil
        
        Task {
            do {
                let payload = BookRequestPayload(googleBooksId: searchResult.googleBooksId)
                
                let response: BookRequestResponse = try await networkService.post(
                    endpoint: "search/request",
                    body: payload
                )
                
                requestState = .bookRequested(response.book)
                
            } catch {
                let errorMessage = handleNetworkError(error)
                searchError = errorMessage
                requestState = .error(errorMessage)
            }
        }
    }
    
    func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        requestState = .idle
        searchError = nil
    }
    
    func resetToSearchResults() {
        if case .searchResults(_) = requestState {
            // Already at search results, do nothing
            return
        }
        
        // If we have a previous search, re-run it
        if !searchText.isEmpty {
            searchBooks(query: searchText)
        } else {
            requestState = .idle
        }
    }
    
    private func handleNetworkError(_ error: Error) -> String {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .clientError(let code, _):
                if code == 409 {
                    return "This book is already in the database"
                } else if code == 404 {
                    return "Book not found"
                } else {
                    return "Request failed. Please try again."
                }
            case .serverError(_):
                return "Server error. Please try again later."
            case .networkFailure(_):
                return "Network error. Please check your connection."
            default:
                return "An unexpected error occurred. Please try again."
            }
        }
        return error.localizedDescription
    }
    
    // Computed properties for view state
    var isSearching: Bool {
        if case .searching = requestState {
            return true
        }
        return false
    }
    
    var isRequestingBook: Bool {
        if case .requestingBook(_) = requestState {
            return true
        }
        return false
    }
    
    var searchResults: [GoogleBookSearchResult] {
        if case .searchResults(let results) = requestState {
            return results
        }
        return []
    }
    
    var hasSearchResults: Bool {
        !searchResults.isEmpty
    }
    
    var showEmptySearchState: Bool {
        if case .searchResults(let results) = requestState {
            return results.isEmpty
        }
        return false
    }
    
    var showInitialState: Bool {
        if case .idle = requestState {
            return true
        }
        return false
    }
    
    var requestedBook: Book? {
        if case .bookRequested(let book) = requestState {
            return book
        }
        return nil
    }
    
    var requestingBookResult: GoogleBookSearchResult? {
        if case .requestingBook(let result) = requestState {
            return result
        }
        return nil
    }
}