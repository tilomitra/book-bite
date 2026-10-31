import Foundation

/// Stores for "Get the full book". Links go through the server (`GET books/:id/buy`), which
/// redirects to the store with Bookgist's affiliate id, so ids can change without an app update.
enum BookStore: String, CaseIterable, Identifiable {
    case amazon, bookshop

    var id: String { rawValue }

    var name: String {
        switch self {
        case .amazon: return "Amazon"
        case .bookshop: return "Bookshop.org"
        }
    }

    var caption: String {
        switch self {
        case .amazon: return "Print, Kindle and audiobook"
        case .bookshop: return "Supports independent bookstores"
        }
    }
}

extension Book {
    /// `source` says where the tap came from (e.g. "reader"), for click counts in the server logs
    func purchaseURL(store: BookStore, source: String, baseURL: String = AppConfiguration.shared.baseServerURL) -> URL? {
        guard var components = URLComponents(string: "\(baseURL)/books/\(id)/buy") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "store", value: store.rawValue),
            URLQueryItem(name: "source", value: source)
        ]
        return components.url
    }
}
