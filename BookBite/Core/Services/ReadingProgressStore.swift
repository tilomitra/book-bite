import Foundation

/// How far the user has read each summary, and which ones they finished. Stored on device (UserDefaults),
/// so it works without sign-in. The reader writes it; Discover's "Continue reading" and Library's
/// "Finished" shelf read it.
@MainActor
final class ReadingProgressStore: ObservableObject {
    static let shared = ReadingProgressStore()

    struct Entry: Codable, Identifiable, Equatable {
        let book: Book
        /// 0...1 through the summary text
        var fraction: Double
        /// Index of the chapter the reader was last in
        var chapterIndex: Int
        /// Minutes to read the whole summary, so "N min left" works without the summary at hand
        var totalMinutes: Int?
        var updatedAt: Date
        var finishedAt: Date?

        var id: String { book.id }
        var isFinished: Bool { finishedAt != nil }

        static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.book.id == rhs.book.id && lhs.fraction == rhs.fraction
                && lhs.chapterIndex == rhs.chapterIndex && lhs.finishedAt == rhs.finishedAt
        }
    }

    /// Newest first
    @Published private(set) var entries: [Entry] = []

    // ISO 8601 dates to match `NetworkService.makeDecoder()`, which reads them back
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let defaults: UserDefaults
    private let key = "readingProgress"
    private let limit = 200

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? NetworkService.makeDecoder().decode([Entry].self, from: data) {
            entries = saved
        }
    }

    /// Started but not finished, newest first. Ignores books barely opened (under 3%).
    var inProgress: [Entry] {
        entries.filter { !$0.isFinished && $0.fraction >= 0.03 }
    }

    /// Finished, most recently finished first
    var finished: [Entry] {
        entries.filter(\.isFinished).sorted { ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast) }
    }

    func entry(for bookId: String) -> Entry? {
        entries.first { $0.book.id == bookId }
    }

    /// Records the reading position. Never moves a finished book back to unfinished.
    func update(_ book: Book, fraction: Double, chapterIndex: Int, totalMinutes: Int? = nil) {
        let clamped = min(max(fraction, 0), 1)
        var entry = entry(for: book.id)
            ?? Entry(book: book, fraction: 0, chapterIndex: 0, updatedAt: Date(), finishedAt: nil)
        entry.fraction = clamped
        entry.chapterIndex = chapterIndex
        if let totalMinutes { entry.totalMinutes = totalMinutes }
        entry.updatedAt = Date()
        upsert(entry)
    }

    func markFinished(_ book: Book) {
        var entry = entry(for: book.id)
            ?? Entry(book: book, fraction: 1, chapterIndex: 0, updatedAt: Date(), finishedAt: nil)
        entry.fraction = 1
        entry.updatedAt = Date()
        if entry.finishedAt == nil { entry.finishedAt = Date() }
        upsert(entry)
    }

    func remove(bookId: String) {
        entries.removeAll { $0.book.id == bookId }
        save()
    }

    func clear() {
        entries = []
        defaults.removeObject(forKey: key)
    }

    private func upsert(_ entry: Entry) {
        var updated = entries.filter { $0.book.id != entry.book.id }
        updated.insert(entry, at: 0)
        entries = Array(updated.prefix(limit))
        save()
    }

    private func save() {
        if let data = try? Self.encoder.encode(entries) {
            defaults.set(data, forKey: key)
        }
    }
}
