import Foundation
import Combine

@MainActor
class SwipeViewModel: ObservableObject {
    @Published var currentBook: Book?
    @Published var nextBook: Book?
    @Published var backgroundBooks: [Book] = []
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
            preloadBackgroundBooks()
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
    
    private func preloadBackgroundBooks() {
        guard !allBooks.isEmpty else { return }
        
        var backgrounds: [Book] = []
        let usedIds = Set([currentBook?.id, nextBook?.id].compactMap { $0 })
        
        // Get 2 random books for background stack
        while backgrounds.count < 2 && allBooks.count > usedIds.count {
            if let randomBook = allBooks.randomElement(),
               !usedIds.contains(randomBook.id),
               !backgrounds.contains(where: { $0.id == randomBook.id }) {
                backgrounds.append(randomBook)
            }
        }
        
        backgroundBooks = backgrounds
    }
    
    func swipeLeft() {
        // Move to next book from stack
        moveToNextCardFromStack()
    }
    
    func swipeRight() -> Book? {
        // Return current book for navigation, then move to next from stack
        let bookToShow = currentBook
        moveToNextCardFromStack()
        return bookToShow
    }
    
    private func moveToNextCardFromStack() {
        // Move the first background book to current
        if !backgroundBooks.isEmpty {
            currentBook = backgroundBooks.removeFirst()
        } else {
            // Fallback to random book if stack is empty
            currentBook = allBooks.randomElement()
        }
        
        // Replenish the background stack
        refillBackgroundBooks()
    }
    
    private func refillBackgroundBooks() {
        guard !allBooks.isEmpty else { return }
        
        // Add books to maintain 2 background books
        while backgroundBooks.count < 2 && allBooks.count > backgroundBooks.count + 1 {
            var randomBook = allBooks.randomElement()
            let usedIds = Set([currentBook?.id].compactMap { $0 } + backgroundBooks.map { $0.id })
            
            // Find a book not already in use
            var attempts = 0
            while randomBook != nil && usedIds.contains(randomBook!.id) && attempts < 10 {
                randomBook = allBooks.randomElement()
                attempts += 1
            }
            
            if let book = randomBook, !usedIds.contains(book.id) {
                backgroundBooks.append(book)
            } else {
                break
            }
        }
    }
    
    func refreshBooks() async {
        await loadBooks()
    }
}