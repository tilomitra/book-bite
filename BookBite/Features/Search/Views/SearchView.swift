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
                HStack {
                    TextField("Search by title, author, or topic", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            Task {
                                await viewModel.performSearch()
                            }
                        }
                    
                    Button("Search") {
                        Task {
                            await viewModel.performSearch()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                
                // Results area
                if viewModel.isSearching {
                    LoadingView()
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
                    SearchResultsList(books: viewModel.searchResults)
                }
            }
            .navigationTitle("Discover Books")
        }
    }
}

struct SearchResultsList: View {
    let books: [Book]
    
    var body: some View {
        List(books) { book in
            NavigationLink(destination: BookDetailView(book: book)) {
                SearchResultRow(book: book)
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
            
            Text("Start typing to search our library of business and technology books")
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