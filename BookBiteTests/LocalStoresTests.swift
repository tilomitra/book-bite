import Foundation
import Testing
@testable import BookBite

/// Reading progress and kept ideas must survive a relaunch (a new store reading the same defaults).
@MainActor
struct LocalStoresTests {
    private let book = Book(id: "b1", title: "Deep Work", authors: ["Cal Newport"])

    private func freshDefaults() -> UserDefaults {
        let name = "LocalStoresTests-\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    @Test("Reading progress persists across store instances")
    func testProgressPersists() {
        let defaults = freshDefaults()
        let store = ReadingProgressStore(defaults: defaults)
        store.update(book, fraction: 0.4, chapterIndex: 2, totalMinutes: 9)
        // A later update without a length keeps the known one
        store.update(book, fraction: 0.4, chapterIndex: 2)

        let reloaded = ReadingProgressStore(defaults: defaults)
        #expect(reloaded.entry(for: "b1")?.fraction == 0.4)
        #expect(reloaded.entry(for: "b1")?.chapterIndex == 2)
        #expect(reloaded.entry(for: "b1")?.totalMinutes == 9)
        #expect(reloaded.inProgress.count == 1)

        reloaded.markFinished(book)
        let finished = ReadingProgressStore(defaults: defaults)
        #expect(finished.finished.first?.book.id == "b1")
        #expect(finished.inProgress.isEmpty)
    }

    @Test("Kept ideas persist across store instances and toggle off")
    func testSavedIdeasPersist() {
        let defaults = freshDefaults()
        let store = SavedIdeasStore(defaults: defaults)
        #expect(store.toggle("Focus is a skill.", ideaId: "k1", book: book))

        let reloaded = SavedIdeasStore(defaults: defaults)
        #expect(reloaded.isSaved(bookId: "b1", text: "Focus is a skill."))

        #expect(!reloaded.toggle("Focus is a skill.", ideaId: "k1", book: book))
        #expect(SavedIdeasStore(defaults: defaults).ideas.isEmpty)
    }
}
