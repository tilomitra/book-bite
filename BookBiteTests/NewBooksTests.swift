import Testing
import Foundation
@testable import BookBite

struct NewBooksTests {

    @Test("New books decode server book rows and the weekly count")
    func testDecoding() throws {
        let json = """
        {
            "books": [{
                "id": "9bac0135-48de-4216-8417-7d2754f626ec",
                "title": "The Anxious Generation",
                "authors": ["Jonathan Haidt"],
                "categories": ["Psychology"],
                "created_at": "2026-10-29T17:40:05.123+00:00"
            }],
            "addedThisWeek": 12
        }
        """

        let newBooks = try NetworkService.makeDecoder().decode(NewBooks.self, from: Data(json.utf8))

        #expect(newBooks.books.first?.title == "The Anxious Generation")
        #expect(newBooks.addedThisWeek == 12)
        #expect(newBooks.caption == "12 added this week")
    }

    @Test("A week without new books has no caption")
    func testQuietWeek() {
        #expect(NewBooks(books: [], addedThisWeek: 0).caption == nil)
    }
}
