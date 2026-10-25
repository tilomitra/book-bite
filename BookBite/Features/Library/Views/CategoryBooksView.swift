import SwiftUI

struct CategoryBooksView: View {
    let category: BookCategory
    @StateObject private var viewModel: CategoryBooksViewModel

    init(category: BookCategory) {
        self.category = category
        _viewModel = StateObject(wrappedValue: CategoryBooksViewModel(
            category: category,
            bookRepository: DependencyContainer.shared.bookRepository
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.books.isEmpty {
                ConsistentLoadingView(style: .primary, message: "Loading books...")
            } else if let error = viewModel.error {
                ContentUnavailableView {
                    Label("Can't load books", systemImage: "wifi.slash")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Try Again") {
                        Task { await viewModel.loadBooks() }
                    }
                    .buttonStyle(.bordered)
                }
            } else if viewModel.books.isEmpty {
                ContentUnavailableView("No books in \(category.name)", systemImage: "books.vertical")
            } else {
                List(viewModel.books) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        SearchResultRow(book: book)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel.books.isEmpty {
                await viewModel.loadBooks()
            }
        }
    }
}
