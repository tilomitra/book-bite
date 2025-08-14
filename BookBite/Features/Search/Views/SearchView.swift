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
                if viewModel.isSearching {
                    LoadingView()
                } else if viewModel.showEmptyState {
                    EmptySearchView(searchText: viewModel.searchText)
                } else if viewModel.showInitialState {
                    InitialSearchView()
                } else {
                    SearchResultsList(books: viewModel.searchResults)
                }
            }
            .navigationTitle("Discover Books")
            .searchable(text: $viewModel.searchText, prompt: "Search by title, author, or topic")
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