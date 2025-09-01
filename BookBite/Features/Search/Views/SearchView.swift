import SwiftUI

struct SearchView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    @StateObject private var viewModel: SearchViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: SearchViewModel(searchService: DependencyContainer.shared.searchService))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar with button
                HStack(spacing: 12) {
                    // Search text field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search by title, author, or topic", text: $viewModel.searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onSubmit {
                                Task {
                                    await viewModel.performSearch()
                                }
                            }
                        
                        if !viewModel.searchText.isEmpty {
                            Button(action: {
                                viewModel.searchText = ""
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
                    
                    // Search button
                    Button(action: {
                        Task {
                            await viewModel.performSearch()
                        }
                    }) {
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
                .padding(.vertical, 8)
                
                // Results area
                if viewModel.isSearching {
                    ConsistentLoadingView(style: .primary, message: "Searching for books...")
                } else if let error = viewModel.searchError {
                    ErrorSearchView(error: error) {
                        Task {
                            await viewModel.performSearch()
                        }
                    }
                } else if viewModel.showEmptyState {
                    EmptySearchView(searchText: viewModel.searchText)
                } else if viewModel.showInitialState {
                    InitialSearchView()
                } else {
                    SearchResultsList(
                        books: viewModel.searchResults,
                        isLoadingMore: viewModel.isLoadingMore,
                        hasMore: viewModel.hasMore,
                        onBookAppear: viewModel.onBookAppear
                    )
                }
            }
            .navigationTitle("Discover Books")
        }
    }
}

struct SearchResultsList: View {
    let books: [Book]
    let isLoadingMore: Bool
    let hasMore: Bool
    let onBookAppear: (Book) -> Void
    
    var body: some View {
        List {
            ForEach(books) { book in
                NavigationLink(destination: BookDetailView(book: book)) {
                    SearchResultRow(book: book)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.visible)
                .onAppear {
                    onBookAppear(book)
                }
            }
            
            // Loading indicator at the bottom
            if isLoadingMore {
                ConsistentLoadingView(style: .pagination)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            } else if !hasMore && !books.isEmpty {
                HStack {
                    Spacer()
                    Text("No more books to load")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct InitialSearchView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Welcome to BookBite")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Search our library or scroll to discover amazing books")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(.top, 100)
    }
}

struct EmptySearchView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No results found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("No books match \"\(searchText)\"")
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.top, 100)
    }
}

struct ErrorSearchView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Search Error")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Unable to search books. Error: \(error.localizedDescription)")
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