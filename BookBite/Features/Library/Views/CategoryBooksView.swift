import SwiftUI

struct CategoryBooksView: View {
    let category: BookCategory
    @EnvironmentObject var dependencies: DependencyContainer
    @StateObject private var viewModel: CategoryBooksViewModel
    
    init(category: BookCategory) {
        self.category = category
        _viewModel = StateObject(wrappedValue: CategoryBooksViewModel(
            category: category,
            bookRepository: DependencyContainer.shared.bookRepository
        ))
    }
    
    var categoryColor: Color {
        DesignSystem.Colors.categoryColor(for: category.name)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.books.isEmpty {
                LoadingView()
            } else if let error = viewModel.error {
                ErrorBooksView(error: error) {
                    Task {
                        await viewModel.loadBooks()
                    }
                }
            } else if viewModel.books.isEmpty {
                EmptyBooksView(category: category.name)
            } else {
                BooksList(
                    books: viewModel.books,
                    isLoadingMore: viewModel.isLoadingMore,
                    hasMore: viewModel.hasMore,
                    onBookAppear: viewModel.onBookAppear
                )
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 16))
                    Text("\(viewModel.books.count)")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(categoryColor)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadBooks()
            }
        }
    }
}

struct BooksList: View {
    let books: [Book]
    let isLoadingMore: Bool
    let hasMore: Bool
    let onBookAppear: (Book) -> Void
    
    var body: some View {
        List {
            ForEach(books) { book in
                NavigationLink(destination: BookDetailView(book: book)) {
                    BookRowView(book: book)
                }
                .onAppear {
                    onBookAppear(book)
                }
            }
            
            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading more books...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowSeparator(.hidden)
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
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct BookRowView: View {
    let book: Book
    
    private func httpsURL(from coverURL: String) -> String {
        // Convert HTTP Google Books URLs to HTTPS
        if coverURL.hasPrefix("http://books.google.com") {
            return coverURL.replacingOccurrences(of: "http://", with: "https://")
        }
        return coverURL
    }
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: book.coverAssetName != nil ? URL(string: httpsURL(from: book.coverAssetName!)) : nil) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 90)
                        .cornerRadius(8)
                case .failure(_):
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 90)
                        .overlay(
                            Image(systemName: "book.closed")
                                .foregroundColor(.gray)
                        )
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 60, height: 90)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.5)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if !book.authors.isEmpty {
                    Text(book.formattedAuthors)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let year = book.publishedYear {
                    Text(String(year))
                        .font(.system(size: 12))
                        .foregroundColor(Color.secondary)
                }
                
                if book.isNYTBestseller == true {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.nytGold)
                        Text("NYT Bestseller")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.nytGold)
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct EmptyBooksView: View {
    let category: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Books Found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("No books available in \(category)")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(.top, 100)
    }
}

struct ErrorBooksView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Loading Error")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Unable to load books. \(error.localizedDescription)")
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