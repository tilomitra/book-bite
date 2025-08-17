import Foundation

protocol ChatRepository {
    func createConversation(for bookId: String) async throws -> ChatConversation
    func getConversation(_ conversationId: String, for bookId: String) async throws -> ChatResponse
    func sendMessage(_ message: String, in conversationId: String, for bookId: String) async throws -> ChatResponse
    func getConversations(for bookId: String) async throws -> [ChatConversation]
    func deleteConversation(_ conversationId: String, for bookId: String) async throws
}

class RemoteChatRepository: ChatRepository {
    private let networkService: NetworkService
    
    init(networkService: NetworkService = NetworkService.shared) {
        self.networkService = networkService
    }
    
    func createConversation(for bookId: String) async throws -> ChatConversation {
        let endpoint = "books/\(bookId)/chat/conversations"
        return try await networkService.post(endpoint: endpoint, body: EmptyBody())
    }
    
    func getConversation(_ conversationId: String, for bookId: String) async throws -> ChatResponse {
        let endpoint = "books/\(bookId)/chat/conversations/\(conversationId)"
        return try await networkService.get(endpoint: endpoint)
    }
    
    func sendMessage(_ message: String, in conversationId: String, for bookId: String) async throws -> ChatResponse {
        let endpoint = "books/\(bookId)/chat/conversations/\(conversationId)/messages"
        let request = SendMessageRequest(message: message)
        return try await networkService.post(endpoint: endpoint, body: request)
    }
    
    func getConversations(for bookId: String) async throws -> [ChatConversation] {
        let endpoint = "books/\(bookId)/chat/conversations"
        return try await networkService.get(endpoint: endpoint)
    }
    
    func deleteConversation(_ conversationId: String, for bookId: String) async throws {
        let endpoint = "books/\(bookId)/chat/conversations/\(conversationId)"
        try await networkService.delete(endpoint: endpoint)
    }
}

class LocalChatRepository: ChatRepository {
    func createConversation(for bookId: String) async throws -> ChatConversation {
        throw NetworkError.networkFailure(URLError(.notConnectedToInternet))
    }
    
    func getConversation(_ conversationId: String, for bookId: String) async throws -> ChatResponse {
        throw NetworkError.networkFailure(URLError(.notConnectedToInternet))
    }
    
    func sendMessage(_ message: String, in conversationId: String, for bookId: String) async throws -> ChatResponse {
        throw NetworkError.networkFailure(URLError(.notConnectedToInternet))
    }
    
    func getConversations(for bookId: String) async throws -> [ChatConversation] {
        throw NetworkError.networkFailure(URLError(.notConnectedToInternet))
    }
    
    func deleteConversation(_ conversationId: String, for bookId: String) async throws {
        throw NetworkError.networkFailure(URLError(.notConnectedToInternet))
    }
}

private struct EmptyBody: Codable {}
private struct EmptyResponse: Codable {}