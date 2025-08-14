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