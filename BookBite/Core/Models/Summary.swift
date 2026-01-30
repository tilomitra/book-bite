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

struct KeyIdea: Identifiable, Codable {
    let id: String
    let idea: String
    let tags: [String]
    let confidence: Confidence
    let sources: [String]
}

struct ApplicationPoint: Identifiable, Codable {
    let id: String
    let action: String
    let tags: [String]
}

struct Citation: Codable, Hashable {
    let source: String
    let url: String?
}