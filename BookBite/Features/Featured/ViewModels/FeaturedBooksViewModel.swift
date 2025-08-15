import Foundation
import Combine

@MainActor
class FeaturedBooksViewModel: ObservableObject {
    @Published var featuredBooks: [Book] = []
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
            groupBooksByGenre()
        } catch {
            // Don't show cancellation errors to user - they're expected during rapid refreshes
            if error is CancellationError {
                print("Request cancelled: \(error)")
            } else {
                self.error = error
                print("Failed to load featured books: \(error)")
            }
        }
        
        isLoading = false
    }
    
    private func groupBooksByGenre() {
        // Create genre groups based on categories
        var genreMap: [String: [Book]] = [:]
        
        // Predefined genre sections to ensure consistent ordering
        let primaryGenres = [
            "Software Development",
            "Management & Leadership",
            "Business Strategy",
            "Personal Development",
            "Technology & Innovation",
            "Entrepreneurship",
            "Product Management",
            "Data & Analytics"
        ]
        
        // Map books to genres based on their categories
        for book in featuredBooks {
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
        
        // Map specific categories to main genres
        if lowercased.contains("software") || lowercased.contains("programming") || 
           lowercased.contains("coding") || lowercased.contains("development") ||
           lowercased.contains("engineering") || lowercased.contains("agile") {
            return "Software Development"
        } else if lowercased.contains("management") || lowercased.contains("leadership") ||
                  lowercased.contains("team") || lowercased.contains("manager") {
            return "Management & Leadership"
        } else if lowercased.contains("business") || lowercased.contains("strategy") ||
                  lowercased.contains("corporate") {
            return "Business Strategy"
        } else if lowercased.contains("personal") || lowercased.contains("self") ||
                  lowercased.contains("productivity") || lowercased.contains("habit") {
            return "Personal Development"
        } else if lowercased.contains("technology") || lowercased.contains("innovation") ||
                  lowercased.contains("digital") || lowercased.contains("tech") {
            return "Technology & Innovation"
        } else if lowercased.contains("entrepreneur") || lowercased.contains("startup") ||
                  lowercased.contains("founder") {
            return "Entrepreneurship"
        } else if lowercased.contains("product") || lowercased.contains("design") ||
                  lowercased.contains("ux") {
            return "Product Management"
        } else if lowercased.contains("data") || lowercased.contains("analytics") ||
                  lowercased.contains("metrics") || lowercased.contains("statistics") {
            return "Data & Analytics"
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