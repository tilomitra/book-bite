import SwiftUI

struct EnhancedSearchView: View {
    @StateObject private var viewModel = EnhancedSearchViewModel()
    @State private var showFilters = false
    @State private var selectedSource = "All Sources"
    
    let sources = ["All Sources", "NYT Bestsellers", "Business Books", "Science Books"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.background,
                        DesignSystem.Colors.vibrantBlue.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Search Header
                    SearchHeaderView(
                        searchText: $viewModel.searchText,
                        selectedSource: $selectedSource,
                        showFilters: $showFilters,
                        sources: sources,
                        onSearch: {
                            Task {
                                await viewModel.search()
                            }
                        }
                    )
                    
                    // Search Results
                    SearchResultsView(
                        searchResults: viewModel.searchResults,
                        isLoading: viewModel.isLoading,
                        error: viewModel.error,
                        searchText: viewModel.searchText,
                        onRetry: {
                            Task {
                                await viewModel.search()
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Search Header View
struct SearchHeaderView: View {
    @Binding var searchText: String
    @Binding var selectedSource: String
    @Binding var showFilters: Bool
    let sources: [String]
    let onSearch: () -> Void
    
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Title and Subtitle
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("Search Books")
                    .font(DesignSystem.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Discover your next great read")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.top, DesignSystem.Spacing.sm)
            
            // Enhanced Search Bar
            HStack(spacing: DesignSystem.Spacing.sm) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(isSearchFocused ? DesignSystem.Colors.vibrantBlue : DesignSystem.Colors.textSecondary)
                        .animation(DesignSystem.Animations.smooth, value: isSearchFocused)
                    
                    TextField("Search titles, authors, or topics", text: $searchText)
                        .focused($isSearchFocused)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .onSubmit(onSearch)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            withAnimation(DesignSystem.Animations.quick) {
                                searchText = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(DesignSystem.Colors.cardBackground)
                        .stroke(
                            isSearchFocused ? DesignSystem.Colors.vibrantBlue : Color.clear,
                            lineWidth: 2
                        )
                        .shadow(
                            color: isSearchFocused ? 
                                DesignSystem.Colors.vibrantBlue.opacity(0.2) : 
                                DesignSystem.Shadow.small.color,
                            radius: isSearchFocused ? 6 : 2,
                            x: 0,
                            y: isSearchFocused ? 3 : 1
                        )
                )
                .animation(DesignSystem.Animations.smooth, value: isSearchFocused)
                
                // Filter Button
                Button(action: {
                    withAnimation(DesignSystem.Animations.bouncy) {
                        showFilters.toggle()
                    }
                }) {
                    Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(showFilters ? DesignSystem.Colors.vibrantBlue : DesignSystem.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(showFilters ? DesignSystem.Colors.vibrantBlue.opacity(0.1) : DesignSystem.Colors.cardBackground)
                        )
                }
                .bounceOnTap()
            }
            
            // Source Filter (shown when filters are enabled)
            if showFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(sources, id: \.self) { source in
                            Button(action: {
                                withAnimation(DesignSystem.Animations.smooth) {
                                    selectedSource = source
                                }
                            }) {
                                Text(source)
                                    .font(DesignSystem.Typography.footnote)
                                    .fontWeight(.medium)
                                    .foregroundColor(
                                        selectedSource == source ? 
                                            .white : 
                                            DesignSystem.Colors.textPrimary
                                    )
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                    .padding(.vertical, DesignSystem.Spacing.sm)
                                    .background(
                                        Capsule()
                                            .fill(
                                                selectedSource == source ? 
                                                    DesignSystem.Colors.vibrantBlue : 
                                                    DesignSystem.Colors.cardBackground
                                            )
                                    )
                            }
                            .bounceOnTap()
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
}

// MARK: - Search Results View
struct SearchResultsView: View {
    let searchResults: [Book]
    let isLoading: Bool
    let error: Error?
    let searchText: String
    let onRetry: () -> Void
    
    var body: some View {
        Group {
            if isLoading {
                SearchLoadingView()
            } else if let error = error {
                SearchErrorView(error: error, onRetry: onRetry)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                SearchEmptyView(searchText: searchText)
            } else if searchResults.isEmpty {
                SearchInitialView()
            } else {
                EnhancedSearchResultsList(books: searchResults)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Search States
struct SearchLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Animated search icon
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.vibrantBlue.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(DesignSystem.Colors.vibrantBlue, lineWidth: 4)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.vibrantBlue)
            }
            
            Text("Searching...")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
    }
}

struct SearchInitialView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.vibrantBlue)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Discover Books")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Search through our collection of NYT bestsellers and curated books")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchEmptyView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No Results Found")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("No books match \"\(searchText)\"")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Text("Try searching for different keywords")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchErrorView: View {
    let error: Error
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundColor(DesignSystem.Colors.error)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Search Error")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Unable to search books. Please try again.")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again", action: onRetry)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.vibrantBlue)
                )
                .bounceOnTap()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Enhanced Search Results List
struct EnhancedSearchResultsList: View {
    let books: [Book]
    @State private var isVisible = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 160, maximum: 180), spacing: DesignSystem.Spacing.md)
                ],
                spacing: DesignSystem.Spacing.lg
            ) {
                ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        EnhancedBookCard(book: book, style: .featured)
                            .scaleEffect(isVisible ? 1.0 : 0.8)
                            .opacity(isVisible ? 1.0 : 0.0)
                            .animation(
                                DesignSystem.Animations.spring
                                    .delay(Double(index) * 0.03),
                                value: isVisible
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
}

// MARK: - Enhanced Search ViewModel
class EnhancedSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [Book] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func search() async {
        // Placeholder for search implementation
        // This would normally call your book repository's search method
    }
}