import Testing
import Foundation
@testable import BookBite

struct ReaderDocumentTests {

    @Test("Text without headings is one untitled chapter of paragraphs")
    func testNoHeadings() {
        let document = ReaderDocument(markdown: "First paragraph here.\n\nSecond paragraph.\n\n\nThird.")

        #expect(document.chapters.count == 1)
        #expect(document.chapters[0].title == nil)
        #expect(document.chapters[0].paragraphs == ["First paragraph here.", "Second paragraph.", "Third."])
        #expect(!document.hasHeadings)
    }

    @Test("## headings start chapters; text before the first heading is an untitled opening")
    func testHeadings() {
        let markdown = """
        An opening thought.

        ## The Habit Loop
        Cue, craving, response, reward.

        Habits compound.

        ## Make It Obvious
        Design your environment.
        """
        let document = ReaderDocument(markdown: markdown)

        #expect(document.chapters.map(\.title) == [nil, "The Habit Loop", "Make It Obvious"])
        #expect(document.chapters.map(\.id) == [0, 1, 2])
        #expect(document.chapters[1].paragraphs == ["Cue, craving, response, reward.", "Habits compound."])
        #expect(document.hasHeadings)
        #expect(document.titledChapters.count == 2)
    }

    @Test("Text starting with a heading has no untitled chapter, and empty headings are dropped")
    func testLeadingAndEmptyHeadings() {
        let document = ReaderDocument(markdown: "## Empty\n\n## Introduction\nHello there.\n## Trailing\n")

        #expect(document.chapters.map(\.title) == ["Introduction"])
        #expect(document.chapters[0].id == 0)
    }

    @Test("Single newlines separate paragraphs and Windows line endings are handled")
    func testLineEndings() {
        let document = ReaderDocument(markdown: "One.\r\nTwo.\r\n\r\nThree.")
        #expect(document.chapters[0].paragraphs == ["One.", "Two.", "Three."])
    }

    @Test("Stray markdown is stripped")
    func testStripsMarkdown() {
        let markdown = """
        # Atomic Habits
        **Small habits** make a *big* difference.
        ### A subheading
        - a list item
        > a quote
        Read [the book](https://example.com) and `code`.
        ---
        2 * 3 * 4 stays as it is.
        """
        let paragraphs = ReaderDocument(markdown: markdown).chapters.flatMap(\.paragraphs)

        #expect(paragraphs == [
            "Atomic Habits",
            "Small habits make a big difference.",
            "A subheading",
            "• a list item",
            "a quote",
            "Read the book and code.",
            "2 * 3 * 4 stays as it is.",
        ])
    }

    @Test("Chapter titles lose markdown and source numbering", arguments: [
        ("## Chapter 2: The Habit Loop", "The Habit Loop"),
        ("## 3. Make It Easy", "Make It Easy"),
        ("## Part IV — Endings", "Endings"),
        ("## **Bold Title**", "Bold Title"),
        ("## Chapter Civilization", "Chapter Civilization"),
        ("## Chapter 1", "Chapter 1"),
        ("## 1984 Revisited", "1984 Revisited"),
    ])
    func testChapterTitles(line: String, expected: String) {
        #expect(ReaderDocument.chapterHeading(in: line) == expected)
    }

    @Test("Deeper headings are not chapters")
    func testDeeperHeadingsAreNotChapters() {
        #expect(ReaderDocument.chapterHeading(in: "### Subheading") == nil)
        #expect(ReaderDocument.chapterHeading(in: "# Title") == nil)
        #expect(ReaderDocument.chapterHeading(in: "##NoSpace") == nil)
    }

    @Test("Minutes left counts down at 200 words a minute")
    func testMinutesLeft() {
        let words = Array(repeating: "word", count: 1000).joined(separator: " ")
        let document = ReaderDocument(markdown: words)

        #expect(document.wordCount == 1000)
        #expect(document.minutesLeft(at: 0) == 5)
        #expect(document.minutesLeft(at: 0.5) == 3)
        #expect(document.minutesLeft(at: 0.99) == 1)
        #expect(document.minutesLeft(at: 1) == 0)
    }

    @Test("Hyphenation only inserts invisible soft hyphens")
    func testHyphenation() {
        let text = "Extraordinary productivity requires understanding."
        let hyphenated = Hyphenator.hyphenate(text, locale: Locale(identifier: "en_US"))

        #expect(hyphenated.replacingOccurrences(of: "\u{00AD}", with: "") == text)
        #expect(hyphenated.contains("\u{00AD}"))
        // Short words are left alone
        #expect(Hyphenator.hyphenate("A cat sat.", locale: Locale(identifier: "en_US")) == "A cat sat.")
    }

    @Test("The opening lead-in splits an initial and a few small-caps words")
    func testLeadIn() throws {
        let lead = try #require(ReaderLeadIn(paragraph: "In the beginning there was a habit loop.", withInitial: true))
        #expect(lead.initial == "I")
        #expect(lead.smallCaps == "n the beginning")
        #expect(lead.rest == " there was a habit loop.")

        let pause = try #require(ReaderLeadIn(paragraph: "Habits, small as they are, compound over years.", withInitial: false))
        #expect(pause.initial == nil)
        #expect(pause.smallCaps == "Habits,")

        let quoted = try #require(ReaderLeadIn(paragraph: "“Every action is a vote for the person you become.”", withInitial: true))
        #expect(quoted.initial == "“E")

        #expect(ReaderLeadIn(paragraph: "Too short.", withInitial: true) == nil)
        #expect(ReaderLeadIn(paragraph: "• A list item that is long enough to count", withInitial: true) == nil)
    }

    @Test("Straight quotes become typographic quotes")
    func testSmartQuotes() {
        #expect(ReaderDocument.smartQuotes(#""The Hobbit" isn't Tolkien's last ('Silmarillion')."#)
            == "“The Hobbit” isn’t Tolkien’s last (‘Silmarillion’).")
    }
}
