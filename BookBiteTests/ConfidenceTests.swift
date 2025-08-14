import Testing
import Foundation
@testable import BookBite

struct ConfidenceTests {
    
    @Test("Confidence should decode from string values")
    func testConfidenceDecoding() throws {
        let highJson = "\"high\"".data(using: .utf8)!
        let mediumJson = "\"medium\"".data(using: .utf8)!
        let lowJson = "\"low\"".data(using: .utf8)!
        
        let high = try JSONDecoder().decode(Confidence.self, from: highJson)
        let medium = try JSONDecoder().decode(Confidence.self, from: mediumJson)
        let low = try JSONDecoder().decode(Confidence.self, from: lowJson)
        
        #expect(high == .high)
        #expect(medium == .medium)
        #expect(low == .low)
    }
    
    @Test("Confidence should provide correct display text")
    func testDisplayText() {
        #expect(Confidence.high.displayText == "High Confidence")
        #expect(Confidence.medium.displayText == "Medium Confidence")
        #expect(Confidence.low.displayText == "Low Confidence")
    }
    
    @Test("Confidence should provide correct color")
    func testColor() {
        #expect(Confidence.high.color == "green")
        #expect(Confidence.medium.color == "orange")
        #expect(Confidence.low.color == "yellow")
    }
}