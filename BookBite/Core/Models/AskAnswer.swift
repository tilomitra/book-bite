import Foundation

/// An Ask answer split into the parts the conversation shows. The server writes plain text in a fixed shape
/// (see `ASK_SYSTEM_PROMPT` in server/src/services/askService.ts):
///
///     The direct answer.
///
///     One sentence leading in.
///     - **Lead.** Body. [1]
///
///     This week: one action
///     Other side: one caveat
///
/// Parsing is tolerant: anything that doesn't fit becomes a paragraph, so a model that drifts from the
/// format still reads fine. With `streaming`, a half-written last line that could still become a
/// section label or a citation is held back, so it doesn't flash up as a paragraph.
struct AskAnswer: Equatable {
    struct Point: Equatable {
        var lead: String
        var body: String
        /// 1-based source numbers
        var sources: [Int]
    }

    /// The first paragraph: the direct answer
    var lead = ""
    var paragraphs: [String] = []
    var points: [Point] = []
    var thisWeek: String?
    var otherSide: String?
    /// Sources cited outside points (follow-up answers are often just prose)
    var proseSources: [Int] = []

    var isEmpty: Bool { lead.isEmpty && points.isEmpty }

    /// Every cited source number, in order of first citation
    var citedSources: [Int] {
        var seen = Set<Int>()
        return (points.flatMap(\.sources) + proseSources).filter { seen.insert($0).inserted }
    }

    private static let thisWeekLabel = "This week:"
    private static let otherSideLabel = "Other side:"

    init(parsing text: String, streaming: Bool = false) {
        var lines = text.components(separatedBy: "\n")
        if streaming, let last = lines.last, !last.isEmpty, Self.mightBecomeLabel(last) {
            lines.removeLast()
        }

        var paragraph: [String] = []
        func endParagraph() {
            guard !paragraph.isEmpty else { return }
            let (body, sources) = Self.extractCitations(paragraph.joined(separator: " "))
            let clean = Self.stripMarkdown(body)
            proseSources += sources
            if lead.isEmpty && points.isEmpty && paragraphs.isEmpty {
                lead = clean
            } else if !clean.isEmpty {
                paragraphs.append(clean)
            }
            paragraph = []
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                endParagraph()
            } else if let rest = Self.value(of: Self.thisWeekLabel, in: line) {
                endParagraph()
                thisWeek = Self.stripMarkdown(Self.extractCitations(rest).text)
            } else if let rest = Self.value(of: Self.otherSideLabel, in: line) {
                endParagraph()
                otherSide = Self.stripMarkdown(Self.extractCitations(rest).text)
            } else if let item = Self.listItem(line) {
                endParagraph()
                points.append(Self.point(from: item))
            } else {
                paragraph.append(line)
            }
        }
        endParagraph()
    }

    /// "This week: Do X" → "Do X", also when the model bolds the label
    private static func value(of label: String, in line: String) -> String? {
        let plain = line.replacingOccurrences(of: "**", with: "")
        guard plain.lowercased().hasPrefix(label.lowercased()) else { return nil }
        return String(plain.dropFirst(label.count)).trimmingCharacters(in: .whitespaces)
    }

    /// The text of "- x", "* x", "• x" or "1. x"; nil for other lines
    private static func listItem(_ line: String) -> String? {
        for marker in ["- ", "* ", "• "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        if let match = line.range(of: #"^\d{1,2}[.)]\s+"#, options: .regularExpression) {
            return String(line[match.upperBound...])
        }
        return nil
    }

    /// "**Lead.** Body [2]" → lead "Lead.", body "Body", sources [2]
    private static func point(from item: String) -> Point {
        let (text, sources) = extractCitations(item)
        if text.hasPrefix("**"), let close = text.range(of: "**", range: text.index(text.startIndex, offsetBy: 2)..<text.endIndex) {
            let lead = text[text.index(text.startIndex, offsetBy: 2)..<close.lowerBound].trimmingCharacters(in: .whitespaces)
            let body = text[close.upperBound...].trimmingCharacters(in: .whitespaces)
            return Point(lead: lead, body: stripMarkdown(body), sources: sources)
        }
        return Point(lead: "", body: stripMarkdown(text), sources: sources)
    }

    /// Removes "[1]", "[1][2]" and "[1, 2]" citations and returns their numbers. A trailing "[" or "[1"
    /// being streamed is dropped too.
    static func extractCitations(_ text: String) -> (text: String, sources: [Int]) {
        var sources: [Int] = []
        var result = text
        let pattern = #"\s*\[(\d+(?:\s*,\s*\d+)*)\]"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(result.startIndex..., in: result)
            for match in regex.matches(in: result, range: range) {
                if let numbers = Range(match.range(at: 1), in: result) {
                    sources += result[numbers].split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                }
            }
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        if let partial = result.range(of: #"\s*\[\d*$"#, options: .regularExpression) {
            result.removeSubrange(partial)
        }
        return (result.trimmingCharacters(in: .whitespaces), sources)
    }

    private static func stripMarkdown(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// A line still being written that could turn into "This week:", "Other side:" or a list marker
    private static func mightBecomeLabel(_ line: String) -> Bool {
        let plain = line.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces).lowercased()
        if plain.isEmpty { return true }
        return [thisWeekLabel, otherSideLabel].contains { label in
            label.lowercased().hasPrefix(plain) && plain.count < label.count
        }
    }
}
