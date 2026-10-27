import Foundation

/// The extended summary split into chapters and paragraphs, ready to set as reading text.
///
/// Chapters start at lines beginning with `## ` (the server's chapter headings). Text before the first
/// heading becomes an untitled opening chapter; text with no headings at all is one untitled chapter.
/// Every non-empty line is a paragraph. Stray markdown (`**bold**`, `*italic*`, other `#` headings,
/// bullets, links, rules) is reduced to plain text.
struct ReaderDocument: Equatable {
    struct Chapter: Equatable, Identifiable {
        /// Position in `chapters`, also the scroll target id
        let id: Int
        /// nil for the untitled opening (or the whole text when there are no headings)
        let title: String?
        let paragraphs: [String]

        var wordCount: Int {
            paragraphs.reduce(0) { $0 + ReaderDocument.wordCount(of: $1) }
        }
    }

    let chapters: [Chapter]

    /// True when the text had chapter headings, so the reader offers a contents menu
    var hasHeadings: Bool { chapters.contains { $0.title != nil } }

    var titledChapters: [Chapter] { chapters.filter { $0.title != nil } }

    var wordCount: Int { chapters.reduce(0) { $0 + $1.wordCount } }

    var isEmpty: Bool { chapters.isEmpty }

    init(chapters: [Chapter]) {
        self.chapters = chapters
    }

    init(markdown: String) {
        var chapters: [Chapter] = []
        var currentTitle: String?
        var currentParagraphs: [String] = []

        func closeChapter() {
            // A heading with nothing under it is dropped rather than shown as an empty chapter
            if !currentParagraphs.isEmpty {
                chapters.append(Chapter(id: chapters.count, title: currentTitle, paragraphs: currentParagraphs))
            }
            currentParagraphs = []
        }

        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        for rawLine in normalized.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if let heading = Self.chapterHeading(in: line) {
                closeChapter()
                currentTitle = heading
                continue
            }

            if Self.isRule(line) { continue }

            let paragraph = Self.plainText(line)
            if !paragraph.isEmpty {
                currentParagraphs.append(paragraph)
            }
        }
        closeChapter()

        self.chapters = chapters
    }

    // MARK: - Parsing helpers

    /// The chapter title when `line` is a `## ` heading (not `###`), with markdown and numbering removed.
    static func chapterHeading(in line: String) -> String? {
        guard line.hasPrefix("## ") else { return nil }
        let title = chapterTitle(from: String(line.dropFirst(3)))
        return title.isEmpty ? nil : title
    }

    /// "Chapter 2: The Habit Loop" / "2. The Habit Loop" → "The Habit Loop". The reader sets its own
    /// chapter rhythm, so numbering from the source is dropped.
    static func chapterTitle(from heading: String) -> String {
        var title = plainText(heading)
        if let match = title.prefixMatch(of: #/(?i)(?:chapter|part)\s+(?:\d+|[ivxlc]+)(?:\s*[:.\-–—]\s*|\s+)/#),
           match.output.count < title.count {
            title = String(title[match.range.upperBound...])
        } else if let match = title.prefixMatch(of: #/\d{1,2}[.):]\s+/#),
                  match.output.count < title.count {
            title = String(title[match.range.upperBound...])
        }
        return title.trimmingCharacters(in: .whitespaces)
    }

    /// `---`, `***`, `___` horizontal rules
    static func isRule(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    /// Strips markdown syntax from one line, leaving readable text.
    static func plainText(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)

        // Leading heading hashes (# Title, ### Subheading) and block quotes
        text = text.replacing(#/^#{1,6}\s*/#, with: "")
        text = text.replacing(#/^>\s?/#, with: "")
        // List bullets become a typographic bullet
        text = text.replacing(#/^[-*+]\s+/#, with: "• ")

        // Links and images: [label](url) → label
        text = text.replacing(#/!?\[([^\]]*)\]\([^)]*\)/#) { String($0.output.1) }
        // Bold and italic markers
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "__", with: "")
        text = italicMarkers.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "$1")
        text = text.replacingOccurrences(of: "`", with: "")
        // A lone hash left at the start (e.g. "#Heading")
        text = text.replacing(#/^#+/#, with: "")

        return text.trimmingCharacters(in: .whitespaces)
    }

    /// `*word*` → word (NSRegularExpression: Swift Regex lookbehind needs a newer OS)
    private static let italicMarkers = try! NSRegularExpression(
        pattern: #"(?<![\w*])\*(?=\S)([^*]+?)(?<=\S)\*(?![\w*])"#)

    static func wordCount(of text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }
}

// MARK: - Reading time

extension ReaderDocument {
    /// Same pace as `Summary.summaryReadTimeMinutes`
    static let wordsPerMinute = 200.0

    /// Whole minutes left at a reading position (0...1); at least 1 until the very end.
    func minutesLeft(at fraction: Double) -> Int {
        let remaining = Double(wordCount) * (1 - min(max(fraction, 0), 1))
        guard remaining > 0 else { return 0 }
        return max(1, Int((remaining / Self.wordsPerMinute).rounded(.up)))
    }
}

// MARK: - Hyphenation

extension ReaderDocument {
    /// A copy with soft hyphens at the language's hyphenation points, so ragged-right text can
    /// break long words instead of leaving big gaps on narrow screens or at large text sizes.
    func hyphenated(locale: Locale = .current) -> ReaderDocument {
        ReaderDocument(chapters: chapters.map { chapter in
            Chapter(id: chapter.id,
                    title: chapter.title,
                    paragraphs: chapter.paragraphs.map { Hyphenator.hyphenate($0, locale: locale) })
        })
    }
}

enum Hyphenator {
    static let softHyphen: Character = "\u{00AD}"

    /// Inserts soft hyphens into words of 7+ letters, keeping at least 3 letters on each side of a break.
    static func hyphenate(_ text: String, locale: Locale = .current) -> String {
        let cfLocale = hyphenationLocale(for: locale)
        guard let cfLocale else { return text }

        let string = text as NSString
        let cfString = string as CFString
        var breaks: [Int] = []

        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length),
                                   options: [.byWords, .substringNotRequired]) { _, range, _, _ in
            guard range.length >= 7 else { return }
            let start = range.location
            let end = range.location + range.length
            let wordRange = CFRange(location: start, length: range.length)
            var limit = end - 2
            while limit > start + 3 {
                let location = CFStringGetHyphenationLocationBeforeIndex(cfString, limit, wordRange, 0, cfLocale, nil)
                guard location != kCFNotFound, location >= start + 3 else { break }
                if location <= end - 3 { breaks.append(location) }
                limit = min(limit - 1, location)
            }
        }

        guard !breaks.isEmpty else { return text }
        let result = NSMutableString(string: string)
        for location in Set(breaks).sorted(by: >) {
            result.insert(String(softHyphen), at: location)
        }
        return result as String
    }

    private static func hyphenationLocale(for locale: Locale) -> CFLocale? {
        let candidates = [locale, Locale(identifier: "en_US")]
        return candidates
            .map { $0 as CFLocale }
            .first { CFStringIsHyphenationAvailableForLocale($0) }
    }
}
