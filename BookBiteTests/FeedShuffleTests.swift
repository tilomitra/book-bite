import Testing
import Foundation
@testable import BookBite

/// Discover's per-visit order: the same seed rebuilds the same feed, a new seed mixes it.
struct FeedShuffleTests {

    private let ranked = Array(0..<200)

    private func shuffled(seed: UInt64, pushedBack: Set<Int> = []) -> [Int] {
        var generator = SeededGenerator(seed: seed)
        return FeedShuffle.jittered(ranked, pushedBack: { pushedBack.contains($0) }, using: &generator)
    }

    @Test("The same seed gives the same order")
    func testSameSeed() {
        #expect(shuffled(seed: 42) == shuffled(seed: 42))
    }

    @Test("A new seed gives a different order with the same items")
    func testNewSeed() {
        let first = shuffled(seed: 1)
        let second = shuffled(seed: 2)
        #expect(first != second)
        #expect(first.sorted() == ranked)
    }

    @Test("Top-ranked items still lead on average")
    func testLeansToTop() {
        for seed: UInt64 in [3, 4, 5] {
            let top = shuffled(seed: seed).prefix(12)
            #expect(Double(top.reduce(0, +)) / Double(top.count) < 50)
        }
    }

    @Test("Items shown on an earlier visit move back")
    func testPushedBack() {
        let seen = Set(0..<10)
        for seed: UInt64 in [6, 7, 8] {
            let order = shuffled(seed: seed, pushedBack: seen)
            let firstSeen = order.firstIndex { seen.contains($0) } ?? order.count
            let plain = shuffled(seed: seed).firstIndex { seen.contains($0) } ?? order.count
            #expect(firstSeen >= plain)
        }
    }
}
