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
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role
        case content
        case createdAt = "created_at"
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