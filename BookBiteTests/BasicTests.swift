import Testing
import Foundation
@testable import BookBite

struct BasicTests {
    
    @Test("Basic test should work")
    func testBasic() {
        #expect(2 + 2 == 4)
    }
    
    @Test("String test should work")
    func testString() {
        let greeting = "Hello, World!"
        #expect(greeting.contains("World"))
    }
    
    @Test("Book model can be created")
    func testBookModel() {
        let book = Book(
            id: "test-id",
            title: "Test Book",
            subtitle: nil,
            authors: ["Test Author"],
            isbn10: nil,
            isbn13: nil,
            publishedYear: 2023,
            publisher: "Test Publisher",
            categories: ["Test"],
            coverAssetName: nil,
            description: "Test description",
            sourceAttribution: ["Test Source"]
        )
        
        #expect(book.id == "test-id")
        #expect(book.title == "Test Book")
        #expect(book.authors.first == "Test Author")
    }
}