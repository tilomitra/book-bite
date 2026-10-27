import Combine
import CoreSpotlight
import Foundation
import UIKit
import UniformTypeIdentifiers

/// Puts the books the user opened, is reading or finished into Spotlight, so searching a title on the
/// Home Screen finds it in BookBite. Watches `RecentBooksStore` and `ReadingProgressStore`; only books
/// that were added or removed since the last run are (re)indexed, so covers aren't downloaded again.
@MainActor
final class SpotlightIndexer {
    static let shared = SpotlightIndexer()

    static let domain = "books"
    private static let idPrefix = "book."
    /// Bump when the item format changes, to re-index everything once
    private static let formatVersion = 1

    private let index = CSSearchableIndex.default()
    private let defaults = UserDefaults.standard
    private let indexedKey = "spotlightIndexedBookIds"
    private let versionKey = "spotlightIndexVersion"
    private var cancellable: AnyCancellable?
    private var syncTask: Task<Void, Never>?

    private init() {}

    /// Starts watching the stores. Safe to call more than once.
    func start() {
        guard cancellable == nil, CSSearchableIndex.isIndexingAvailable() else { return }

        if defaults.integer(forKey: versionKey) != Self.formatVersion {
            defaults.removeObject(forKey: indexedKey)
            defaults.set(Self.formatVersion, forKey: versionKey)
        }

        cancellable = RecentBooksStore.shared.$books
            .combineLatest(ReadingProgressStore.shared.$entries)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] recent, progress in
                self?.sync(books: progress.map(\.book) + recent)
            }
    }

    /// The book id behind a Spotlight result, from a `CSSearchableItemActionType` user activity.
    static func bookId(from activity: NSUserActivity) -> String? {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              identifier.hasPrefix(idPrefix) else { return nil }
        return String(identifier.dropFirst(idPrefix.count))
    }

    /// The locally known copy of a book (from the stores), used while the full record loads.
    static func knownBook(id: String) -> Book? {
        ReadingProgressStore.shared.entry(for: id)?.book
            ?? RecentBooksStore.shared.books.first { $0.id == id }
    }

    private func sync(books: [Book]) {
        var unique: [String: Book] = [:]
        for book in books where unique[book.id] == nil {
            unique[book.id] = book
        }

        let indexed = Set(defaults.stringArray(forKey: indexedKey) ?? [])
        let current = Set(unique.keys)
        let removed = indexed.subtracting(current)
        let added = unique.values.filter { !indexed.contains($0.id) }
        guard !removed.isEmpty || !added.isEmpty else { return }

        syncTask?.cancel()
        syncTask = Task {
            if !removed.isEmpty {
                try? await index.deleteSearchableItems(withIdentifiers: removed.map { Self.idPrefix + $0 })
            }
            var items: [CSSearchableItem] = []
            for book in added {
                guard !Task.isCancelled else { return }
                items.append(await makeItem(for: book))
            }
            if !items.isEmpty {
                do {
                    try await index.indexSearchableItems(items)
                } catch {
                    print("Spotlight indexing failed: \(error)")
                    return
                }
            }
            defaults.set(Array(current), forKey: indexedKey)
        }
    }

    private func makeItem(for book: Book) async -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = book.title
        attributes.displayName = book.title
        attributes.authorNames = book.authors
        attributes.contentDescription = description(for: book)
        attributes.keywords = book.authors + book.categories + ["summary", "book"]
        attributes.thumbnailData = await thumbnail(for: book)

        let item = CSSearchableItem(
            uniqueIdentifier: Self.idPrefix + book.id,
            domainIdentifier: Self.domain,
            attributeSet: attributes
        )
        item.expirationDate = .distantFuture
        return item
    }

    /// "Author — hook", using the summary's hook when it's cached, else the book description.
    private func description(for book: Book) -> String {
        let hook = (try? CacheService.shared.getCachedSummary(bookId: book.id))?.oneSentenceHook
        let text = [hook, book.description]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        let byline = book.authors.isEmpty ? nil : book.formattedAuthors
        return [byline, text].compactMap { $0 }.joined(separator: " — ")
    }

    private func thumbnail(for book: Book) async -> Data? {
        guard let cover = book.coverAssetName, let url = URL.bookCover(from: cover) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let image = UIImage(data: data) else { return nil }

        // Spotlight shows a small thumbnail; keep the stored data small
        let height: CGFloat = 180
        let size = CGSize(width: height * image.size.width / max(image.size.height, 1), height: height)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
