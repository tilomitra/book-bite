import Foundation

/// Model tracking offline download metadata
struct OfflineBook: Codable, Identifiable, Equatable {
    /// Why the book is on the device. A saved book stays until removed; a book kept for reading goes
    /// some time after it is finished (see `OfflineBook.expiredReadingCopies`).
    enum Reason: String, Codable {
        case saved
        case reading
    }

    let bookId: String
    let downloadedAt: Date
    var bookTitle: String
    var bookAuthors: [String]
    var hasSummary: Bool
    var hasCoverImage: Bool
    var hasAudio: Bool
    var reason: Reason
    /// When the book and summary were last written from the server
    var refreshedAt: Date

    var id: String { bookId }

    init(
        bookId: String,
        bookTitle: String,
        bookAuthors: [String],
        hasSummary: Bool = false,
        hasCoverImage: Bool = false,
        hasAudio: Bool = false,
        reason: Reason = .saved,
        downloadedAt: Date = Date(),
        refreshedAt: Date? = nil
    ) {
        self.bookId = bookId
        self.downloadedAt = downloadedAt
        self.bookTitle = bookTitle
        self.bookAuthors = bookAuthors
        self.hasSummary = hasSummary
        self.hasCoverImage = hasCoverImage
        self.hasAudio = hasAudio
        self.reason = reason
        self.refreshedAt = refreshedAt ?? downloadedAt
    }

    // Custom decoder to handle legacy data: no hasAudio, reason (all were favorites) or refreshedAt
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookId = try container.decode(String.self, forKey: .bookId)
        downloadedAt = try container.decode(Date.self, forKey: .downloadedAt)
        bookTitle = try container.decode(String.self, forKey: .bookTitle)
        bookAuthors = try container.decode([String].self, forKey: .bookAuthors)
        hasSummary = try container.decode(Bool.self, forKey: .hasSummary)
        hasCoverImage = try container.decode(Bool.self, forKey: .hasCoverImage)
        hasAudio = try container.decodeIfPresent(Bool.self, forKey: .hasAudio) ?? false
        reason = try container.decodeIfPresent(Reason.self, forKey: .reason) ?? .saved
        refreshedAt = try container.decodeIfPresent(Date.self, forKey: .refreshedAt) ?? downloadedAt
    }

    private enum CodingKeys: String, CodingKey {
        case bookId, downloadedAt, bookTitle, bookAuthors, hasSummary, hasCoverImage, hasAudio, reason, refreshedAt
    }
}

extension OfflineBook {
    /// How long a book kept for reading stays after it is finished
    static let readingCopyLifetime: TimeInterval = 30 * 24 * 60 * 60

    /// Ids of reading copies to remove: finished more than `readingCopyLifetime` ago, or with no reading
    /// progress at all (cleared, or dropped from the store) and downloaded longer ago than that.
    /// `progress` maps book id to its finish date, or nil while unfinished. Saved books are never returned.
    static func expiredReadingCopies(_ books: [OfflineBook], progress: [String: Date?], now: Date = Date()) -> [String] {
        let cutoff = now.addingTimeInterval(-readingCopyLifetime)
        return books.filter { book in
            guard book.reason == .reading else { return false }
            guard let entry = progress[book.bookId] else { return book.downloadedAt < cutoff }
            guard let finishedAt = entry else { return false }
            return finishedAt < cutoff
        }
        .map(\.bookId)
    }

    /// Downloads not refreshed for `maxAge`, oldest first, at most `limit`
    static func stale(_ books: [OfflineBook], maxAge: TimeInterval, limit: Int, now: Date = Date()) -> [OfflineBook] {
        let cutoff = now.addingTimeInterval(-maxAge)
        return Array(books.filter { $0.refreshedAt < cutoff }
            .sorted { $0.refreshedAt < $1.refreshedAt }
            .prefix(limit))
    }
}

/// Information about offline storage usage
struct OfflineStorageInfo {
    let sizeInBytes: Int64
    let bookCount: Int
    let formattedSize: String
}
