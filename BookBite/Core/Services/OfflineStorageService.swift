import Foundation
import UIKit

/// Service for managing offline book storage
/// Unlike CacheService (temporary, auto-cleaned), offline storage persists until explicitly removed
class OfflineStorageService {
    static let shared = OfflineStorageService()

    private let fileManager = FileManager.default
    private let offlineDirectory: URL
    private let booksDirectory: URL
    private let summariesDirectory: URL
    private let imagesDirectory: URL
    private let audioDirectory: URL
    private let manifestPath: URL

    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        offlineDirectory = documentsPath.appendingPathComponent("BookBiteOffline")
        booksDirectory = offlineDirectory.appendingPathComponent("books")
        summariesDirectory = offlineDirectory.appendingPathComponent("summaries")
        imagesDirectory = offlineDirectory.appendingPathComponent("images")
        audioDirectory = offlineDirectory.appendingPathComponent("audio")
        manifestPath = offlineDirectory.appendingPathComponent("manifest.json")

        // Create directories if they don't exist
        try? fileManager.createDirectory(at: offlineDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: summariesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
    }

    // MARK: - File Paths

    private func bookPath(id: String) -> URL {
        booksDirectory.appendingPathComponent("\(id).json")
    }

    private func summaryPath(bookId: String) -> URL {
        summariesDirectory.appendingPathComponent("\(bookId).json")
    }

    private func imagePath(bookId: String) -> URL {
        imagesDirectory.appendingPathComponent("\(bookId).jpg")
    }

    private func audioPath(bookId: String) -> URL {
        audioDirectory.appendingPathComponent("\(bookId).mp3")
    }

    // MARK: - Manifest Management

    private func loadManifest() -> [OfflineBook] {
        guard fileManager.fileExists(atPath: manifestPath.path) else { return [] }

        do {
            let data = try Data(contentsOf: manifestPath)
            return try JSONDecoder().decode([OfflineBook].self, from: data)
        } catch {
            if AppConfiguration.shared.isLoggingEnabled {
                print("❌ OfflineStorageService: Failed to load manifest: \(error)")
            }
            return []
        }
    }

    private func saveManifest(_ manifest: [OfflineBook]) {
        do {
            let data = try JSONEncoder().encode(manifest)
            try data.write(to: manifestPath)
        } catch {
            if AppConfiguration.shared.isLoggingEnabled {
                print("❌ OfflineStorageService: Failed to save manifest: \(error)")
            }
        }
    }

    private func addToManifest(_ offlineBook: OfflineBook) {
        var manifest = loadManifest()
        // Remove existing entry if present
        manifest.removeAll { $0.bookId == offlineBook.bookId }
        manifest.append(offlineBook)
        saveManifest(manifest)
    }

    private func removeFromManifest(bookId: String) {
        var manifest = loadManifest()
        manifest.removeAll { $0.bookId == bookId }
        saveManifest(manifest)
    }

    // MARK: - Download Operations

    /// Download a book for offline access
    func downloadBookForOffline(_ book: Book, summary: Summary?) throws {
        if AppConfiguration.shared.isLoggingEnabled {
            print("📥 OfflineStorageService: Downloading book \(book.id) for offline")
        }

        // Save book data
        let bookData = try JSONEncoder().encode(book)
        try bookData.write(to: bookPath(id: book.id))

        // Save summary if available
        var hasSummary = false
        if let summary = summary {
            let summaryData = try JSONEncoder().encode(summary)
            try summaryData.write(to: summaryPath(bookId: book.id))
            hasSummary = true
        }

        // Track in manifest
        let offlineBook = OfflineBook(
            bookId: book.id,
            bookTitle: book.title,
            bookAuthors: book.authors,
            hasSummary: hasSummary,
            hasCoverImage: false
        )
        addToManifest(offlineBook)

        if AppConfiguration.shared.isLoggingEnabled {
            print("✅ OfflineStorageService: Book \(book.id) saved for offline")
        }
    }

    /// Download cover image for offline access
    func downloadCoverImage(from urlString: String, for bookId: String) async throws {
        guard let url = URL.bookCover(from: urlString) else {
            throw OfflineStorageError.invalidURL
        }

        if AppConfiguration.shared.isLoggingEnabled {
            print("📥 OfflineStorageService: Downloading cover image for book \(bookId)")
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OfflineStorageError.downloadFailed
        }

        // Save image data
        try data.write(to: imagePath(bookId: bookId))

        // Update manifest to indicate we have the cover
        var manifest = loadManifest()
        if let index = manifest.firstIndex(where: { $0.bookId == bookId }) {
            let existing = manifest[index]
            let updated = OfflineBook(
                bookId: existing.bookId,
                bookTitle: existing.bookTitle,
                bookAuthors: existing.bookAuthors,
                hasSummary: existing.hasSummary,
                hasCoverImage: true
            )
            manifest[index] = updated
            saveManifest(manifest)
        }

        if AppConfiguration.shared.isLoggingEnabled {
            print("✅ OfflineStorageService: Cover image saved for book \(bookId)")
        }
    }

    // MARK: - Retrieve Operations

