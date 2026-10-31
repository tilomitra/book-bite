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
        Summary(
            id: "summary-\(bookId)",
            bookId: bookId,
            oneSentenceHook: "Focus is a skill.",
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
