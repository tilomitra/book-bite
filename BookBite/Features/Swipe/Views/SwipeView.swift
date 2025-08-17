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
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.error {
                    ErrorSwipeView(error: error) {
                        Task {
                            await viewModel.refreshBooks()
                        }
                    }
                } else if let book = viewModel.currentBook {
                    SwipeCardView(
                        book: book,
                        dragOffset: dragOffset,
                        rotationAngle: rotationAngle
                    )
                    .scaleEffect(1.0 - abs(dragOffset.width) / 1000.0)
                    .opacity(1.0 - abs(dragOffset.width) / 500.0)
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
                } else {
                    EmptySwipeView()
                }
                
                // Swipe instruction overlay
                if viewModel.currentBook != nil && dragOffset == .zero {
                    VStack {
                        Spacer()
                        SwipeInstructionsView()
                            .padding(.bottom, 100)
                    }
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
        let threshold: CGFloat = 100
        
        if value.translation.width > threshold {
            // Swipe right - show book detail
            if let book = viewModel.swipeRight() {
                selectedBook = book
                showingBookDetail = true
            }
        } else if value.translation.width < -threshold {
            // Swipe left - next book
            viewModel.swipeLeft()
        }
        
        // Reset position
        dragOffset = .zero
        rotationAngle = 0
    }
}

struct SwipeCardView: View {
    let book: Book
    let dragOffset: CGSize
    let rotationAngle: Double
    
    var body: some View {
        VStack(spacing: 20) {
            // Book Cover
            BookCoverView(coverURL: book.coverAssetName, size: .large)
                .frame(maxHeight: 350)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            
            // Book Info
            VStack(spacing: 12) {
                Text(book.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                
                Text(book.formattedAuthors)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                if !book.categories.isEmpty {
                    Text(book.formattedCategories)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                        .lineLimit(1)
                }
                
                if let description = book.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .frame(maxWidth: 320, maxHeight: 600)
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
        HStack(spacing: 40) {
            VStack(spacing: 8) {
                Image(systemName: "arrow.left")
                    .font(.title2)
                    .foregroundColor(.red)
                
                Text("Next Book")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Read More")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
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

