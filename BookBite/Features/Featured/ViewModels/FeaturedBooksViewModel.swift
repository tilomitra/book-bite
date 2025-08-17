import Foundation
import Combine

@MainActor
class FeaturedBooksViewModel: ObservableObject {
    @Published var featuredBooks: [Book] = []
    @Published var nytBestsellerBooks: [Book] = []
    @Published var booksByGenre: [(genre: String, books: [Book])] = []
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
    
    var allBooks: [Book] {
        return featuredBooks + nytBestsellerBooks
    }
    
    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return allBooks
        }
        
        let lowercasedQuery = searchText.lowercased()
        return allBooks.filter { book in
            book.title.lowercased().contains(lowercasedQuery) ||
            book.authors.contains { $0.lowercased().contains(lowercasedQuery) } ||
            book.categories.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
    
    var showEmptyState: Bool {
        !isLoading && filteredBooks.isEmpty && !searchText.isEmpty
    }
    
    var showInitialState: Bool {
        !isLoading && allBooks.isEmpty && searchText.isEmpty
    }
    
    func loadFeaturedBooks() async {
        isLoading = true
        error = nil
        
        // Clear cache to ensure fresh data
        bookRepository.clearCache()
        
        do {
            // Fetch both featured books and NYT bestsellers
            async let featuredBooksTask = bookRepository.fetchFeaturedBooks()
            async let nytBooksTask = bookRepository.fetchNYTBestsellerBooks()
            
            let (featured, nytBooks) = try await (featuredBooksTask, nytBooksTask)
            
            featuredBooks = featured
            nytBestsellerBooks = nytBooks
            groupBooksByGenre()
        } catch {
            // Don't show cancellation errors to user - they're expected during rapid refreshes
            if error is CancellationError {
                print("Request cancelled: \(error)")
            } else {
                self.error = error
                print("Failed to load books: \(error)")
            }
        }
        
        isLoading = false
    }
    
    private func groupBooksByGenre() {
        // Create genre groups based on categories
        var genreMap: [String: [Book]] = [:]
        
        // Predefined genre sections for NYT bestsellers to ensure consistent ordering
        let primaryGenres = [
            "Business",
            "Self-Help",
            "Biography",
            "Science",
            "Politics",
            "Health",
            "History",
            "Psychology"
        ]
        
        // Map books to genres based on their categories
        for book in allBooks {
            for category in book.categories {
                // Map categories to main genres
                let mainGenre = mapCategoryToGenre(category)
                if genreMap[mainGenre] == nil {
                    genreMap[mainGenre] = []
                }
                if !genreMap[mainGenre]!.contains(where: { $0.id == book.id }) {
                    genreMap[mainGenre]!.append(book)
                }
            }
        }
        
        // Create ordered genre list
        var orderedGenres: [(genre: String, books: [Book])] = []
        
        // Add primary genres first (if they have books)
        for genre in primaryGenres {
            if let books = genreMap[genre], !books.isEmpty {
                orderedGenres.append((genre: genre, books: books))
                genreMap.removeValue(forKey: genre)
            }
        }
        
        // Add any remaining genres
        for (genre, books) in genreMap.sorted(by: { $0.key < $1.key }) {
            if !books.isEmpty {
                orderedGenres.append((genre: genre, books: books))
            }
        }
        
        booksByGenre = orderedGenres
    }
    
    private func mapCategoryToGenre(_ category: String) -> String {
        let lowercased = category.lowercased()
        
        // Map specific categories to main NYT genres
        if lowercased.contains("business") || lowercased.contains("management") ||
           lowercased.contains("leadership") || lowercased.contains("entrepreneur") ||
           lowercased.contains("strategy") || lowercased.contains("corporate") {
            return "Business"
        } else if lowercased.contains("self-help") || lowercased.contains("self help") ||
                  lowercased.contains("personal") || lowercased.contains("productivity") ||
                  lowercased.contains("habit") || lowercased.contains("improvement") {
            return "Self-Help"
        } else if lowercased.contains("biography") || lowercased.contains("memoir") ||
                  lowercased.contains("life") && (lowercased.contains("story") || lowercased.contains("journey")) {
            return "Biography"
        } else if lowercased.contains("science") || lowercased.contains("physics") ||
                  lowercased.contains("biology") || lowercased.contains("chemistry") ||
                  lowercased.contains("technology") || lowercased.contains("engineering") {
            return "Science"
        } else if lowercased.contains("politics") || lowercased.contains("government") ||
                  lowercased.contains("democracy") || lowercased.contains("election") {
            return "Politics"
        } else if lowercased.contains("health") || lowercased.contains("medicine") ||
                  lowercased.contains("fitness") || lowercased.contains("nutrition") ||
                  lowercased.contains("wellness") {
            return "Health"
        } else if lowercased.contains("history") || lowercased.contains("historical") ||
                  lowercased.contains("war") || lowercased.contains("ancient") {
            return "History"
        } else if lowercased.contains("psychology") || lowercased.contains("mental") ||
                  lowercased.contains("mind") || lowercased.contains("behavior") ||
                  lowercased.contains("social science") {
            return "Psychology"
        } else {
            // Return the original category if it doesn't match any mapping
            return category
        }
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