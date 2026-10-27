import Foundation

/// Ask conversations, newest first. Stored on device (UserDefaults), so asking works without sign-in;
/// the server is stateless and gets earlier turns from the app with each follow-up.
@MainActor
final class AskHistoryStore: ObservableObject {
    static let shared = AskHistoryStore()

    static let maxConversations = 50

    @Published private(set) var conversations: [AskConversation] = []

    // ISO 8601 dates to match `NetworkService.makeDecoder()`, which reads them back
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let defaults: UserDefaults
    private let key = "askConversations"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? NetworkService.makeDecoder().decode([AskConversation].self, from: data) {
            conversations = saved
        }
    }

    /// Adds the conversation, or replaces it and moves it to the top. Turns without an answer aren't kept.
    func save(_ conversation: AskConversation) {
        var conversation = conversation
        conversation.turns.removeAll { $0.answer.isEmpty }
        conversations.removeAll { $0.id == conversation.id }
        guard !conversation.turns.isEmpty else { return persist() }
        conversation.updatedAt = Date()
        conversations.insert(conversation, at: 0)
        if conversations.count > Self.maxConversations {
            conversations.removeLast(conversations.count - Self.maxConversations)
        }
        persist()
    }

    func remove(_ conversation: AskConversation) {
        conversations.removeAll { $0.id == conversation.id }
        persist()
    }

    private func persist() {
        if let data = try? Self.encoder.encode(conversations) {
            defaults.set(data, forKey: key)
        }
    }
}
