import Foundation
import Combine

@MainActor
class LibraryViewModel: ObservableObject {
    @Published var categories: [BookCategory] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    private let bookRepository: BookRepository
    
    init(bookRepository: BookRepository) {
        self.bookRepository = bookRepository
        setupCategories()
    }
    
    private func setupCategories() {
        categories = [
            BookCategory(name: "NYT Bestsellers", iconName: BookCategory.getCategoryIcon(for: "NYT Bestsellers")),
            BookCategory(name: "Self-Help", iconName: BookCategory.getCategoryIcon(for: "Self-Help")),
            BookCategory(name: "Psychology", iconName: BookCategory.getCategoryIcon(for: "Psychology")),
            BookCategory(name: "Business", iconName: BookCategory.getCategoryIcon(for: "Business")),
            BookCategory(name: "History", iconName: BookCategory.getCategoryIcon(for: "History")),
            BookCategory(name: "Biography", iconName: BookCategory.getCategoryIcon(for: "Biography")),
            BookCategory(name: "Science", iconName: BookCategory.getCategoryIcon(for: "Science")),
            BookCategory(name: "Technology", iconName: BookCategory.getCategoryIcon(for: "Technology")),
            BookCategory(name: "Health", iconName: BookCategory.getCategoryIcon(for: "Health")),
            BookCategory(name: "Personal Development", iconName: BookCategory.getCategoryIcon(for: "Personal Development")),
            BookCategory(name: "Leadership", iconName: BookCategory.getCategoryIcon(for: "Leadership")),
            BookCategory(name: "Entrepreneurship", iconName: BookCategory.getCategoryIcon(for: "Entrepreneurship")),
            BookCategory(name: "Economics", iconName: BookCategory.getCategoryIcon(for: "Economics")),
            BookCategory(name: "Philosophy", iconName: BookCategory.getCategoryIcon(for: "Philosophy")),
            BookCategory(name: "Politics", iconName: BookCategory.getCategoryIcon(for: "Politics")),
            BookCategory(name: "Memoir", iconName: BookCategory.getCategoryIcon(for: "Memoir")),
            BookCategory(name: "Mental Health", iconName: BookCategory.getCategoryIcon(for: "Mental Health")),
            BookCategory(name: "Innovation", iconName: BookCategory.getCategoryIcon(for: "Innovation")),
            BookCategory(name: "Marketing", iconName: BookCategory.getCategoryIcon(for: "Marketing")),
            BookCategory(name: "Productivity", iconName: BookCategory.getCategoryIcon(for: "Productivity")),
            BookCategory(name: "Mindfulness", iconName: BookCategory.getCategoryIcon(for: "Mindfulness")),
            BookCategory(name: "Biology", iconName: BookCategory.getCategoryIcon(for: "Biology")),
            BookCategory(name: "Physics", iconName: BookCategory.getCategoryIcon(for: "Physics")),
            BookCategory(name: "Medicine", iconName: BookCategory.getCategoryIcon(for: "Medicine")),
            BookCategory(name: "Environment", iconName: BookCategory.getCategoryIcon(for: "Environment")),
            BookCategory(name: "Nutrition", iconName: BookCategory.getCategoryIcon(for: "Nutrition")),
            BookCategory(name: "Fitness", iconName: BookCategory.getCategoryIcon(for: "Fitness")),
            BookCategory(name: "Spirituality", iconName: BookCategory.getCategoryIcon(for: "Spirituality")),
            BookCategory(name: "Sociology", iconName: BookCategory.getCategoryIcon(for: "Sociology")),
            BookCategory(name: "Education", iconName: BookCategory.getCategoryIcon(for: "Education")),
            BookCategory(name: "Art", iconName: BookCategory.getCategoryIcon(for: "Art")),
            BookCategory(name: "Music", iconName: BookCategory.getCategoryIcon(for: "Music")),
            BookCategory(name: "Travel", iconName: BookCategory.getCategoryIcon(for: "Travel")),
            BookCategory(name: "Cooking", iconName: BookCategory.getCategoryIcon(for: "Cooking"))
        ]
    }
    
