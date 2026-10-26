import Testing
import Foundation
@testable import BookBite

struct RecommendationsTests {

    @Test("Recommendations decode shelves with server book rows and scores")
    func testDecoding() throws {
        let json = """
        {
            "shelves": [{
                "id": "for-you",
                "kind": "for-you",
                "title": "For you",
                "books": [{
                    "id": "9bac0135-48de-4216-8417-7d2754f626ec",
                    "title": "Atomic Habits",
                    "authors": ["James Clear"],
                    "categories": ["Self-Help"],
                    "is_featured": true,
                    "created_at": "2025-01-02T03:04:05.123+00:00"
                }]
            }],
            "scores": { "9bac0135-48de-4216-8417-7d2754f626ec": 0.8123 }
        }
        """

        let recommendations = try NetworkService.makeDecoder().decode(Recommendations.self, from: Data(json.utf8))

        #expect(recommendations.shelves.first?.title == "For you")
        #expect(recommendations.shelves.first?.books.first?.title == "Atomic Habits")
        #expect(recommendations.scores["9bac0135-48de-4216-8417-7d2754f626ec"] == 0.8123)
    }

    @Test("Request encodes the camelCase keys the server validates")
    func testRequestEncoding() throws {
        let request = RecommendationRequest(likedBookIds: ["a"], recentBookIds: [], goals: ["habits"], genres: ["Business"])
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]

        #expect(Set(object?.keys ?? [:].keys) == ["likedBookIds", "recentBookIds", "goals", "genres"])
        #expect(!request.isEmpty)
        #expect(RecommendationRequest(likedBookIds: [], recentBookIds: [], goals: [], genres: []).isEmpty)
    }
}
