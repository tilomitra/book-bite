import Foundation

extension URL {
    /// Creates a cover URL from a stored string. Google Books thumbnails are upgraded to HTTPS,
    /// stripped of the baked-in page curl (`edge=curl`) and requested at 800px wide (`fife=w800`).
    /// With `maxWidth`, Google and Apple covers come at that width, which is 2–4x smaller on the wire
    /// than the stored size. Open Library covers can't be resized.
    /// - Parameters:
    ///   - string: The stored cover URL string
    ///   - maxWidth: The width in pixels to ask the host for
    /// - Returns: The cover URL, nil if empty or invalid
    static func bookCover(from string: String?, maxWidth: Int? = nil) -> URL? {
        guard let urlString = string, !urlString.isEmpty else { return nil }

        if let maxWidth, urlString.contains("mzstatic.com"),
           let size = urlString.range(of: #"/\d+x\d+bb\.jpg$"#, options: .regularExpression) {
            return URL(string: urlString.replacingCharacters(in: size, with: "/\(maxWidth)x\(maxWidth * 3 / 2)bb.jpg"))
        }

        if let maxWidth, urlString.contains("books.google.com/books/publisher/content"),
           var components = URLComponents(string: urlString) {
            var items = (components.queryItems ?? []).filter { $0.name != "fife" }
            items.append(URLQueryItem(name: "fife", value: "w\(maxWidth)-h\(maxWidth * 3 / 2)"))
            components.queryItems = items
            return components.url
        }

        guard urlString.contains("books.google.com/books/content"),
              var components = URLComponents(string: urlString) else {
            return URL(string: urlString)
        }

        components.scheme = "https"
        // Keep zoom=1: without it Google sometimes returns the title page instead of the cover
        var items = (components.queryItems ?? []).filter { $0.name != "edge" && $0.name != "fife" }
        items.append(URLQueryItem(name: "fife", value: "w\(maxWidth ?? 800)"))
        components.queryItems = items
        return components.url
    }
}
