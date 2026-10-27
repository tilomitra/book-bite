import Foundation

/// The Ask tab: question of the day and Explore topics, each with a few matching books. From `GET ask/home`.
struct AskHome: Codable {
    let date: String
    let daily: Daily
    let topics: [Topic]

    struct Daily: Codable {
        let question: String
        let books: [Book]
    }

    struct Topic: Codable, Identifiable, Hashable {
        let id: String
        let name: String
        /// Starter questions; the compose screen suggests them
        let questions: [String]
        let books: [Book]
    }
}

struct AskMatches: Codable {
    let books: [Book]
}

/// Body of `POST ask`. History is the earlier turns of the conversation, oldest first.
struct AskRequest: Encodable {
    let question: String
    let history: [Turn]

    struct Turn: Encodable {
        let question: String
        let answer: String
    }
}

/// What `POST ask` streams: the books it read (numbered in order, as the answer cites them), then text.
enum AskStreamEvent {
    case sources([Book])
    case delta(String)
}

/// One question and its answer. `answer` is the raw text the server wrote; `AskAnswer` parses it.
struct AskTurn: Codable, Identifiable, Hashable {
    let id: UUID
    let question: String
    var answer: String
    /// Cited as [1], [2]… in the answer
    var sources: [Book]
    let askedAt: Date

    init(id: UUID = UUID(), question: String, answer: String = "", sources: [Book] = [], askedAt: Date = Date()) {
        self.id = id
        self.question = question
        self.answer = answer
        self.sources = sources
        self.askedAt = askedAt
    }
}

struct AskConversation: Codable, Identifiable, Hashable {
    let id: UUID
    var turns: [AskTurn]
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), turns: [AskTurn] = [], createdAt: Date = Date()) {
        self.id = id
        self.turns = turns
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var title: String { turns.first?.question ?? "" }

    /// Books from every turn, first seen first, one each
    var books: [Book] {
        var seen = Set<String>()
        return turns.flatMap(\.sources).filter { seen.insert($0.id).inserted }
    }
}
