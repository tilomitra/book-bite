import Testing
import Foundation
@testable import BookBite

struct BookModelTests {
    
    @Test("Book should decode from JSON correctly")
    func testBookDecoding() throws {
        let json = """
        {
            "id": "test_001",
            "title": "Test Book",
            "subtitle": "A Test Subtitle",
            "authors": ["Test Author"],
            "published_year": 2023,
            "categories": ["Test Category"],
            "cover_url": "test_cover",
            "description": "Test description",
            "source_attribution": ["Test Source"]
        }
        """
        
        let data = json.data(using: .utf8)!
        let book = try JSONDecoder().decode(Book.self, from: data)
        
        #expect(book.id == "test_001")
        #expect(book.title == "Test Book")
        #expect(book.subtitle == "A Test Subtitle")
        #expect(book.authors == ["Test Author"])
        #expect(book.publishedYear == 2023)
        #expect(book.formattedAuthors == "Test Author")
    }
    
    @Test("Book should handle multiple authors correctly")
    func testMultipleAuthors() throws {
        let json = """
        {
            "id": "test_002",
            "title": "Test Book 2",
            "authors": ["Author One", "Author Two", "Author Three"],
            "published_year": 2023,
            "categories": ["Test"],
            "cover_url": "test_cover",
            "description": "Test description",
            "source_attribution": ["Test Source"]
        }
        """
        
        let data = json.data(using: .utf8)!
        let book = try JSONDecoder().decode(Book.self, from: data)
        
        #expect(book.formattedAuthors == "Author One, Author Two, Author Three")
    }
    
    @Test("Book should handle optional fields")
    func testOptionalFields() throws {
        let json = """
        {
            "id": "test_003",
            "title": "Minimal Book",
            "authors": ["Test Author"],
            "published_year": 2023,
            "categories": ["Test"],
            "cover_url": "test_cover",
            "description": "Test description",
            "source_attribution": ["Test Source"]
        }
        """
        
        let data = json.data(using: .utf8)!
        let book = try JSONDecoder().decode(Book.self, from: data)
        
        #expect(book.subtitle == nil)
        #expect(book.isbn10 == nil)
        #expect(book.isbn13 == nil)
        #expect(book.publisher == nil)
    }
}