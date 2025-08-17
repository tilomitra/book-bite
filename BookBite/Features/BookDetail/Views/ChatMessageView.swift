import SwiftUI

struct ChatMessageView: View {
    let message: ChatMessage
    let isUser: Bool
    
    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isUser ? Color.blue : Color(UIColor.systemGray6))
                    )
                
                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !isUser {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 16) {
        ChatMessageView(
            message: ChatMessage(
                id: "1",
                conversationId: "conv1",
                role: .user,
                content: "What are the main ideas in this book?",
                createdAt: Date()
            ),
            isUser: true
        )
        
        ChatMessageView(
            message: ChatMessage(
                id: "2",
                conversationId: "conv1",
                role: .assistant,
                content: "The main ideas in this book focus on building atomic habits through small, consistent changes. The author emphasizes the power of 1% improvements and how they compound over time to create remarkable results.",
                createdAt: Date()
            ),
            isUser: false
        )
    }
    .padding()
}