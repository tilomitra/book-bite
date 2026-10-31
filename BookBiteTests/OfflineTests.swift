import Testing
import Foundation
@testable import BookBite

private final class StubConnectivity: ConnectivityChecking {
    let isOnline: Bool
    init(isOnline: Bool) { self.isOnline = isOnline }
}

struct OfflineRetryTests {
    private let get = HTTPMethod.GET.rawValue

    @Test("A request that failed because the device is offline isn't retried")
    func offlineErrorsAreNotRetried() {
        for code in [URLError.Code.notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff] {
            #expect(!NetworkService.shouldRetry(URLError(code), method: get, retryCount: 0, isOnline: true))
        }
    }

    @Test("Transient failures of GET requests are retried while online")
    func transientErrorsAreRetried() {
        #expect(NetworkService.shouldRetry(URLError(.timedOut), method: get, retryCount: 0, isOnline: true))
        #expect(NetworkService.shouldRetry(URLError(.networkConnectionLost), method: get, retryCount: 2, isOnline: true))
    }

    @Test("No retry when offline, cancelled, out of attempts, or not a GET")
    func otherCasesAreNotRetried() {
        let timedOut = URLError(.timedOut)
        #expect(!NetworkService.shouldRetry(timedOut, method: get, retryCount: 0, isOnline: false))
        #expect(!NetworkService.shouldRetry(URLError(.cancelled), method: get, retryCount: 0, isOnline: true))
        #expect(!NetworkService.shouldRetry(CancellationError(), method: get, retryCount: 0, isOnline: true))
        #expect(!NetworkService.shouldRetry(timedOut, method: get, retryCount: NetworkService.Configuration.maxRetryAttempts, isOnline: true))
        #expect(!NetworkService.shouldRetry(timedOut, method: HTTPMethod.POST.rawValue, retryCount: 0, isOnline: true))
    }

    @Test("Offline, a request fails at once with no connection")
    func offlineRequestFailsAtOnce() async {
        let service = NetworkService(connectivity: StubConnectivity(isOnline: false))
        let start = Date()
        do {
            let _: [String: String] = try await service.get(endpoint: "books/featured")
            Issue.record("Expected the request to fail")
        } catch NetworkError.networkFailure(let error) {
            #expect((error as? URLError)?.code == .notConnectedToInternet)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(Date().timeIntervalSince(start) < 0.5)
    }
}

struct OfflineRepositoryTests {
    private func makeBook(id: String) -> Book {
        Book(id: id, title: "Deep Work", authors: ["Cal Newport"])
    }

    private func makeSummary(bookId: String) -> Summary {
        Self.summary(bookId: bookId, hook: "Focus is a skill.")
    }

    static func summary(bookId: String, hook: String) -> Summary {
        Summary(
            id: "summary-\(bookId)",
            bookId: bookId,
            oneSentenceHook: hook,
            keyIdeas: [],
            howToApply: [],
            commonPitfalls: [],
            critiques: [],
            whoShouldRead: "Knowledge workers",
            limitations: "",
            citations: [],
            readTimeMinutes: 8,
            style: .full,
            extendedSummary: "Long text",
            audioUrl: nil,
            audioDurationSeconds: nil,
            audioFileSizeBytes: nil,
            audioVoiceId: nil
        )
    }

    @Test("Offline, a downloaded book and its summary come from the device without waiting")
    func offlineUsesDownloadedCopy() async throws {
        // A unique id: other suites clear the shared cache, but not offline storage
        let id = "offline-test-\(UUID().uuidString)"
        let storage = OfflineStorageService.shared
        try storage.downloadBookForOffline(makeBook(id: id), summary: makeSummary(bookId: id))
        defer { storage.removeOfflineBook(id) }

        let repository = HybridBookRepository(connectivity: StubConnectivity(isOnline: false))
        let start = Date()
        let book = try await repository.fetchBook(by: id)
        let summary = try await repository.fetchSummary(for: id)

        #expect(book?.title == "Deep Work")
        #expect(summary?.oneSentenceHook == "Focus is a skill.")
        #expect(Date().timeIntervalSince(start) < 0.5)
    }
}

struct OfflineBookRulesTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private func entry(_ id: String, reason: OfflineBook.Reason, daysAgo: Double = 0, refreshedDaysAgo: Double? = nil) -> OfflineBook {
        let downloaded = now.addingTimeInterval(-daysAgo * day)
        return OfflineBook(bookId: id, bookTitle: id, bookAuthors: [], reason: reason, downloadedAt: downloaded,
                           refreshedAt: refreshedDaysAgo.map { now.addingTimeInterval(-$0 * day) })
    }

