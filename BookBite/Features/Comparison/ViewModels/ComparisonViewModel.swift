import Foundation
import Combine

@MainActor
class ComparisonViewModel: ObservableObject {
    @Published var firstBook: Book
    @Published var secondBook: Book?
    @Published var firstSummary: Summary?
    @Published var secondSummary: Summary?
    @Published var availableBooks: [Book] = []
    @Published var isLoadingBooks = false
    @Published var isLoadingSummaries = false
    @Published var synchronizedScrolling = true
    
    private let repository: BookRepository
    
    init(firstBook: Book, repository: BookRepository) {
        self.firstBook = firstBook
        self.repository = repository
        
        Task {
            await loadFirstSummary()
            await loadAvailableBooks()
        }
    }
    
    private func loadFirstSummary() async {
        isLoadingSummaries = true
        firstSummary = try? await repository.fetchSummary(for: firstBook.id)
        isLoadingSummaries = false
    }
    
    private func loadAvailableBooks() async {
        isLoadingBooks = true
        let allBooks = try? await repository.fetchAllBooks()
        availableBooks = allBooks?.filter { $0.id != firstBook.id } ?? []
        isLoadingBooks = false
    }
    
    func selectSecondBook(_ book: Book) async {
        secondBook = book
        isLoadingSummaries = true
        secondSummary = try? await repository.fetchSummary(for: book.id)
        isLoadingSummaries = false
    }
    
    func clearSecondBook() {
        secondBook = nil
        secondSummary = nil
    }
    
    func findCommonThemes() -> [String] {
        guard let first = firstSummary, let second = secondSummary else { return [] }
        
        let firstTags = Set(first.keyIdeas.flatMap { $0.tags })
        let secondTags = Set(second.keyIdeas.flatMap { $0.tags })
        
        return Array(firstTags.intersection(secondTags))
    }
    
    func findUniqueIdeas(for book: Book) -> [KeyIdea] {
        guard let first = firstSummary, let second = secondSummary else { return [] }
        
        if book.id == firstBook.id {
            let secondIdeas = Set(second.keyIdeas.map { $0.idea.lowercased() })
            return first.keyIdeas.filter { !secondIdeas.contains($0.idea.lowercased()) }
        } else {
            let firstIdeas = Set(first.keyIdeas.map { $0.idea.lowercased() })
            return second.keyIdeas.filter { !firstIdeas.contains($0.idea.lowercased()) }
        }
    }
}