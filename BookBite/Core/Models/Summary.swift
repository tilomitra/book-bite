import Foundation

struct Summary: Identifiable, Codable {
    let id: String
    let bookId: String
    let oneSentenceHook: String
    let keyIdeas: [KeyIdea]
    let howToApply: [ApplicationPoint]
    let commonPitfalls: [String]
    let critiques: [String]
    let whoShouldRead: String
    let limitations: String
    let citations: [Citation]
    let readTimeMinutes: Int
    let style: SummaryStyle
    let extendedSummary: String?

    // Audio fields
    let audioUrl: String?
    let audioDurationSeconds: Int?
    let audioFileSizeBytes: Int?
    let audioVoiceId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case bookId = "book_id"
        case oneSentenceHook = "one_sentence_hook"
        case keyIdeas = "key_ideas"
        case howToApply = "how_to_apply"
        case commonPitfalls = "common_pitfalls"
        case critiques
        case whoShouldRead = "who_should_read"
        case limitations
        case citations
        case readTimeMinutes = "read_time_minutes"
        case style
        case extendedSummary = "extended_summary"
        case audioUrl = "audio_url"
        case audioDurationSeconds = "audio_duration_seconds"
        case audioFileSizeBytes = "audio_file_size_bytes"
        case audioVoiceId = "audio_voice_id"
    }

    enum SummaryStyle: String, Codable {
        case brief
        case full
    }

    /// Minutes to read the summary itself (~200 wpm). The stored read_time_minutes is an LLM
    /// estimate that is often the length of the whole book (e.g. 300), so prefer the real text.
    var summaryReadTimeMinutes: Int {
        guard let text = extendedSummary, !text.isEmpty else { return readTimeMinutes }
        let words = text.split(whereSeparator: { $0.isWhitespace }).count
        return max(1, Int((Double(words) / 200.0).rounded(.up)))
    }

    /// True when there is an extended summary to read in full
    var hasFullText: Bool {
        !(extendedSummary ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Returns true if audio summary is available
    var hasAudio: Bool {
        audioUrl != nil && !audioUrl!.isEmpty
    }

    /// Returns formatted audio duration (e.g., "10:24")
    var formattedAudioDuration: String? {
        guard let seconds = audioDurationSeconds else { return nil }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// Lenient decoding: the DB columns behind these fields are nullable and LLM output varies,
// so a single missing field must not make the whole summary fail to load.
extension Summary {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        bookId = try c.decode(String.self, forKey: .bookId)
        oneSentenceHook = try c.decodeIfPresent(String.self, forKey: .oneSentenceHook) ?? ""
        keyIdeas = try c.decodeIfPresent([KeyIdea].self, forKey: .keyIdeas) ?? []
        howToApply = try c.decodeIfPresent([ApplicationPoint].self, forKey: .howToApply) ?? []
        commonPitfalls = try c.decodeIfPresent([String].self, forKey: .commonPitfalls) ?? []
        critiques = try c.decodeIfPresent([String].self, forKey: .critiques) ?? []
        whoShouldRead = try c.decodeIfPresent(String.self, forKey: .whoShouldRead) ?? ""
        limitations = try c.decodeIfPresent(String.self, forKey: .limitations) ?? ""
        citations = try c.decodeIfPresent([Citation].self, forKey: .citations) ?? []
        readTimeMinutes = try c.decodeIfPresent(Int.self, forKey: .readTimeMinutes) ?? 0
        style = (try? c.decodeIfPresent(SummaryStyle.self, forKey: .style)) ?? .full
        extendedSummary = try c.decodeIfPresent(String.self, forKey: .extendedSummary)
        audioUrl = try c.decodeIfPresent(String.self, forKey: .audioUrl)
        audioDurationSeconds = try c.decodeIfPresent(Int.self, forKey: .audioDurationSeconds)
        audioFileSizeBytes = try c.decodeIfPresent(Int.self, forKey: .audioFileSizeBytes)
        audioVoiceId = try c.decodeIfPresent(String.self, forKey: .audioVoiceId)
    }
}

struct KeyIdea: Identifiable, Codable {
    let id: String
    let idea: String
    let tags: [String]
    let confidence: Confidence
    let sources: [String]
}

extension KeyIdea {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        idea = try c.decode(String.self, forKey: .idea)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        // Unknown/odd casing from the LLM falls back to medium
        let rawConfidence = (try? c.decodeIfPresent(String.self, forKey: .confidence)) ?? nil
        confidence = rawConfidence.flatMap { Confidence(rawValue: $0.lowercased()) } ?? .medium
        sources = try c.decodeIfPresent([String].self, forKey: .sources) ?? []
    }
}

struct ApplicationPoint: Identifiable, Codable {
    let id: String
    let action: String
    let tags: [String]
}

struct Citation: Codable, Hashable {
    let source: String
    let url: String?

    /// A link worth following. Generated citations often point at a site's home page
    /// ("https://www.nytimes.com"), which proves nothing, so those stay plain text.
    var link: URL? {
        guard let url, let parsed = URL(string: url), parsed.scheme?.lowercased() == "https",
              parsed.host != nil, parsed.path.count > 1 else { return nil }
        return parsed
    }
}

extension Summary {
    /// Citations to show: named sources, each once
    var displayCitations: [Citation] {
        var seen = Set<String>()
        return citations.filter { citation in
            let name = citation.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !name.isEmpty && seen.insert(name).inserted
        }
    }
}