import SwiftUI

struct ConversationHistoryView: View {
    let bookId: String
    let onSelectConversation: (ChatConversation) -> Void
    let onDismiss: () -> Void
    
    @State private var conversations: [ChatConversation] = []
    @State private var isLoading = true
    @State private var error: Error?
    
    private let chatRepository = DependencyContainer.shared.chatRepository
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading conversations...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationsList
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onDismiss()
                    }
                }
            }
        }
        .task {
            await loadConversations()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No conversations yet")
                .font(.headline)
            
            Text("Start chatting to see your conversation history here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var conversationsList: some View {
        List(conversations) { conversation in
            ConversationRowView(conversation: conversation) {
                onSelectConversation(conversation)
                onDismiss()
            }
        }
    }
    
    private func loadConversations() async {
        isLoading = true
        error = nil
        
        do {
            conversations = try await chatRepository.getConversations(for: bookId)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
}

struct ConversationRowView: View {
    let conversation: ChatConversation
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title ?? "Untitled Conversation")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(formatDate(conversation.updatedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    ConversationHistoryView(
        bookId: "test-book-id",
        onSelectConversation: { _ in },
        onDismiss: {}
    )
}