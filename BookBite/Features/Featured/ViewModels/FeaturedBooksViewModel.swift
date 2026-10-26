import Foundation
import Combine

@MainActor
class FeaturedBooksViewModel: ObservableObject {
    @Published var dailyIdea: DailyIdea?
    @Published var booksByGenre: [(genre: String, books: [Book])] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let bookRepository: BookRepository
    private var featuredBooks: [Book] = []
    private var nytBestsellerBooks: [Book] = []

    init(bookRepository: BookRepository) {
        self.bookRepository = bookRepository

        Task {
            await loadFeaturedBooks()
        }
    }

    var showEmptyState: Bool {
        !isLoading && error == nil && booksByGenre.isEmpty
    }

    func loadFeaturedBooks() async {
        isLoading = true
        error = nil

        // Clear cache to ensure fresh data
        bookRepository.clearCache()

        // Loads alongside the books; a failure only hides the card
        let dailyIdeaTask = Task { await fetchDailyIdea() }

        do {
            async let featuredBooksTask = bookRepository.fetchFeaturedBooks()
            async let nytBooksTask = bookRepository.fetchNYTBestsellerBooks()

            let (featured, nytBooks) = try await (featuredBooksTask, nytBooksTask)

            featuredBooks = featured
            nytBestsellerBooks = nytBooks
            groupBooksByGenre()
        } catch {
            // Don't show cancellation errors to user - they're expected during rapid refreshes
            if !(error is CancellationError) {
                self.error = error
                print("Failed to load books: \(error)")
            }
        }

        dailyIdea = await dailyIdeaTask.value ?? dailyIdea
        if let dailyIdea { WidgetBridge.publish(dailyIdea) }
        isLoading = false
    }

    private func fetchDailyIdea() async -> DailyIdea? {
        guard let provider = bookRepository as? DailyIdeaProviding else { return nil }

        // The user's local day, so the idea changes at their midnight
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        do {
            return try await provider.fetchDailyIdea(for: formatter.string(from: Date()))
        } catch {
            print("Failed to load daily idea: \(error)")
            return nil
        }
    }

    /// Most popular first, then alphabetical, so shelves keep the same order between visits
    private func sortedByPopularity(_ books: [Book]) -> [Book] {
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
        for book in featuredBooks + nytBestsellerBooks {
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
                    orderedGenres.append((genre: genre, books: sortedByPopularity(books)))
                } else {
                    // Add books to "More Books" if less than 4 books
                    otherPicksBooks.append(contentsOf: books)
                }
                genreMap.removeValue(forKey: genre)
            }
        }
        
        // Add any remaining genres (if they have 4+ books)
        for (genre, books) in genreMap.sorted(by: { $0.key < $1.key }) {
            if !books.isEmpty {
                if books.count >= 4 {
                    orderedGenres.append((genre: genre, books: sortedByPopularity(books)))
                } else {
                    // Add books to "More Books" if less than 4 books
                    otherPicksBooks.append(contentsOf: books)
                }
            }
        }
        
        // Add "More Books" shelf if we have books for it
        if !otherPicksBooks.isEmpty {
            orderedGenres.append((genre: "More Books", books: sortedByPopularity(otherPicksBooks)))
        }
        
        // Topics picked during onboarding come first, in their usual order
        let preferred = Set(OnboardingPreferences.preferredGenres)
        booksByGenre = orderedGenres.filter { preferred.contains($0.genre) }
            + orderedGenres.filter { !preferred.contains($0.genre) }
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
}
