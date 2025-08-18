import Foundation
import Combine

@MainActor
class BookChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var isLoadingResponse = false
    @Published var error: Error?
    @Published var inputText = ""
    
    private var currentConversation: ChatConversation?
    private let book: Book
    private let chatRepository: ChatRepository
    private var cancellables = Set<AnyCancellable>()
    
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
        
        isLoadingResponse = true
        error = nil
        
        do {
            let response = try await chatRepository.sendMessage(messageText, in: conversation.id, for: book.id)
            
            // Replace all messages with the server response (removes pending state)
            messages = response.messages
            
            // Update conversation if title was generated
            if let updatedConversation = response.conversation {
                currentConversation = updatedConversation
            }
        } catch {
            self.error = error
            
            // Remove the pending user message on error
            if let index = messages.firstIndex(where: { $0.id == userMessage.id }) {
                messages.remove(at: index)
            }
        }
        
        isLoadingResponse = false
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