    @Test("Downloads from older versions were favorites and count as saved")
    func legacyManifestDecodesAsSaved() throws {
        let json = #"[{"bookId":"b1","downloadedAt":5,"bookTitle":"T","bookAuthors":["A"],"hasSummary":true,"hasCoverImage":false}]"#
        let books = try JSONDecoder().decode([OfflineBook].self, from: Data(json.utf8))
        #expect(books.first?.reason == .saved)
        #expect(books.first?.hasAudio == false)
        #expect(books.first?.refreshedAt == books.first?.downloadedAt)
    }

    @Test("A reading copy goes 30 days after the book is finished; saved books and unfinished books stay")
    func expiredReadingCopies() {
        let books = [
            entry("finished-long-ago", reason: .reading, daysAgo: 60),
            entry("finished-recently", reason: .reading, daysAgo: 60),
            entry("in-progress", reason: .reading, daysAgo: 60),
            entry("no-progress-old", reason: .reading, daysAgo: 31),
            entry("no-progress-new", reason: .reading, daysAgo: 2),
            entry("saved-finished", reason: .saved, daysAgo: 60),
        ]
        let progress: [String: Date?] = [
            "finished-long-ago": now.addingTimeInterval(-31 * day),
            "finished-recently": now.addingTimeInterval(-5 * day),
            "in-progress": Date?.none,
            "saved-finished": now.addingTimeInterval(-90 * day),
        ]
        let expired = OfflineBook.expiredReadingCopies(books, progress: progress, now: now)
        #expect(Set(expired) == ["finished-long-ago", "no-progress-old"])
    }

    @Test("Stale downloads come oldest first, up to the limit")
    func staleDownloads() {
        let books = [
            entry("fresh", reason: .saved, refreshedDaysAgo: 1),
            entry("old", reason: .saved, refreshedDaysAgo: 10),
            entry("oldest", reason: .reading, refreshedDaysAgo: 40),
            entry("older", reason: .saved, refreshedDaysAgo: 20),
        ]
        let stale = OfflineBook.stale(books, maxAge: 7 * day, limit: 2, now: now)
        #expect(stale.map(\.bookId) == ["oldest", "older"])
    }
}

struct OfflineStorageTests {
    private let storage = OfflineStorageService.shared

    private func makeBook(id: String) -> Book {
        Book(id: id, title: "Atomic Habits", authors: ["James Clear"])
    }

    @Test("Keeping a saved book for reading doesn't make it a reading copy")
    func savedIsNeverDowngraded() throws {
        let id = "offline-test-\(UUID().uuidString)"
        defer { storage.removeOfflineBook(id) }

        try storage.downloadBookForOffline(makeBook(id: id), summary: nil, reason: .saved)
        try storage.downloadBookForOffline(makeBook(id: id), summary: nil, reason: .reading)
        #expect(storage.offlineBook(id: id)?.reason == .saved)
    }

    @Test("Saving a reading copy makes it saved")
    func readingCopyBecomesSaved() throws {
        let id = "offline-test-\(UUID().uuidString)"
        defer { storage.removeOfflineBook(id) }

        try storage.downloadBookForOffline(makeBook(id: id), summary: nil, reason: .reading)
        #expect(storage.offlineBook(id: id)?.reason == .reading)
        try storage.downloadBookForOffline(makeBook(id: id), summary: nil, reason: .saved)
        #expect(storage.offlineBook(id: id)?.reason == .saved)
    }

    @Test("A newer summary replaces the downloaded one, and is ignored for books not on the device")
    func updateDownloadedSummary() throws {
        let id = "offline-test-\(UUID().uuidString)"
        let other = "offline-test-\(UUID().uuidString)"
        defer { storage.removeOfflineBook(id) }

        try storage.downloadBookForOffline(makeBook(id: id), summary: nil, reason: .reading)
        #expect(storage.offlineBook(id: id)?.hasSummary == false)

        storage.updateDownloadedSummary(OfflineRepositoryTests.summary(bookId: id, hook: "Small habits compound."))
        #expect(storage.getOfflineSummary(bookId: id)?.oneSentenceHook == "Small habits compound.")
        #expect(storage.offlineBook(id: id)?.hasSummary == true)

        storage.updateDownloadedSummary(OfflineRepositoryTests.summary(bookId: other, hook: "Not kept"))
        #expect(storage.getOfflineSummary(bookId: other) == nil)
        #expect(storage.offlineBook(id: other) == nil)
    }
}
