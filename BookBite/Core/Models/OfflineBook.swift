import Foundation

/// Model tracking offline download metadata
struct OfflineBook: Codable, Identifiable {
    let bookId: String
    let downloadedAt: Date
    let bookTitle: String
    let bookAuthors: [String]
    let hasSummary: Bool
    let hasCoverImage: Bool
    let hasAudio: Bool

    var id: String { bookId }

    init(
        bookId: String,
        bookTitle: String,
        bookAuthors: [String],
        hasSummary: Bool = false,
        hasCoverImage: Bool = false,
        hasAudio: Bool = false
    ) {
        self.bookId = bookId
        self.downloadedAt = Date()
        self.bookTitle = bookTitle
        self.bookAuthors = bookAuthors
        self.hasSummary = hasSummary
        self.hasCoverImage = hasCoverImage
        self.hasAudio = hasAudio
    }

    // Custom decoder to handle legacy data without hasAudio field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bookId = try container.decode(String.self, forKey: .bookId)
        downloadedAt = try container.decode(Date.self, forKey: .downloadedAt)
        bookTitle = try container.decode(String.self, forKey: .bookTitle)
        bookAuthors = try container.decode([String].self, forKey: .bookAuthors)
        hasSummary = try container.decode(Bool.self, forKey: .hasSummary)
        hasCoverImage = try container.decode(Bool.self, forKey: .hasCoverImage)
        hasAudio = try container.decodeIfPresent(Bool.self, forKey: .hasAudio) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case bookId, downloadedAt, bookTitle, bookAuthors, hasSummary, hasCoverImage, hasAudio
    }
}

/// Information about offline storage usage
struct OfflineStorageInfo {
    let sizeInBytes: Int64
    let bookCount: Int
    let formattedSize: String
}
