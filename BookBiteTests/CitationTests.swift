import Foundation
import Testing
@testable import BookBite

struct CitationTests {
    @Test("Only https links with a path can be followed")
    func testLink() {
        #expect(Citation(source: "RAND", url: "https://www.rand.org/pubs/research_reports/RR2211.html").link != nil)
        #expect(Citation(source: "NYT", url: "https://www.nytimes.com").link == nil)
        #expect(Citation(source: "NYT", url: "https://www.nytimes.com/").link == nil)
        #expect(Citation(source: "Blog", url: "http://example.com/post").link == nil)
        #expect(Citation(source: "Book", url: nil).link == nil)
    }
}
