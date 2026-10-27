import Foundation

/// Key ideas the user kept, newest first: their personal notebook. Stored on device (UserDefaults),
/// so it works without sign-in. Book pages write it; Library's "Notebook" reads it.
@MainActor
final class SavedIdeasStore: ObservableObject {
    static let shared = SavedIdeasStore()

    struct SavedIdea: Codable, Identifiable, Equatable {
        let book: Book
        /// `KeyIdea.id`, or a hash of the text when the summary had no stable ids
        let ideaId: String
        let text: String
        let savedAt: Date

        var id: String { "\(book.id)/\(ideaId)" }

        static func == (lhs: SavedIdea, rhs: SavedIdea) -> Bool { lhs.id == rhs.id }
    }

    @Published private(set) var ideas: [SavedIdea] = []

    private let defaults: UserDefaults
    private let key = "savedIdeas"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? NetworkService.makeDecoder().decode([SavedIdea].self, from: data) {
            ideas = saved
        }
    }

    func isSaved(bookId: String, text: String) -> Bool {
        ideas.contains { $0.book.id == bookId && $0.text == text }
    }

    /// Saves the idea, or removes it when it is already saved. Returns true when it is now saved.
    @discardableResult
    func toggle(_ text: String, ideaId: String, book: Book) -> Bool {
        if isSaved(bookId: book.id, text: text) {
            ideas.removeAll { $0.book.id == book.id && $0.text == text }
            save()
            return false
        }
        ideas.insert(SavedIdea(book: book, ideaId: ideaId, text: text, savedAt: Date()), at: 0)
        save()
        return true
    }

    func remove(_ idea: SavedIdea) {
        ideas.removeAll { $0.id == idea.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(ideas) {
            defaults.set(data, forKey: key)
        }
    }
}
