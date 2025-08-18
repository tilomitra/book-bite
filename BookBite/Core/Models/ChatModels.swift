import Foundation

struct ChatConversation: Identifiable, Codable {
    let id: String
    let bookId: String
    let title: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case bookId = "book_id"
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let conversationId: String
    let role: MessageRole
    let content: String
    let createdAt: Date
    let isPending: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role
        case content
        case createdAt = "created_at"
        case isPending = "is_pending"
    }
    
    init(id: String, conversationId: String, role: MessageRole, content: String, createdAt: Date, isPending: Bool = false) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.isPending = isPending
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        conversationId = try container.decode(String.self, forKey: .conversationId)
        role = try container.decode(MessageRole.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isPending = try container.decodeIfPresent(Bool.self, forKey: .isPending) ?? false
    }
}

enum MessageRole: String, Codable, CaseIterable {
    case user
    case assistant
    
    var displayName: String {
        switch self {
        case .user:
            return "You"
        case .assistant:
            return "BookBite"
        }
    }
}

struct ChatResponse: Codable {
    let conversation: ChatConversation?
    let messages: [ChatMessage]
    let message: String?
}

struct SendMessageRequest: Codable {
    let message: String
}