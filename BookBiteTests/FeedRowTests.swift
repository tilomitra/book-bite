import Testing
import Foundation
@testable import BookBite

/// Discover's wide (iPad) layout: shelves stay full width, editorial cards share rows of three.
struct FeedRowTests {

    private func shelf(_ id: String) -> DiscoverBlock {
        .shelf(title: id, books: [Book(id: id, title: id, authors: ["A"])])
    }

    private func card(_ id: String) throws -> DiscoverBlock {
        let json = """
        {"book": {"id": "\(id)", "title": "\(id)", "authors": ["A"]}, "hook": "Hook", "idea": {"id": "k", "idea": "Idea"}}
        """
        return .passage(try NetworkService.makeDecoder().decode(Highlight.self, from: Data(json.utf8)))
    }

    private func shape(_ rows: [FeedRow]) -> [String] {
        rows.map { row in
            switch row {
            case .block(let block): return block.id
            case .cards(let cards): return cards.map(\.id).joined(separator: "+")
            }
        }
    }

    @Test("Each card row sits where its first card was and fills with the next cards")
    func testGrouping() throws {
        let blocks = [shelf("s1"), shelf("s2"), try card("c1"), shelf("s3"), shelf("s4"), try card("c2"),
                      shelf("s5"), try card("c3"), try card("c4")]

        #expect(shape(FeedRow.wide(blocks)) == [
            "shelf:s1:s1", "shelf:s2:s2", "passage:c1+passage:c2+passage:c3", "shelf:s3:s3", "shelf:s4:s4",
            "shelf:s5:s5", "passage:c4",
        ])
    }

    @Test("Rows keep their ids as more blocks load")
    func testStableIds() throws {
        let first = [shelf("s1"), try card("c1"), shelf("s2")]
        let more = first + [try card("c2"), shelf("s3")]

        let before = FeedRow.wide(first).map(\.id)
        let after = FeedRow.wide(more).map(\.id)

        #expect(Array(after.prefix(before.count)) == before)
        #expect(after.count == before.count + 1)
    }
}
