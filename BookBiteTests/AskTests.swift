import Foundation
import Testing
@testable import BookBite

struct AskAnswerTests {
    private let full = """
    Stop taking the work back. Every rescue teaches your team the deadline is yours.

    Three books point the same way.
    - **Hand over the decision.** People keep deadlines they set themselves. [1]
    - **Fix the brief first.** Say why the date matters. [2][3]
    1. **Name the slip early.** Say it the same day. [3, 1]

    This week: Ask them to say the deadline back.
    **Other side:** If deadlines were never realistic, check the calendar first.
    """

    @Test("Parses the answer format into its parts")
    func testParsesFormat() {
        let answer = AskAnswer(parsing: full)
        #expect(answer.lead == "Stop taking the work back. Every rescue teaches your team the deadline is yours.")
        #expect(answer.paragraphs == ["Three books point the same way."])
        #expect(answer.points.count == 3)
        #expect(answer.points[0] == .init(lead: "Hand over the decision.", body: "People keep deadlines they set themselves.", sources: [1]))
        #expect(answer.points[1].sources == [2, 3])
        #expect(answer.points[2].sources == [3, 1])
        #expect(answer.thisWeek == "Ask them to say the deadline back.")
        #expect(answer.otherSide == "If deadlines were never realistic, check the calendar first.")
        #expect(answer.citedSources == [1, 2, 3])
    }

    @Test("Prose-only follow-ups keep their citations")
    func testProseCitations() {
        let answer = AskAnswer(parsing: "Then it’s a conversation, not a process. [2]\n\nTalk to them alone. [1]")
        #expect(answer.lead == "Then it’s a conversation, not a process.")
        #expect(answer.paragraphs == ["Talk to them alone."])
        #expect(answer.proseSources == [2, 1])
        #expect(answer.points.isEmpty)
    }

    @Test("While streaming, a half-written label or citation is held back")
    func testStreamingHoldsBackPartialLines() {
        let partialLabel = AskAnswer(parsing: "Stop taking the work back.\n\nThis we", streaming: true)
        #expect(partialLabel.paragraphs.isEmpty)
        #expect(partialLabel.thisWeek == nil)

        let partialCitation = AskAnswer(parsing: "Stop.\n- **Lead.** Body text [", streaming: true)
        #expect(partialCitation.points.first?.body == "Body text")

        // Once finished, the same text is a paragraph
        #expect(AskAnswer(parsing: "Stop taking the work back.\n\nThis we").paragraphs == ["This we"])
    }

    @Test("Points without a bold lead keep all their text")
    func testPlainListItems() {
        let answer = AskAnswer(parsing: "Answer.\n- Just do the thing. [1]")
        #expect(answer.points == [.init(lead: "", body: "Just do the thing.", sources: [1])])
    }
}

@MainActor
struct AskHistoryStoreTests {
    private let book = Book(id: "b1", title: "Turn the Ship Around!", authors: ["L. David Marquet"])

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "AskHistoryStoreTests-\(UUID().uuidString)")!
    }

    @Test("Conversations persist across store instances, newest first, without unanswered turns")
    func testPersists() {
        let defaults = freshDefaults()
        let store = AskHistoryStore(defaults: defaults)
        let first = AskConversation(turns: [AskTurn(question: "One?", answer: "Yes. [1]", sources: [book])])
        var second = AskConversation(turns: [AskTurn(question: "Two?", answer: "No.")])
        second.turns.append(AskTurn(question: "Pending?"))
        store.save(first)
        store.save(second)

        let reloaded = AskHistoryStore(defaults: defaults)
        #expect(reloaded.conversations.map(\.title) == ["Two?", "One?"])
        #expect(reloaded.conversations[0].turns.count == 1)
        #expect(reloaded.conversations[1].turns[0].sources.first?.id == "b1")

        // Saving again moves it to the top; removing deletes it
        reloaded.save(first)
        #expect(reloaded.conversations.first?.id == first.id)
        reloaded.remove(first)
        #expect(AskHistoryStore(defaults: defaults).conversations.map(\.title) == ["Two?"])
    }
}
