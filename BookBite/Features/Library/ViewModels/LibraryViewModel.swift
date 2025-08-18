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
                // Use server-provided categories with accurate counts
                categories = serverCategories
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
                if let books = try? await bookRepository.fetchBooksByCategory(category.name, page: 1, limit: 1000) {
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
        
        do {
            // Load all books in the category (up to 1000 to get all of them)
            let allBooks = try await bookRepository.fetchBooksByCategory(category.name, page: 1, limit: 1000)
            books = allBooks
            hasMore = false  // We loaded all books, no more pagination needed
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