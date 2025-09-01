import SwiftUI

struct RequestView: View {
    @StateObject private var viewModel = RequestViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar - always at top
                SearchBarView(viewModel: viewModel, isSearchFieldFocused: $isSearchFieldFocused)
                    .padding(.top, DesignSystem.Spacing.sm)
                
                // Error banner
                if let error = viewModel.searchError {
                    ErrorBanner(message: error) {
                        viewModel.searchError = nil
                    }
                }
                
                // Main content based on state
                Group {
                    switch viewModel.requestState {
                    case .idle:
                        ScrollView {
                            InitialRequestView()
                        }
                        .scrollDismissesKeyboard(.interactively)
                        
                    case .searching:
                        LoadingSearchView()
                        
                    case .searchResults(let results):
                        if results.isEmpty {
                            EmptySearchResultsView(searchText: viewModel.searchText)
                        } else {
                            GoogleBookSearchResultsView(results: results) { result in
                                viewModel.requestBook(result)
                            }
                        }
                        
                    case .requestingBook(let result):
                        GeneratingSummaryView(bookResult: result)
                        
                    case .bookRequested(let book):
                        BookRequestedSuccessView(book: book) {
                            viewModel.resetToSearchResults()
                        }
                        
                    case .error(let errorMessage):
                        ErrorStateView(
                            errorMessage: errorMessage,
                            onRetry: {
                                if !viewModel.searchText.isEmpty {
                                    viewModel.searchBooks(query: viewModel.searchText)
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("Request Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Request Books")
                        .font(.headline)
                        .opacity(isSearchFieldFocused ? 0 : 1)
                }
            }
            .background(DesignSystem.Colors.background.ignoresSafeArea())
        }
    }
}

struct InitialRequestView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Simple hero section
            VStack(spacing: 12) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.blue)
                
                Text("Request Any Book")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Search for any book to add it to your library")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            
            // Simplified how it works
            VStack(spacing: 12) {
                Text("How it works:")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                
                VStack(spacing: 8) {
                    HowItWorksStep(
                        number: "1",
                        title: "Search",
                        description: "Search for any book using the search bar above",
                        color: .blue
                    )
                    
                    HowItWorksStep(
                        number: "2",
                        title: "Select", 
                        description: "Choose the book you want from the search results",
                        color: .blue
                    )
                    
                    HowItWorksStep(
                        number: "3",
                        title: "AI Analysis",
                        description: "Our AI generates a comprehensive summary with key insights",
                        color: .blue
                    )
                    
                    HowItWorksStep(
                        number: "4",
                        title: "Ready to Read",
                        description: "The book is added to your library with intelligent summaries",
                        color: .blue
                    )
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
    }
}

struct HowItWorksStep: View {
    let number: String
    let title: String
    let description: String
    let color: Color
    
    init(number: String, title: String, description: String, color: Color = DesignSystem.Colors.vibrantBlue) {
        self.number = number
        self.title = title
        self.description = description
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Simple step number
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(.blue))
            
            // Compact content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

struct LoadingSearchView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Enhanced loading animation
            ZStack {
                // Outer pulsing circle
                Circle()
                    .stroke(DesignSystem.Colors.vibrantBlue.opacity(0.3), lineWidth: 2)
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .opacity(isAnimating ? 0.3 : 1.0)
                
                // Inner spinning circle
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [DesignSystem.Colors.vibrantBlue, DesignSystem.Colors.vibrantPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                
                // Center icon
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.vibrantBlue)
            }
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("Searching books...")
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Finding the perfect matches for you")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.background)
    }
}

struct BookRequestedSuccessView: View {
    let book: Book
    let onContinueSearching: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact success indicator and book card
            VStack(spacing: 20) {
                // Inline success message with small checkmark
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.15), Color.mint.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Book Added Successfully!")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Added to library with AI-generated summaries")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                // Compact book card
                VStack(spacing: 12) {
                    BookCoverView(coverURL: book.coverAssetName, size: .small)
                    
                    VStack(spacing: 6) {
                        Text(book.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                        
                        if !book.authors.isEmpty {
                            Text(book.formattedAuthors)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                        }
                        
                        // Categories or bestseller info
                        if let nytInfo = book.nytBestsellerInfo {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text(nytInfo)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                        } else if !book.categories.isEmpty {
                            Text(book.categories.prefix(2).joined(separator: " • "))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(
                            color: Color.black.opacity(0.05),
                            radius: 6,
                            x: 0,
                            y: 2
                        )
                )
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Always visible action buttons at bottom
            VStack(spacing: 12) {
                NavigationLink(destination: BookDetailView(book: book)) {
                    HStack {
                        Image(systemName: "book.pages")
                            .font(.headline)
                        Text("View Book Summary")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                Button(action: onContinueSearching) {
                    HStack {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.subheadline)
                        Text("Request Another Book")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGroupedBackground).opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct ErrorStateView: View {
    let errorMessage: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: onRetry) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 120, height: 44)
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DesignSystem.Colors.warning)
            
            Text(message)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(DesignSystem.Colors.warning.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .stroke(DesignSystem.Colors.warning.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.sm)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct SearchBarView: View {
    @ObservedObject var viewModel: RequestViewModel
    @FocusState.Binding var isSearchFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Simple search text field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search for any book...", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        performSearch()
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                        viewModel.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Simple search button
            Button(action: performSearch) {
                Text("Search")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSearching)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private func performSearch() {
        let trimmedText = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            viewModel.searchBooks(query: trimmedText)
        }
    }
}

#Preview {
    NavigationStack {
        RequestView()
    }
}