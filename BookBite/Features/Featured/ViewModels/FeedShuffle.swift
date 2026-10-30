import Foundation

/// Seeded random numbers (SplitMix64), so one Discover visit can rebuild the same order
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Mixes Discover's ranked lists so the feed is different on every visit but still leans toward the best books.
enum FeedShuffle {
    /// Each item's key is log(rank + 10) plus up to `spread` of noise (same rule as the server's highlights).
    /// With 1.5 the first book competes with roughly the first 45. Items in `pushedBack` (seen on earlier
    /// visits) get `penalty` more, about 2.7 times deeper with 1.0.
    static func jittered<T, G: RandomNumberGenerator>(
        _ items: [T],
        spread: Double = 1.5,
        pushedBack: (T) -> Bool = { _ in false },
        penalty: Double = 1.0,
        using generator: inout G
    ) -> [T] {
        items.enumerated()
            .map { rank, item in
                let key = log(Double(rank + 10)) + Double.random(in: 0...spread, using: &generator)
                    + (pushedBack(item) ? penalty : 0)
                return (item, key)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }
}

/// Books Discover showed on earlier visits (UserDefaults `discoverShownBookIds`, newest last, max 300),
/// so the next feed puts them further back.
enum DiscoverHistory {
    private static let key = "discoverShownBookIds"
    private static let limit = 300

    static var shownBookIds: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func record(_ bookIds: [String]) {
        guard !bookIds.isEmpty else { return }
        let new = Set(bookIds)
        let kept = (UserDefaults.standard.stringArray(forKey: key) ?? []).filter { !new.contains($0) }
        UserDefaults.standard.set(Array((kept + bookIds).suffix(limit)), forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
