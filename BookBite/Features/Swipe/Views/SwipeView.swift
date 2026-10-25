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
                // Background - clean monochrome
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ConsistentLoadingView(style: .primary, message: "Loading books...")
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
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06))
                        .foregroundColor(.secondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
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

        var text: String {
            switch self {
            case .like: return "READ MORE"
            case .pass: return "NEXT"
            }
        }

        var icon: String {
            switch self {
            case .like: return "arrow.right.circle.fill"
            case .pass: return "arrow.left.circle.fill"
            }
        }
    }

    let type: IndicatorType

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: type.icon)
                .font(.system(size: 36, weight: .bold))

            Text(type.text)
                .font(.caption)
                .fontWeight(.bold)
        }
        .foregroundColor(.primary)
        .padding(20)
        .background(Color(UIColor.systemBackground).opacity(0.95))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.primary.opacity(0.2), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct SwipeInstructionsView: View {
    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Skip")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 6) {
                Text("Read More")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(.systemBackground).opacity(0.95))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
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
                .foregroundColor(.primary.opacity(0.6))

            Text("Connection Error")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Unable to load books. Please check your internet connection and try again.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: retry) {
                Text("Try Again")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIColor.systemBackground))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.primary)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.top, 100)
    }
}