    func loadCategories() async {
        isLoading = true
        error = nil
        
        do {
            // Try to fetch categories with counts from server
            if let serverCategories = try? await bookRepository.fetchCategories() {
                // Always ensure NYT Bestsellers is first, then add server categories (excluding duplicates)
                let nytCategory = BookCategory(name: "NYT Bestsellers", iconName: BookCategory.getCategoryIcon(for: "NYT Bestsellers"))
                
                // Get NYT Bestsellers count
                let nytBestsellerBooks = try? await bookRepository.fetchNYTBestsellerBooks()
                let nytCategoryWithCount = BookCategory(
                    name: nytCategory.name,
                    iconName: nytCategory.iconName,
                    bookCount: nytBestsellerBooks?.count ?? 0
                )
                
                // Filter out NYT Bestsellers from server categories if it exists, and add our version first
                let filteredServerCategories = serverCategories.filter { $0.name != "NYT Bestsellers" }
                categories = [nytCategoryWithCount] + filteredServerCategories
            } else {
                // Fallback: calculate counts locally if server endpoint fails
                let categoryCounts = await fetchCategoryCounts()
                
                categories = categories.map { category in
                    BookCategory(
                        name: category.name,
                        iconName: category.iconName,
                        bookCount: categoryCounts[category.name] ?? 0
                    )
                }
            }
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    private func fetchCategoryCounts() async -> [String: Int] {
        var counts: [String: Int] = [:]
        
        do {
            // For each category, fetch the actual books that would be shown
            for category in categories {
                let books: [Book]?
                if category.name == "NYT Bestsellers" {
                    books = try? await bookRepository.fetchNYTBestsellerBooks()
                } else {
                    books = try? await bookRepository.fetchBooksByCategory(category.name, page: 1, limit: 1000)
                }
                
                if let books = books {
                    counts[category.name] = books.count
                }
            }
        } catch {
            print("Error fetching category counts: \(error)")
        }
        
        return counts
    }
}

@MainActor
class CategoryBooksViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var error: Error?
    @Published var hasMore: Bool = true
    
    private let category: BookCategory
    private let bookRepository: BookRepository
    private var currentPage = 1
    private let itemsPerPage = 20
    
    init(category: BookCategory, bookRepository: BookRepository) {
        self.category = category
        self.bookRepository = bookRepository
    }
    
    func loadBooks() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        currentPage = 1  // Reset to first page
        
        do {
            // Handle special case for NYT Bestsellers category
            if category.name == "NYT Bestsellers" {
                let allBooks = try await bookRepository.fetchNYTBestsellerBooks()
                
                // Sort books by popularity_score (highest first), then by title as fallback
                books = allBooks.sorted { book1, book2 in
                    // First priority: books with popularity_score
                    if let score1 = book1.popularityScore, let score2 = book2.popularityScore {
                        return score1 > score2  // Higher scores first
                    }
                    
                    // Second priority: books with popularity_score over those without
                    if book1.popularityScore != nil && book2.popularityScore == nil {
                        return true
                    }
                    if book1.popularityScore == nil && book2.popularityScore != nil {
                        return false
                    }
                    
                    // Final fallback: alphabetical by title
                    return book1.title.localizedCaseInsensitiveCompare(book2.title) == .orderedAscending
                }
                
                hasMore = false  // NYT Bestsellers are loaded all at once
            } else {
                // Load books with proper pagination for regular categories
                var allBooks: [Book] = []
                var pageToLoad = 1
                var hasMorePages = true
                
                // Load all pages to get all books in the category
                while hasMorePages {
                    let fetchedBooks = try await bookRepository.fetchBooksByCategory(
                        category.name,
                        page: pageToLoad,
                        limit: 100  // Use reasonable page size
                    )
                    
                    if fetchedBooks.isEmpty {
                        hasMorePages = false
                    } else {
                        allBooks.append(contentsOf: fetchedBooks)
                        pageToLoad += 1
                        
                        // Safety check to prevent infinite loops (max 50 pages = 5000 books)
                        if pageToLoad > 50 {
                            hasMorePages = false
                        }
                    }
                }
                
                // Sort all fetched books
                books = allBooks.sorted { book1, book2 in
                    // First priority: books with popularity_score
                    if let score1 = book1.popularityScore, let score2 = book2.popularityScore {
                        return score1 > score2  // Higher scores first
                    }
                    
                    // Second priority: books with popularity_score over those without
                    if book1.popularityScore != nil && book2.popularityScore == nil {
                        return true
                    }
                    if book1.popularityScore == nil && book2.popularityScore != nil {
                        return false
                    }
                    
                    // Final fallback: alphabetical by title
                    return book1.title.localizedCaseInsensitiveCompare(book2.title) == .orderedAscending
                }
                
                hasMore = false  // All books loaded
            }
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
    
    func onBookAppear(_ book: Book) {
        // No longer needed since we load all books at once
    }
    
    private func loadMoreBooks() async {
        // No longer needed since we load all books at once
    }
}