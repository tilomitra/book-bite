import Testing
import Foundation
@testable import BookBite

struct ReadingLoopTests {

    private let habits = Book(id: "1", title: "Atomic Habits: An Easy & Proven Way", authors: ["James Clear"])
    private let deep = Book(id: "2", title: "Deep Work", authors: ["Cal Newport", "Someone Else"])

    private func idea(_ book: Book, _ id: String, secondsAgo: TimeInterval) -> SavedIdeasStore.SavedIdea {
        SavedIdeasStore.SavedIdea(book: book, ideaId: id, text: "Idea \(id)", savedAt: Date(timeIntervalSince1970: 1_000_000 - secondsAgo))
    }

    private func entry(_ book: Book, finishedAt: Date?) -> ReadingProgressStore.Entry {
        ReadingProgressStore.Entry(book: book, fraction: 1, chapterIndex: 0, updatedAt: .now, finishedAt: finishedAt)
    }

    // MARK: Minutes left

    @Test("Minutes left rounds up the unread part of the summary")
    func testMinutesLeft() {
        #expect(ReadingTime.minutesLeft(fraction: 0, totalMinutes: 15) == 15)
        #expect(ReadingTime.minutesLeft(fraction: 0.5, totalMinutes: 15) == 8)
        #expect(ReadingTime.minutesLeft(fraction: 0.4, totalMinutes: 10) == 6)
    }

    @Test("Minutes left is at least one and clamps the fraction")
    func testMinutesLeftBounds() {
        #expect(ReadingTime.minutesLeft(fraction: 0.99, totalMinutes: 12) == 1)
        #expect(ReadingTime.minutesLeft(fraction: 1.5, totalMinutes: 12) == 1)
        #expect(ReadingTime.minutesLeft(fraction: -1, totalMinutes: 12) == 12)
    }

    @Test("Unknown length gives no minutes and a gentle prompt")
    func testUnknownLength() {
        #expect(ReadingTime.minutesLeft(fraction: 0.3, totalMinutes: nil) == nil)
        #expect(ReadingTime.minutesLeft(fraction: 0.3, totalMinutes: 0) == nil)
        #expect(ReadingTime.status(fraction: 0.3, totalMinutes: nil) == "Pick up where you left off")
        #expect(ReadingTime.status(fraction: 0.5, totalMinutes: 20) == "10 min left")
    }

    // MARK: Notebook

    @Test("Grouping by book puts the most recently kept book first, ideas newest first")
    func testGroupedByBook() {
        let ideas = [
            idea(habits, "a", secondsAgo: 300),
            idea(deep, "b", secondsAgo: 100),
            idea(habits, "c", secondsAgo: 10),
            idea(deep, "d", secondsAgo: 500),
        ]

        let groups = Notebook.groupedByBook(ideas)

        #expect(groups.map(\.book.id) == ["1", "2"])
        #expect(groups[0].ideas.map(\.ideaId) == ["c", "a"])
        #expect(groups[1].ideas.map(\.ideaId) == ["b", "d"])
    }

    @Test("Newest first sorts by when the idea was kept")
    func testNewestFirst() {
        let ideas = [idea(habits, "a", secondsAgo: 300), idea(deep, "b", secondsAgo: 5), idea(habits, "c", secondsAgo: 50)]
        #expect(Notebook.newestFirst(ideas).map(\.ideaId) == ["b", "c", "a"])
        #expect(Notebook.groupedByBook([]).isEmpty)
    }

    @Test("Shared text quotes the idea and credits the book")
    func testShareText() {
        let text = Notebook.shareText(for: idea(habits, "a", secondsAgo: 0))
        #expect(text == "“Idea a”\n\n— Atomic Habits by James Clear")
        let multiAuthor = Notebook.shareText(for: idea(deep, "b", secondsAgo: 0))
        #expect(multiAuthor.hasSuffix("— Deep Work by Cal Newport & others"))
    }

    // MARK: Finished

    @Test("Finished this year counts only this calendar year's finished summaries")
    func testFinishedThisYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let date = { (y: Int, m: Int, d: Int) in
            calendar.date(from: DateComponents(year: y, month: m, day: d))!
        }
        let now = date(2026, 10, 26)
        let entries = [
            entry(habits, finishedAt: date(2026, 1, 2)),
            entry(deep, finishedAt: date(2026, 10, 1)),
            entry(Book(id: "3", title: "Old"), finishedAt: date(2025, 12, 31)),
            entry(Book(id: "4", title: "Unfinished"), finishedAt: nil),
        ]

        #expect(FinishedStats.finishedThisYear(entries, now: now, calendar: calendar) == 2)
        #expect(FinishedStats.caption(entries, now: now, calendar: calendar) == "2 finished this year")
        #expect(FinishedStats.caption(Array(entries.suffix(2)), now: now, calendar: calendar) == nil)
    }
}
