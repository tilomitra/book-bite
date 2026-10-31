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

    // The reader, the book page and launch refreshes write from different tasks; every read-modify-write holds it
    private let manifestLock = NSRecursiveLock()

    private func loadManifest() -> [OfflineBook] {
        manifestLock.lock()
        defer { manifestLock.unlock() }
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
        manifestLock.lock()
        defer { manifestLock.unlock() }
        do {
            let data = try JSONEncoder().encode(manifest)
            try data.write(to: manifestPath, options: .atomic)
        } catch {
            if AppConfiguration.shared.isLoggingEnabled {
                print("❌ OfflineStorageService: Failed to save manifest: \(error)")
            }
        }
    }

    private func updateManifest(_ change: (inout [OfflineBook]) -> Void) {
        manifestLock.lock()
        defer { manifestLock.unlock() }
        var manifest = loadManifest()
        change(&manifest)
        saveManifest(manifest)
    }

    private func updateEntry(bookId: String, _ change: (inout OfflineBook) -> Void) {
        updateManifest { manifest in
            guard let index = manifest.firstIndex(where: { $0.bookId == bookId }) else { return }
            change(&manifest[index])
        }
    }

    private func removeFromManifest(bookId: String) {
        updateManifest { $0.removeAll { $0.bookId == bookId } }
    }

    // MARK: - Download Operations

    /// Download a book for offline access. A saved book stays saved when it is kept again for reading;
    /// the cover and audio already on the device stay.
    func downloadBookForOffline(_ book: Book, summary: Summary?, reason: OfflineBook.Reason = .saved) throws {
        if AppConfiguration.shared.isLoggingEnabled {
            print("📥 OfflineStorageService: Downloading book \(book.id) for offline (\(reason.rawValue))")
        }

        // Save book data
        let bookData = try JSONEncoder().encode(book)
        try bookData.write(to: bookPath(id: book.id), options: .atomic)

        // Save summary if available
        if let summary = summary {
            let summaryData = try JSONEncoder().encode(summary)
            try summaryData.write(to: summaryPath(bookId: book.id), options: .atomic)
        }
        let hasSummary = fileManager.fileExists(atPath: summaryPath(bookId: book.id).path)

        // Track in manifest
        updateManifest { manifest in
            if let index = manifest.firstIndex(where: { $0.bookId == book.id }) {
                var entry = manifest[index]
                entry.bookTitle = book.title
                entry.bookAuthors = book.authors
                entry.hasSummary = hasSummary
                entry.refreshedAt = Date()
                if reason == .saved { entry.reason = .saved }
                manifest[index] = entry
            } else {
                manifest.append(OfflineBook(
                    bookId: book.id,
                    bookTitle: book.title,
                    bookAuthors: book.authors,
                    hasSummary: hasSummary,
                    reason: reason
                ))
            }
        }

        if AppConfiguration.shared.isLoggingEnabled {
            print("✅ OfflineStorageService: Book \(book.id) saved for offline")
        }
    }

    /// Writes a newer copy of a downloaded book. Does nothing for books not on the device.
    func updateDownloadedBook(_ book: Book) {
        guard isBookDownloadedForOffline(book.id),
              let data = try? JSONEncoder().encode(book) else { return }
        try? data.write(to: bookPath(id: book.id), options: .atomic)
        updateEntry(bookId: book.id) { entry in
            entry.bookTitle = book.title
            entry.bookAuthors = book.authors
        }
    }

    /// Writes a newer summary of a downloaded book, so a rewritten summary reaches the device.
    /// Does nothing for books not on the device.
    func updateDownloadedSummary(_ summary: Summary) {
        guard isBookDownloadedForOffline(summary.bookId),
              let data = try? JSONEncoder().encode(summary),
              (try? data.write(to: summaryPath(bookId: summary.bookId), options: .atomic)) != nil else { return }
        updateEntry(bookId: summary.bookId) { entry in
            entry.hasSummary = true
            entry.refreshedAt = Date()
        }
    }

    /// Records a refresh attempt, so a book the server can't refresh doesn't hold up the others
    func markRefreshed(bookId: String) {
        updateEntry(bookId: bookId) { $0.refreshedAt = Date() }
    }

    /// The download's entry, if the book is on the device
    func offlineBook(id: String) -> OfflineBook? {
        loadManifest().first { $0.bookId == id }
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
        try data.write(to: imagePath(bookId: bookId), options: .atomic)

        // Update manifest to indicate we have the cover
        updateEntry(bookId: bookId) { $0.hasCoverImage = true }

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
        updateEntry(bookId: bookId) { $0.hasAudio = hasAudio }
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
