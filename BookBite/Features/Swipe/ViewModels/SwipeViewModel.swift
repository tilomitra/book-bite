import Foundation
import Combine

@MainActor
class SwipeViewModel: ObservableObject {
    @Published var currentBook: Book?
    @Published var nextBook: Book?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let bookRepository: BookRepository
    private var allBooks: [Book] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(bookRepository: BookRepository) {
        self.bookRepository = bookRepository
        
        Task {
            await loadBooks()
        }
    }
    
    func loadBooks() async {
        isLoading = true
        error = nil
        
        do {
            allBooks = try await bookRepository.fetchAllBooks()
            loadNextBook()
            preloadNextBook()
        } catch {
            self.error = error
            print("Failed to load books for swipe: \(error)")
            if let networkError = error as? NetworkError {
                print("Network error details: \(networkError)")
            }
            print("Error type: \(type(of: error))")
        }
        
        isLoading = false
    }
    
    private func loadNextBook() {
        guard !allBooks.isEmpty else { return }
        
        // If we have a preloaded next book, use it
        if let preloaded = nextBook {
            currentBook = preloaded
        } else {
            // Otherwise pick a random book
            currentBook = allBooks.randomElement()
        }
    }
    
    private func preloadNextBook() {
        guard !allBooks.isEmpty else { return }
        
        // Pick a random book that's different from current book
        var randomBook = allBooks.randomElement()
        while randomBook?.id == currentBook?.id && allBooks.count > 1 {
            randomBook = allBooks.randomElement()
        }
        nextBook = randomBook
    }
    
    func swipeLeft() {
        // Move to next book
        loadNextBook()
        preloadNextBook()
    }
    
    func swipeRight() -> Book? {
        // Return current book for navigation, then load next
        let bookToShow = currentBook
        loadNextBook()
        preloadNextBook()
        return bookToShow
    }
    
    func refreshBooks() async {
        await loadBooks()
    }
}