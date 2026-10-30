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
    @Published var hasMore: Bool = false

    private let category: BookCategory
    private let bookRepository: BookRepository
    private let cache: CacheService
    private var nextPage = 2
    private let itemsPerPage = 40

    private var snapshotKey: String {
        let name = category.name.lowercased().filter { $0.isLetter || $0.isNumber }
        return "category-\(name)"
    }

    init(category: BookCategory, bookRepository: BookRepository, cache: CacheService = .shared) {
        self.category = category
        self.bookRepository = bookRepository
        self.cache = cache
        // The first page from last time, so the list is there when the screen opens
        books = cache.snapshot([Book].self, key: snapshotKey) ?? []
    }

    func loadBooks() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            // Handle special case for NYT Bestsellers category
            if category.name == "NYT Bestsellers" {
                books = Self.byPopularity(try await bookRepository.fetchNYTBestsellerBooks())
                hasMore = false  // NYT Bestsellers are loaded all at once
            } else {
                // The server sorts most read first, so the list can grow as the reader scrolls
                let firstPage = try await bookRepository.fetchBooksByCategory(category.name, page: 1, limit: itemsPerPage)
                books = firstPage
                nextPage = 2
                hasMore = firstPage.count == itemsPerPage
            }

            prefetchCovers(books)

            let snapshot = books
            let cache = cache
            let key = snapshotKey
            Task.detached(priority: .utility) {
                cache.saveSnapshot(snapshot, key: key)
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func onBookAppear(_ book: Book) {
        guard hasMore, !isLoadingMore,
              let index = books.lastIndex(where: { $0.id == book.id }),
              index >= books.count - 10 else { return }
        Task { await loadMoreBooks() }
    }

    private func loadMoreBooks() async {
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await bookRepository.fetchBooksByCategory(category.name, page: nextPage, limit: itemsPerPage)
            let known = Set(books.map(\.id))
            books += page.filter { !known.contains($0.id) }
            prefetchCovers(page)
            nextPage += 1
            hasMore = page.count == itemsPerPage
        } catch {
            // The next row to appear tries again
            print("Failed to load more books: \(error)")
        }
    }

    /// So fast scrolling doesn't outrun the covers
    private func prefetchCovers(_ books: [Book]) {
        let width = BookCoverView.CoverSize.small.dimensions.width
        CoverImageLoader.shared.prefetch(books.compactMap(\.coverAssetName), pixelWidth: CoverImageLoader.pixelWidth(forPoints: width))
    }

    /// Highest popularity_score first, books without one after them, then by title
    private static func byPopularity(_ books: [Book]) -> [Book] {
        books.sorted { book1, book2 in
            switch (book1.popularityScore, book2.popularityScore) {
            case let (score1?, score2?) where score1 != score2:
                return score1 > score2
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return book1.title.localizedCaseInsensitiveCompare(book2.title) == .orderedAscending
            }
        }
    }
}
