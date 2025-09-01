import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    @StateObject private var viewModel: LibraryViewModel
    @StateObject private var searchViewModel: SearchViewModel
    @State private var isSearchActive = false
    
    init() {
        _viewModel = StateObject(wrappedValue: LibraryViewModel(bookRepository: DependencyContainer.shared.bookRepository))
        _searchViewModel = StateObject(wrappedValue: SearchViewModel(searchService: DependencyContainer.shared.searchService))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                LibrarySearchBarView(
                    searchText: $searchViewModel.searchText,
                    isActive: $isSearchActive,
                    onSearchSubmit: {
                        Task {
                            await searchViewModel.performSearch()
                        }
                    },
                    onClear: {
                        searchViewModel.clearSearch()
                        isSearchActive = false
                    }
                )
                
                // Content Area
                if isSearchActive || !searchViewModel.searchText.isEmpty {
                    // Search Results
                    SearchResultsContent(
                        searchViewModel: searchViewModel,
                        onDismissSearch: {
                            isSearchActive = false
                            searchViewModel.clearSearch()
                        }
                    )
                } else {
                    // Category Grid
                    Group {
                        if viewModel.isLoading && viewModel.categories.isEmpty {
                            ConsistentLoadingView(style: .primary, message: "Loading categories...")
                        } else if let error = viewModel.error {
                            CategoriesErrorView(error: error) {
                                Task {
                                    await viewModel.loadCategories()
                                }
                            }
                        } else {
                            CategoryGridView(categories: viewModel.categories)
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            Task {
                await viewModel.loadCategories()
            }
        }
        .onChange(of: searchViewModel.searchText) { oldValue, newValue in
            if !newValue.isEmpty {
                isSearchActive = true
            }
        }
    }
}

struct CategoryGridView: View {
    let categories: [BookCategory]
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(categories) { category in
                    NavigationLink(destination: CategoryBooksView(category: category)) {
                        CategoryCard(category: category)
                    }
                    .buttonStyle(CategoryCardButtonStyle())
                }
            }
            .padding()
        }
    }
}

struct CategoriesErrorView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Unable to Load Categories")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
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

struct CategoryCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
    }
}

// MARK: - Search Components

struct LibrarySearchBarView: View {
    @Binding var searchText: String
    @Binding var isActive: Bool
    let onSearchSubmit: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Search text field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search by title, author, or topic", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        onSearchSubmit()
                    }
                    .onTapGesture {
                        isActive = true
                    }
                
                if !searchText.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Search button - always visible when there's text
            if !searchText.isEmpty {
                Button(action: onSearchSubmit) {
                    Text("Search")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct SearchResultsContent: View {
    @ObservedObject var searchViewModel: SearchViewModel
    let onDismissSearch: () -> Void
    
    var body: some View {
        Group {
            if searchViewModel.isSearching {
                ConsistentLoadingView(style: .primary, message: "Searching...")
            } else if let error = searchViewModel.searchError {
                ErrorSearchView(error: error) {
                    Task {
                        await searchViewModel.performSearch()
                    }
                }
            } else if searchViewModel.showEmptyState {
                EmptySearchView(searchText: searchViewModel.searchText)
            } else if searchViewModel.hasResults {
                SearchResultsList(
                    books: searchViewModel.searchResults,
                    isLoadingMore: searchViewModel.isLoadingMore,
                    hasMore: searchViewModel.hasMore,
                    onBookAppear: searchViewModel.onBookAppear
                )
            } else {
                InitialSearchViewLibrary()
            }
        }
    }
}

struct InitialSearchViewLibrary: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Search BookBite Library")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Find amazing books by title, author, or topic")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(.top, 100)
    }
}