import Foundation

extension URL {
    /// Creates a URL from a string, converting HTTP Google Books URLs to HTTPS
    /// - Parameter string: The URL string, potentially with HTTP protocol
    /// - Returns: A URL with HTTPS protocol if it was a Google Books HTTP URL, nil if invalid
    static func bookCover(from string: String?) -> URL? {
        guard let urlString = string, !urlString.isEmpty else { return nil }
        
        // Convert HTTP Google Books URLs to HTTPS for security and reliability
        let httpsURL: String
        if urlString.hasPrefix("http://books.google.com") {
            httpsURL = urlString.replacingOccurrences(of: "http://", with: "https://")
        } else {
            httpsURL = urlString
        }
        
        return URL(string: httpsURL)
    }
}

/// Global helper function for backward compatibility
/// - Parameter url: The URL string to convert
/// - Returns: HTTPS version of the URL string
func httpsURL(from url: String) -> String {
    if url.hasPrefix("http://books.google.com") {
        return url.replacingOccurrences(of: "http://", with: "https://")
    }
    return url
}