import SwiftUI
import Combine

struct BookChatView: View {
    @StateObject private var viewModel: BookChatViewModel
    @State private var showErrorAlert = false
    @State private var showConversationHistory = false
    @State private var userHasScrolled = false
    @State private var lastMessageCount = 0
    
    private let book: Book
    
    init(book: Book) {
        self.book = book
        _viewModel = StateObject(wrappedValue: BookChatViewModel(
            book: book,
            chatRepository: DependencyContainer.shared.chatRepository
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            Divider()
            
            // Messages area
            if viewModel.isLoading {
                ChatLoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.hasMessages {
                messagesScrollView
            } else {
                emptyStateView
            }
            
            // Input area
            Divider()
            ChatInputView(
                text: $viewModel.inputText,
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                },
                isLoading: viewModel.isLoadingResponse
            )
        }
        .background(Color(UIColor.systemBackground))
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onReceive(viewModel.$error) { error in
            showErrorAlert = error != nil
        }
        .sheet(isPresented: $showConversationHistory) {
            ConversationHistoryView(
                bookId: book.id,
                onSelectConversation: { conversation in
                    Task {
                        await viewModel.loadConversation(conversation)
                    }
                },
                onDismiss: {
                    showConversationHistory = false
                }
            )
        }
    }
    
    private var chatHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ask")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Chat about this book's topics")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                if viewModel.hasMessages {
                    Button("New Chat") {
                        Task {
                            await viewModel.startNewConversation()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
    }
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        ChatMessageView(
                            message: message,
                            isUser: viewModel.isUserMessage(message)
                        )
                        .id(message.id)
                    }
                    
                    // Show typing indicator only if no streaming content yet
                    if viewModel.isLoadingResponse && viewModel.streamingMessage.isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    TypingIndicatorView()
                                    
                                    Text("BookBite is typing...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(UIColor.systemGray6))
                                )
                            }
                            
                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal)
                        .id("loading")
                    }
                }
                .padding(.vertical)
            }
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in
                        // User has started scrolling manually
                        userHasScrolled = true
                    }
            )
            .onChange(of: viewModel.messages.count) { oldCount, newCount in
                // Reset scroll tracking when new messages are added (not during streaming)
                if newCount > lastMessageCount {
                    lastMessageCount = newCount
                    userHasScrolled = false
                    
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .top)
                        }
                    }
                }
            }
            .onChange(of: viewModel.isLoadingResponse) { _, isLoading in
                if isLoading && !userHasScrolled {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("loading", anchor: .top)
                    }
                }
            }
            .onChange(of: viewModel.streamingMessage) { _, _ in
                // Only auto-scroll during streaming if user hasn't manually scrolled
                if !userHasScrolled, let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(lastMessage.id, anchor: .top)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Start a conversation")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("Ask questions about the book's ideas, concepts, or how to apply them in your life.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Suggested questions
            VStack(spacing: 8) {
                Text("Try asking:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    SuggestedQuestionButton("What are the key ideas?") {
                        viewModel.inputText = "What are the key ideas in this book?"
                    }
                    
                    SuggestedQuestionButton("How can I apply this?") {
                        viewModel.inputText = "How can I apply these concepts in my daily life?"
                    }
                    
                    SuggestedQuestionButton("What are the main takeaways?") {
                        viewModel.inputText = "What are the main takeaways I should remember?"
                    }
                    
                    SuggestedQuestionButton("Who should read this?") {
                        viewModel.inputText = "Who would benefit most from reading this book?"
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct SuggestedQuestionButton: View {
    let title: String
    let action: () -> Void
    
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        .background(Color.blue.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }
}

struct ChatLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Setting up chat...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct TypingIndicatorView: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.7))
                    .frame(width: 6, height: 6)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
        .onDisappear {
            animating = false
        }
    }
}

#Preview {
    BookChatView(book: Book(
        id: "1",
        title: "Atomic Habits",
        subtitle: "An Easy & Proven Way to Build Good Habits & Break Bad Ones",
        authors: ["James Clear"],
        isbn10: nil,
        isbn13: nil,
        publishedYear: 2018,
        publisher: "Avery",
        categories: ["Self-Help"],
        coverAssetName: "atomic_habits",
        description: "A comprehensive guide to building good habits and breaking bad ones.",
        sourceAttribution: [],
        popularityRank: 1,
        isFeatured: true,
        isNYTBestseller: true,
        nytRank: 1,
        nytWeeksOnList: 52,
        nytList: "Combined Print & E-Book Nonfiction"
    ))
}