import Foundation

protocol ChatRepository {
    func createConversation(for bookId: String) async throws -> ChatConversation
    func getConversation(_ conversationId: String, for bookId: String) async throws -> ChatResponse
    func sendMessage(_ message: String, in conversationId: String, for bookId: String) async throws -> ChatResponse
    func sendMessageStreaming(_ message: String, in conversationId: String, for bookId: String, onChunk: @escaping @Sendable (String) -> Void) async throws
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
    
    func sendMessageStreaming(_ message: String, in conversationId: String, for bookId: String, onChunk: @escaping @Sendable (String) -> Void) async throws {
        let endpoint = "books/\(bookId)/chat/conversations/\(conversationId)/messages/stream"
        let request = SendMessageRequest(message: message)
        
        let baseURLString = AppConfiguration.shared.baseServerURL
        guard let url = URL(string: "\(baseURLString)/\(endpoint)") else {
            throw NetworkError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.timeoutInterval = 120.0 // Longer timeout for streaming
        
        let jsonData = try JSONEncoder().encode(request)
        urlRequest.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.bytes(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
        }
        
        for try await line in data.lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6)) // Remove "data: " prefix
                if let data = jsonString.data(using: .utf8),
                   let streamEvent = try? JSONDecoder().decode(StreamEvent.self, from: data) {
                    switch streamEvent.type {
                    case "chunk":
                        onChunk(streamEvent.content)
                    case "complete":
                        return
                    case "error":
                        throw NetworkError.networkFailure(NSError(domain: "ChatStreamingError", code: -1, userInfo: [NSLocalizedDescriptionKey: streamEvent.error ?? "Unknown streaming error"]))
                    default:
                        break
                    }
                }
            }
        }
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
    
    func sendMessageStreaming(_ message: String, in conversationId: String, for bookId: String, onChunk: @escaping @Sendable (String) -> Void) async throws {
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

private struct StreamEvent: Codable {
    let type: String
    let content: String
    let error: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}