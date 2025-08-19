import SwiftUI

struct SwipeView: View {
    @StateObject private var viewModel: SwipeViewModel
    @State private var dragOffset = CGSize.zero
    @State private var rotationAngle: Double = 0
    @State private var showingBookDetail = false
    @State private var selectedBook: Book?
    
    init() {
        _viewModel = StateObject(wrappedValue: SwipeViewModel(bookRepository: DependencyContainer.shared.bookRepository))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient based on swipe direction
                if dragOffset.width > 20 {
                    // Right swipe - green gradient
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green.opacity(0.1), Color.green.opacity(0.3)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .opacity(min(1.0, abs(dragOffset.width) / 150.0))
                    .ignoresSafeArea()
                } else if dragOffset.width < -20 {
                    // Left swipe - red gradient
                    LinearGradient(
                        gradient: Gradient(colors: [Color.red.opacity(0.3), Color.red.opacity(0.1)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .opacity(min(1.0, abs(dragOffset.width) / 150.0))
                    .ignoresSafeArea()
                } else {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                }
                
                if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.error {
                    ErrorSwipeView(error: error) {
                        Task {
                            await viewModel.refreshBooks()
                        }
                    }
                } else if let book = viewModel.currentBook {
                    ZStack {
                        // Background cards stack
                        ForEach(Array(viewModel.backgroundBooks.enumerated().reversed()), id: \.element.id) { index, backgroundBook in
                            SwipeCardView(
                                book: backgroundBook,
                                dragOffset: .zero,
                                rotationAngle: 0
                            )
                            .scaleEffect(0.95 - Double(index) * 0.03)
                            .offset(x: 0, y: CGFloat(index + 1) * 8)
                            .opacity(0.6 - Double(index) * 0.2)
                            .allowsHitTesting(false)
                        }
                        
                        // Main active card
                        SwipeCardView(
                            book: book,
                            dragOffset: dragOffset,
                            rotationAngle: rotationAngle
                        )
                        .scaleEffect(1.0 - abs(dragOffset.width) / 1000.0)
                        .offset(dragOffset)
                        .rotationEffect(.degrees(rotationAngle))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                    rotationAngle = Double(value.translation.width / 10)
                                }
                                .onEnded { value in
                                    handleSwipeEnd(value: value)
                                }
                        )
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: dragOffset)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: rotationAngle)
                    }
                } else {
                    EmptySwipeView()
                }
                
                // Swipe instruction overlay
                if viewModel.currentBook != nil && dragOffset == .zero {
                    VStack {
                        Spacer()
                        SwipeInstructionsView()
                            .padding(.bottom, 40)
                    }
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("Discover")
            .refreshable {
                await viewModel.refreshBooks()
            }
            .navigationDestination(isPresented: $showingBookDetail) {
                if let book = selectedBook {
                    BookDetailView(book: book)
                }
            }
        }
    }
    
    private func handleSwipeEnd(value: DragGesture.Value) {
        let threshold: CGFloat = 120
        
        if value.translation.width > threshold {
            // Swipe right - show book detail (immediate stack update)
            if let book = viewModel.swipeRight() {
                selectedBook = book
                showingBookDetail = true
            }
            // Reset position immediately since we're navigating away
            dragOffset = .zero
            rotationAngle = 0
        } else if value.translation.width < -threshold {
            // Swipe left - next book from stack (immediate stack update)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                viewModel.swipeLeft()
                dragOffset = .zero
                rotationAngle = 0
            }
        } else {
            // Not swiped far enough - return to original position
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                dragOffset = .zero
                rotationAngle = 0
            }
        }
    }
}

struct SwipeCardView: View {
    let book: Book
    let dragOffset: CGSize
    let rotationAngle: Double
    
    var body: some View {
        VStack(spacing: 16) {
            // Book Cover
            BookCoverView(coverURL: book.coverAssetName, size: .large)
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            
            // Book Info
            VStack(spacing: 10) {
                Text(book.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                
                Text(book.formattedAuthors)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                
                if !book.categories.isEmpty {
                    Text(book.formattedCategories)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                        .lineLimit(nil)
                        .multilineTextAlignment(.center)
                }
                
                if let description = book.description, !description.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(description.strippedHTML)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .padding(.horizontal, 8)
                    }
                    .frame(height: 80)
                }
            }
            .padding(.horizontal, 16)
            
            Spacer(minLength: 20)
        }
        .frame(maxWidth: 340, maxHeight: 600)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 5)
        .overlay(
            // Swipe indicators
            Group {
                if dragOffset.width > 50 {
                    SwipeIndicator(type: .like)
                        .opacity(min(1.0, dragOffset.width / 100.0))
                        .scaleEffect(min(1.2, 1.0 + dragOffset.width / 500.0))
                } else if dragOffset.width < -50 {
                    SwipeIndicator(type: .pass)
                        .opacity(min(1.0, abs(dragOffset.width) / 100.0))
                        .scaleEffect(min(1.2, 1.0 + abs(dragOffset.width) / 500.0))
                }
            }
        )
    }
}

struct SwipeIndicator: View {
    enum IndicatorType {
        case like, pass
        
        var color: Color {
            switch self {
            case .like: return .green
            case .pass: return .red
            }
        }
        
        var text: String {
            switch self {
            case .like: return "READ MORE"
            case .pass: return "NEXT"
            }
        }
        
        var icon: String {
            switch self {
            case .like: return "heart.fill"
            case .pass: return "xmark"
            }
        }
    }
    
    let type: IndicatorType
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: type.icon)
                .font(.system(size: 30, weight: .bold))
            
            Text(type.text)
                .font(.caption)
                .fontWeight(.bold)
        }
        .foregroundColor(type.color)
        .padding(16)
        .background(type.color.opacity(0.1))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(type.color, lineWidth: 3)
        )
    }
}

struct SwipeInstructionsView: View {
    var body: some View {
        HStack(spacing: 30) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left")
                    .font(.caption)
                    .foregroundColor(.red)
                
                Text("Next")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 6) {
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Text("Read More")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground).opacity(0.9))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
}

struct EmptySwipeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Books Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Check your connection and try refreshing")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(.top, 100)
    }
}

struct ErrorSwipeView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Connection Error")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Unable to load books. Please check your internet connection and try again.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Try Again") {
                retry()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .padding(.top, 100)
    }
}

