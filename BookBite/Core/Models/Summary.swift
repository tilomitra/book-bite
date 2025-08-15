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
    }
    
    enum SummaryStyle: String, Codable {
        case brief
        case full
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