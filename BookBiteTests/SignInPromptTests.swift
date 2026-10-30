import Foundation
import Testing
@testable import BookBite

struct SignInPromptTests {
    private let book = Book(id: "b1", title: "Atomic Habits: An Easy & Proven Way", authors: ["James Clear"])

    @Test("The Ask prompt quotes the question and counts the books")
    func testAskMessage() {
        let none = SignInPrompt.Reason.ask(question: "How do I focus?", books: []).message
        let one = SignInPrompt.Reason.ask(question: "How do I focus?", books: [book]).message
        let two = SignInPrompt.Reason.ask(question: "How do I focus?", books: [book, book]).message

        #expect(none.contains("“How do I focus?”"))
        #expect(one.hasPrefix("We found a book with ideas on"))
        #expect(two.hasPrefix("We found 2 books with ideas on"))
        #expect(two.hasSuffix("Create a free account to read the answer."))
    }

    @Test("The Save prompt names the book by its short title")
    func testSaveMessage() {
        let message = SignInPrompt.Reason.save(book).message
        #expect(message.contains("“Atomic Habits”"))
        #expect(!message.contains("Proven"))
    }

    @Test("Long questions are cut at a word")
    func testShortened() {
        #expect(SignInPrompt.Reason.shortened("Short one") == "Short one")

        let long = String(repeating: "word ", count: 30).trimmingCharacters(in: .whitespaces)
        let cut = SignInPrompt.Reason.shortened(long)
        #expect(cut.hasSuffix("word…"))
        #expect(cut.count <= 71)
    }
}
