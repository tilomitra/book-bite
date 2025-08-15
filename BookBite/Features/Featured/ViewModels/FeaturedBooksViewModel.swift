import Foundation
import Combine

@MainActor
class FeaturedBooksViewModel: ObservableObject {
    @Published var featuredBooks: [Book] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchText = ""
    
    private let bookRepository: BookRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(bookRepository: BookRepository) {
        self.bookRepository = bookRepository
        
        // Set up search debouncing
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.filterBooks()
            }
            .store(in: &cancellables)
        
        // Load featured books on initialization
        Task {
            await loadFeaturedBooks()
        }
    }
    
    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return featuredBooks
        }
        
        let lowercasedQuery = searchText.lowercased()
        return featuredBooks.filter { book in
            book.title.lowercased().contains(lowercasedQuery) ||
            book.authors.contains { $0.lowercased().contains(lowercasedQuery) } ||
            book.categories.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
    
    var showEmptyState: Bool {
        !isLoading && filteredBooks.isEmpty && !searchText.isEmpty
    }
    
    var showInitialState: Bool {
        !isLoading && featuredBooks.isEmpty && searchText.isEmpty
    }
    
    func loadFeaturedBooks() async {
        isLoading = true
        error = nil
        
        do {
            let books = try await bookRepository.fetchFeaturedBooks()
            featuredBooks = books
        } catch {
            self.error = error
            print("Failed to load featured books: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshFeaturedBooks() async {
        await loadFeaturedBooks()
    }
    
    private func filterBooks() {
        // Filtering is handled by computed property filteredBooks
        // This method exists for future enhancements if needed
    }
    
    func clearSearch() {
        searchText = ""
    }
    
    // MARK: - Book Actions
    
    func bookTapped(_ book: Book) {
        // This will be handled by the view through navigation
    }
}