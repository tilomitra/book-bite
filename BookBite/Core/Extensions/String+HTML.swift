import Foundation

extension String {
    /// Strips HTML tags from the string and converts common HTML entities to readable text
    var strippedHTML: String {
        var result = self
        
        // Replace common HTML entities with their text equivalents
        let htmlEntities: [String: String] = [
            "&lt;": "<",
            "&gt;": ">",
            "&amp;": "&",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&#39;": "'"
        ]
        
        for (entity, replacement) in htmlEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // Remove HTML tags using regular expression
        do {
            let regex = try NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(location: 0, length: result.count),
                withTemplate: ""
            )
        } catch {
            // If regex fails, fallback to simple replacement
            result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        
        // Clean up extra whitespace and line breaks
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return result
    }
}