    /// Get offline book data
    func getOfflineBook(id: String) -> Book? {
        let path = bookPath(id: id)
        guard fileManager.fileExists(atPath: path.path) else { return nil }

        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode(Book.self, from: data)
        } catch {
            if AppConfiguration.shared.isLoggingEnabled {
                print("❌ OfflineStorageService: Failed to load book \(id): \(error)")
            }
            return nil
        }
    }

    /// Get offline summary data
    func getOfflineSummary(bookId: String) -> Summary? {
        let path = summaryPath(bookId: bookId)
        guard fileManager.fileExists(atPath: path.path) else { return nil }

        do {
            let data = try Data(contentsOf: path)
            return try JSONDecoder().decode(Summary.self, from: data)
        } catch {
            if AppConfiguration.shared.isLoggingEnabled {
                print("❌ OfflineStorageService: Failed to load summary for book \(bookId): \(error)")
            }
            return nil
        }
    }

    /// Get offline cover image
    func getOfflineCoverImage(bookId: String) -> UIImage? {
        let path = imagePath(bookId: bookId)
        guard fileManager.fileExists(atPath: path.path) else { return nil }

        return UIImage(contentsOfFile: path.path)
    }

    /// Get offline cover image URL (for use with AsyncImage fallback)
    func getOfflineCoverImageURL(bookId: String) -> URL? {
        let path = imagePath(bookId: bookId)
        guard fileManager.fileExists(atPath: path.path) else { return nil }
        return path
    }

    // MARK: - Audio Operations

    /// Download audio file for offline access
    func downloadAudio(from urlString: String, for bookId: String) async throws {
        guard let url = URL(string: urlString) else {
            throw OfflineStorageError.invalidURL
        }

        if AppConfiguration.shared.isLoggingEnabled {
            print("OfflineStorageService: Downloading audio for book \(bookId)")
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OfflineStorageError.downloadFailed
        }

        // Save audio data
        try data.write(to: audioPath(bookId: bookId))

        // Update manifest to indicate we have audio
        updateManifestAudioStatus(bookId: bookId, hasAudio: true)

        if AppConfiguration.shared.isLoggingEnabled {
            let sizeMB = Double(data.count) / (1024 * 1024)
            print("OfflineStorageService: Audio saved for book \(bookId) (\(String(format: "%.2f", sizeMB)) MB)")
        }
    }

    /// Get offline audio URL for a book
    func getOfflineAudioURL(bookId: String) -> URL? {
        let path = audioPath(bookId: bookId)
        guard fileManager.fileExists(atPath: path.path) else { return nil }
        return path
    }

    /// Check if audio is available offline for a book
    func hasOfflineAudio(bookId: String) -> Bool {
        let path = audioPath(bookId: bookId)
        return fileManager.fileExists(atPath: path.path)
    }

    /// Remove offline audio for a book
    func removeOfflineAudio(bookId: String) {
        try? fileManager.removeItem(at: audioPath(bookId: bookId))
        updateManifestAudioStatus(bookId: bookId, hasAudio: false)
    }

    private func updateManifestAudioStatus(bookId: String, hasAudio: Bool) {
        var manifest = loadManifest()
        if let index = manifest.firstIndex(where: { $0.bookId == bookId }) {
            let existing = manifest[index]
            let updated = OfflineBook(
                bookId: existing.bookId,
                bookTitle: existing.bookTitle,
                bookAuthors: existing.bookAuthors,
                hasSummary: existing.hasSummary,
                hasCoverImage: existing.hasCoverImage,
                hasAudio: hasAudio
            )
            manifest[index] = updated
            saveManifest(manifest)
        }
    }

    // MARK: - Query Operations

    /// Get all offline books
    func getAllOfflineBooks() -> [OfflineBook] {
        return loadManifest()
    }

    /// Check if a book is downloaded for offline
    func isBookDownloadedForOffline(_ bookId: String) -> Bool {
        let manifest = loadManifest()
        return manifest.contains { $0.bookId == bookId }
    }

    // MARK: - Remove Operations

    /// Remove a single book from offline storage
    func removeOfflineBook(_ bookId: String) {
        if AppConfiguration.shared.isLoggingEnabled {
            print("🗑️ OfflineStorageService: Removing book \(bookId) from offline storage")
        }

        // Remove files
        try? fileManager.removeItem(at: bookPath(id: bookId))
        try? fileManager.removeItem(at: summaryPath(bookId: bookId))
        try? fileManager.removeItem(at: imagePath(bookId: bookId))
        try? fileManager.removeItem(at: audioPath(bookId: bookId))

        // Remove from manifest
        removeFromManifest(bookId: bookId)

        if AppConfiguration.shared.isLoggingEnabled {
            print("✅ OfflineStorageService: Book \(bookId) removed from offline storage")
        }
    }

    /// Remove all offline books
    func removeAllOfflineBooks() {
        if AppConfiguration.shared.isLoggingEnabled {
            print("🗑️ OfflineStorageService: Removing all offline books")
        }

        // Remove all content but keep directory structure
        try? fileManager.removeItem(at: offlineDirectory)
        try? fileManager.createDirectory(at: offlineDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: summariesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)

        if AppConfiguration.shared.isLoggingEnabled {
            print("✅ OfflineStorageService: All offline books removed")
        }
    }

    // MARK: - Storage Info

    /// Get information about offline storage usage
    func getOfflineStorageInfo() -> OfflineStorageInfo {
        let size = getStorageSize()
        let bookCount = loadManifest().count

        return OfflineStorageInfo(
            sizeInBytes: size,
            bookCount: bookCount,
            formattedSize: ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        )
    }

    private func getStorageSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: offlineDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }
}

// MARK: - Errors

enum OfflineStorageError: LocalizedError {
    case invalidURL
    case downloadFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid image URL"
        case .downloadFailed:
            return "Failed to download content"
        case .saveFailed:
            return "Failed to save content"
        }
    }
}
