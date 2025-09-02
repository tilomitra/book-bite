import Foundation
import Combine

@MainActor
class BookChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var isLoadingResponse = false
    @Published var error: Error?
    @Published var inputText = ""
    @Published var streamingMessage: String = ""
    
    private var currentConversation: ChatConversation?
    private let book: Book
    private let chatRepository: ChatRepository
    private var cancellables = Set<AnyCancellable>()
    private var currentStreamingMessageId: String?
    
    init(book: Book, chatRepository: ChatRepository) {
        self.book = book
        self.chatRepository = chatRepository
    }
    
    var canSendMessage: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoadingResponse
    }
    
    var hasMessages: Bool {
        !messages.isEmpty
    }
    
    var conversationTitle: String {
        currentConversation?.title ?? "Ask about \(book.title)"
    }
    
    func startNewConversation() async {
        isLoading = true
        error = nil
        
        do {
            currentConversation = try await chatRepository.createConversation(for: book.id)
            messages = []
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func loadConversation(_ conversation: ChatConversation) async {
        isLoading = true
        error = nil
        
        do {
            let response = try await chatRepository.getConversation(conversation.id, for: book.id)
            currentConversation = response.conversation ?? conversation
            messages = response.messages
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func sendMessage() async {
        guard canSendMessage else { return }
        
        let messageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        
        // If no conversation exists, create one first
        if currentConversation == nil {
            await startNewConversation()
            guard currentConversation != nil else { return }
        }
        
        guard let conversation = currentConversation else { return }
        
        // Create and show user message immediately
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            conversationId: conversation.id,
            role: .user,
            content: messageText,
            createdAt: Date(),
            isPending: true
        )
        messages.append(userMessage)
        
        // Create a placeholder for the assistant message
        let assistantMessageId = UUID().uuidString
        let assistantMessage = ChatMessage(
            id: assistantMessageId,
            conversationId: conversation.id,
            role: .assistant,
            content: "",
            createdAt: Date(),
            isPending: true
        )
        messages.append(assistantMessage)
        currentStreamingMessageId = assistantMessageId
        
        isLoadingResponse = true
        error = nil
        streamingMessage = ""
        
        do {
            // Run streaming on background task to prevent UI blocking
            await withTaskGroup(of: Void.self) { group in
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    do {
                        try await self.chatRepository.sendMessageStreaming(messageText, in: conversation.id, for: self.book.id) { chunk in
                            Task { @MainActor [weak self] in
                                guard let self = self else { return }
                                self.streamingMessage += chunk
                                
                                // Update the assistant message content
                                if let index = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                                    self.messages[index] = ChatMessage(
                                        id: assistantMessageId,
                                        conversationId: conversation.id,
                                        role: .assistant,
                                        content: self.streamingMessage,
                                        createdAt: Date(),
                                        isPending: false
                                    )
                                }
                            }
                        }
                    } catch {
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }
                            self.error = error
                            
                            // Remove both pending messages on error
                            self.messages.removeAll { $0.id == userMessage.id || $0.id == assistantMessageId }
                        }
                    }
                }
            }
            
            // Mark user message as not pending after streaming completes
            if let userIndex = messages.firstIndex(where: { $0.id == userMessage.id }) {
                messages[userIndex] = ChatMessage(
                    id: userMessage.id,
                    conversationId: conversation.id,
                    role: .user,
                    content: messageText,
                    createdAt: Date(),
                    isPending: false
                )
            }
            
        } catch {
            self.error = error
            
            // Remove both pending messages on error
            messages.removeAll { $0.id == userMessage.id || $0.id == assistantMessageId }
        }
        
        isLoadingResponse = false
        streamingMessage = ""
        currentStreamingMessageId = nil
    }
    
    func clearConversation() async {
        guard let conversation = currentConversation else { return }
        
        isLoading = true
        error = nil
        
        do {
            try await chatRepository.deleteConversation(conversation.id, for: book.id)
            currentConversation = nil
            messages = []
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func clearError() {
        error = nil
    }
    
    var errorMessage: String {
        if let error = error as? NetworkError {
            switch error {
            case .networkFailure(let underlyingError):
                if (underlyingError as? URLError)?.code == .notConnectedToInternet {
                    return "Chat requires an internet connection"
                }
                return "Network error. Please try again."
            case .clientError(_, _):
                return "Request error. Please try again."
            case .serverError(_):
                return "Server error. Please try again later."
            case .invalidResponse:
                return "Invalid response from server"
            case .unexpectedStatusCode(_):
                return "Unexpected response from server"
            case .decodingError(_):
                return "Response format error"
            }
        }
        return error?.localizedDescription ?? "An unknown error occurred"
    }
}

// MARK: - Helper extensions
extension BookChatViewModel {
    func isUserMessage(_ message: ChatMessage) -> Bool {
        message.role == .user
    }
    
    func formatMessageTime(_ message: ChatMessage) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.createdAt)
    }
}