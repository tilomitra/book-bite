import Foundation
import Combine

@MainActor
class FeaturedBooksViewModel: ObservableObject {
    @Published var featuredBooks: [Book] = []
    @Published var nytBestsellerBooks: [Book] = []
    @Published var noteworthyBooks: [Book] = []
    @Published var booksByGenre: [(genre: String, books: [Book])] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchText = ""
    
    private let bookRepository: BookRepository
    private var cancellables = Set<AnyCancellable>()
    private var allPopularBooks: [Book] = []
    
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
            
            // Store all popular books for the noteworthy section
            allPopularBooks = (featured + nytBooks).filter { book in
                // Include books with popularity score or NYT bestseller status
                book.popularityScore != nil || book.isNYTBestseller == true
            }
            
            // Select random noteworthy books
            selectNoteworthyBooks()
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
    
    private func selectNoteworthyBooks() {
        // Select 8-10 random books from popular books
        let numberOfBooks = Int.random(in: 8...10)
        
        // Sort by popularity score to get truly popular books
        let sortedPopularBooks = allPopularBooks.sorted { book1, book2 in
            // Prioritize books with higher popularity scores
            if let score1 = book1.popularityScore, let score2 = book2.popularityScore {
                return score1 > score2
            }
            // NYT bestsellers next
            if book1.isNYTBestseller == true && book2.isNYTBestseller != true {
                return true
            }
            if book1.isNYTBestseller != true && book2.isNYTBestseller == true {
                return false
            }
            // Random for others
            return Bool.random()
        }
        
        // Take top popular books and shuffle them for variety
        let topBooks = Array(sortedPopularBooks.prefix(min(30, sortedPopularBooks.count)))
        noteworthyBooks = Array(topBooks.shuffled().prefix(numberOfBooks))
    }
    
    private func groupBooksByGenre() {
        // Create genre groups based on categories
        var genreMap: [String: [Book]] = [:]
        
        // Predefined genre sections for NYT bestsellers to ensure consistent ordering
        let primaryGenres = [
            "Business",
            "Self-Help",
            "Biography", 
            "Personal Development",
            "Psychology",
            "Health",
            "History",
            "Politics",
            "Philosophy",
            "Economics",
            "Technology",
            "Education",
            "Arts & Culture",
            "Nature & Environment"
        ]
        
        // Track which books have been assigned to prevent duplicates across genres
        var assignedBookIds = Set<String>()
        
        // Map books to their primary genre (first matching category only)
        for book in allBooks {
            // Skip if this book is already assigned to a genre
            if assignedBookIds.contains(book.id) {
                continue
            }
            
            // Find the first matching primary genre for this book
            var assignedGenre: String? = nil
            for category in book.categories {
                let mainGenre = mapCategoryToGenre(category)
                if primaryGenres.contains(mainGenre) {
                    assignedGenre = mainGenre
                    break
                }
            }
            
            // If no primary genre match, use the first category mapped to any genre
            if assignedGenre == nil {
                for category in book.categories {
                    let mainGenre = mapCategoryToGenre(category)
                    assignedGenre = mainGenre
                    break
                }
            }
            
            // Assign book to the determined genre
            if let genre = assignedGenre {
                if genreMap[genre] == nil {
                    genreMap[genre] = []
                }
                genreMap[genre]!.append(book)
                assignedBookIds.insert(book.id)
            }
        }
        
        // Create ordered genre list
        var orderedGenres: [(genre: String, books: [Book])] = []
        var otherPicksBooks: [Book] = []
        
        // Add primary genres first (if they have 4+ books)
        for genre in primaryGenres {
            if let books = genreMap[genre], !books.isEmpty {
                if books.count >= 4 {
                    // Randomize books for Business, Self-Help, Biography, and Personal Development sections
                    let shuffledBooks = if genre == "Business" || genre == "Self-Help" || genre == "Biography" || genre == "Personal Development" {
                        books.shuffled()
                    } else {
                        books
                    }
                    orderedGenres.append((genre: genre, books: shuffledBooks))
                } else {
                    // Add books to "Other Picks" if less than 4 books
                    otherPicksBooks.append(contentsOf: books)
                }
                genreMap.removeValue(forKey: genre)
            }
        }
        
        // Add any remaining genres (if they have 4+ books)
        for (genre, books) in genreMap.sorted(by: { $0.key < $1.key }) {
            if !books.isEmpty {
                if books.count >= 4 {
                    // Randomize books for Business, Self-Help, Biography, and Personal Development sections
                    let shuffledBooks = if genre == "Business" || genre == "Self-Help" || genre == "Biography" || genre == "Personal Development" {
                        books.shuffled()
                    } else {
                        books
                    }
                    orderedGenres.append((genre: genre, books: shuffledBooks))
                } else {
                    // Add books to "Other Picks" if less than 4 books
                    otherPicksBooks.append(contentsOf: books)
                }
            }
        }
        
        // Add "Other Picks" category if we have books for it
        if !otherPicksBooks.isEmpty {
            orderedGenres.append((genre: "Other Picks", books: otherPicksBooks))
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
        } else if lowercased.contains("personal development") || lowercased.contains("development") ||
                  lowercased.contains("growth") || lowercased.contains("mindfulness") ||
                  lowercased.contains("meditation") || lowercased.contains("wellness") {
            return "Personal Development"
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
        } else if lowercased.contains("philosophy") || lowercased.contains("ethics") ||
                  lowercased.contains("wisdom") || lowercased.contains("meaning") ||
                  lowercased.contains("spiritual") {
            return "Philosophy"
        } else if lowercased.contains("economics") || lowercased.contains("economy") ||
                  lowercased.contains("finance") || lowercased.contains("money") ||
                  lowercased.contains("wealth") || lowercased.contains("investing") {
            return "Economics"
        } else if lowercased.contains("technology") || lowercased.contains("tech") ||
                  lowercased.contains("digital") || lowercased.contains("computer") ||
                  lowercased.contains("artificial intelligence") || lowercased.contains("ai") {
            return "Technology"
        } else if lowercased.contains("education") || lowercased.contains("learning") ||
                  lowercased.contains("teaching") || lowercased.contains("school") ||
                  lowercased.contains("university") {
            return "Education"
        } else if lowercased.contains("art") || lowercased.contains("culture") ||
                  lowercased.contains("music") || lowercased.contains("literature") ||
                  lowercased.contains("design") || lowercased.contains("creative") {
            return "Arts & Culture"
        } else if lowercased.contains("nature") || lowercased.contains("environment") ||
                  lowercased.contains("climate") || lowercased.contains("ecology") ||
                  lowercased.contains("sustainability") {
            return "Nature & Environment"
        } else {
            // Return the original category if it doesn't match any mapping
            return category
        }
    }
    
    func refreshFeaturedBooks() async {
        // Re-select noteworthy books for variety on refresh
        if !allPopularBooks.isEmpty {
            selectNoteworthyBooks()
        }
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