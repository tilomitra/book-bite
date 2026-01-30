import Foundation
import Combine

@MainActor
class DownloadedBooksViewModel: ObservableObject {
    @Published var offlineBooks: [OfflineBook] = []
    @Published var storageInfo: OfflineStorageInfo?
    @Published var isLoading = false
    @Published var showingRemoveAllAlert = false

    private let offlineStorage = OfflineStorageService.shared

    init() {
        loadOfflineBooks()
    }

    func loadOfflineBooks() {
        isLoading = true

        offlineBooks = offlineStorage.getAllOfflineBooks()
            .sorted { $0.downloadedAt > $1.downloadedAt } // Most recent first
        storageInfo = offlineStorage.getOfflineStorageInfo()

        isLoading = false
    }

    func removeBook(at offsets: IndexSet) {
        for index in offsets {
            let book = offlineBooks[index]
            offlineStorage.removeOfflineBook(book.bookId)
        }
        loadOfflineBooks()
    }

    func removeBook(_ bookId: String) {
        offlineStorage.removeOfflineBook(bookId)
        loadOfflineBooks()
    }

    func removeAllBooks() {
        offlineStorage.removeAllOfflineBooks()
        loadOfflineBooks()
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
