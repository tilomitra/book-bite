import SwiftUI

/// Search tab: type to search the library, or browse by category.
struct BookSearchView: View {
    @StateObject private var categoriesViewModel: LibraryViewModel
    @StateObject private var searchViewModel: SearchViewModel

    init() {
        _categoriesViewModel = StateObject(wrappedValue: LibraryViewModel(bookRepository: DependencyContainer.shared.bookRepository))
        _searchViewModel = StateObject(wrappedValue: SearchViewModel(searchService: DependencyContainer.shared.searchService))
    }

    var body: some View {
        Group {
            if searchViewModel.isQueryEmpty {
                CategoryList(categories: categoriesViewModel.categories)
            } else {
                SearchResultsContent(searchViewModel: searchViewModel)
            }
        }
        .navigationTitle("Search")
        .searchable(text: $searchViewModel.searchText, prompt: "Title, author, or topic")
        .autocorrectionDisabled()
        .onSubmit(of: .search) {
            Task { await searchViewModel.performSearch() }
        }
        .task {
            await categoriesViewModel.loadCategories()
        }
    }
}

struct CategoryList: View {
    let categories: [BookCategory]

    /// Categories the server reports as empty lead nowhere, so leave them out
    private var visibleCategories: [BookCategory] {
        categories.filter { $0.bookCount != 0 }
    }

    var body: some View {
        List {
            Section("Browse") {
                ForEach(visibleCategories) { category in
                    NavigationLink(destination: CategoryBooksView(category: category)) {
                        HStack {
                            Text(category.name)
                            Spacer()
                            if let count = category.bookCount {
                                Text("\(count)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                RequestBookLink()
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct SearchResultsContent: View {
    @ObservedObject var searchViewModel: SearchViewModel

    var body: some View {
        Group {
            if (searchViewModel.isSearching || searchViewModel.isPending) && searchViewModel.searchResults.isEmpty {
                ConsistentLoadingView(style: .primary, message: "Searching...")
            } else if let error = searchViewModel.searchError {
                ContentUnavailableView {
                    Label("Search failed", systemImage: "wifi.slash")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Try Again") {
                        Task { await searchViewModel.performSearch() }
                    }
                    .buttonStyle(.bordered)
                }
            } else if searchViewModel.showEmptyState {
                ContentUnavailableView {
                    Label("No results", systemImage: "magnifyingglass")
                } description: {
                    Text("No books in the library match \"\(searchViewModel.searchText)\".")
                } actions: {
                    NavigationLink("Request this book") {
                        RequestView()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                SearchResultsList(
                    books: searchViewModel.searchResults,
                    isLoadingMore: searchViewModel.isLoadingMore,
                    onBookAppear: searchViewModel.onBookAppear
                )
            }
        }
    }
}

struct SearchResultsList: View {
    let books: [Book]
    let isLoadingMore: Bool
    let onBookAppear: (Book) -> Void

    var body: some View {
        List {
            ForEach(books) { book in
                NavigationLink(destination: BookDetailView(book: book)) {
                    SearchResultRow(book: book)
                }
                .onAppear {
                    onBookAppear(book)
                }
            }

            if isLoadingMore {
                ConsistentLoadingView(style: .pagination)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                RequestBookLink()
            }
        }
        .listStyle(.plain)
    }
}

/// Entry point to request a book that is not in the library yet.
struct RequestBookLink: View {
    var body: some View {
        NavigationLink(destination: RequestView()) {
            Label("Can't find a book? Request it", systemImage: "plus")
                .foregroundColor(.secondary)
        }
    }
}
