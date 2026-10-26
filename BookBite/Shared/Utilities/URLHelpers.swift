import Foundation

extension URL {
    /// Creates a cover URL from a stored string. Google Books thumbnails are upgraded to HTTPS,
    /// stripped of the baked-in page curl (`edge=curl`) and requested at 800px wide (`fife=w800`).
    /// - Parameter string: The stored cover URL string
    /// - Returns: The cover URL, nil if empty or invalid
    static func bookCover(from string: String?) -> URL? {
        guard let urlString = string, !urlString.isEmpty else { return nil }
        guard urlString.contains("books.google.com/books/content"),
              var components = URLComponents(string: urlString) else {
            return URL(string: urlString)
        }

        components.scheme = "https"
        // Keep zoom=1: without it Google sometimes returns the title page instead of the cover
        var items = (components.queryItems ?? []).filter { $0.name != "edge" && $0.name != "fife" }
        items.append(URLQueryItem(name: "fife", value: "w800"))
        components.queryItems = items
        return components.url
    }
}
