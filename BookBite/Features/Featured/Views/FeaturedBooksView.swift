import SwiftUI

struct FeaturedBooksView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    @StateObject private var viewModel: FeaturedBooksViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: FeaturedBooksViewModel(bookRepository: DependencyContainer.shared.bookRepository))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.featuredBooks.isEmpty {
                    LoadingView()
                } else if let error = viewModel.error {
                    ErrorNYTView(error: error) {
                        Task {
                            await viewModel.loadFeaturedBooks()
                        }
                    }
                } else if viewModel.showEmptyState {
                    EmptyNYTSearchView(searchText: viewModel.searchText)
                } else if viewModel.showInitialState {
                    InitialNYTView()
                } else {
                    FeaturedBooksGenreView(booksByGenre: viewModel.booksByGenre, searchText: viewModel.searchText)
                }
            }
            .navigationTitle("NYT Bestsellers")
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search NYT bestsellers"
            )
            .refreshable {
                await viewModel.refreshFeaturedBooks()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.searchText.isEmpty {
                        Button("Clear") {
                            viewModel.clearSearch()
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
}

struct FeaturedBooksGenreView: View {
    let booksByGenre: [(genre: String, books: [Book])]
    let searchText: String
    
    var filteredGenres: [(genre: String, books: [Book])] {
        if searchText.isEmpty {
            return booksByGenre
        }
        
        let lowercasedQuery = searchText.lowercased()
        return booksByGenre.compactMap { genreGroup in
            let filteredBooks = genreGroup.books.filter { book in
                book.title.lowercased().contains(lowercasedQuery) ||
                book.authors.contains { $0.lowercased().contains(lowercasedQuery) } ||
                book.categories.contains { $0.lowercased().contains(lowercasedQuery) }
            }
            return filteredBooks.isEmpty ? nil : (genre: genreGroup.genre, books: filteredBooks)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(filteredGenres, id: \.genre) { genreGroup in
                    GenreSection(genre: genreGroup.genre, books: genreGroup.books)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct GenreSection: View {
    let genre: String
    let books: [Book]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section Header
            HStack {
                Text(genre)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if books.count > 6 {
                    NavigationLink(destination: GenreDetailView(genre: genre, books: books)) {
                        HStack(spacing: 4) {
                            Text("See all")
                                .font(.system(size: 14, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal)
            
            // Horizontal Scroll View of Books
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(books.prefix(10)) { book in
                        NavigationLink(destination: BookDetailView(book: book)) {
                            CompactBookCard(book: book)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct GenreDetailView: View {
    let genre: String
    let books: [Book]
    
    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
                ],
                spacing: 20
            ) {
                ForEach(books) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        FeaturedBookCard(book: book)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .navigationTitle(genre)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct CompactBookCard: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Book Cover - Larger and consistent
            EnhancedBookCover(coverURL: book.coverAssetName)
                .frame(width: 140, height: 210)
            
            // Book Info - Simplified
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                Text(book.formattedAuthors)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            .frame(width: 140, alignment: .leading)
        }
    }
}

struct FeaturedBookCard: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Book Cover
            BookCoverView(coverURL: book.coverAssetName, size: .medium)
            
            // Book Info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                Text(book.formattedAuthors)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
                
                if let nytRank = book.nytRank {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        
                        Text("NYT #\(nytRank)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                } else if let rank = book.popularityRank {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        
                        Text("#\(rank)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
                
                // Categories
                Text(book.formattedCategories)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 160)
        .background(Color.clear)
    }
}

struct InitialNYTView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("NYT Bestsellers")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Discover New York Times bestselling non-fiction books, organized by genre and ranked by popularity.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(.top, 100)
    }
}

struct EmptyNYTSearchView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No matches found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("No NYT bestsellers match \"\(searchText)\"")
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.top, 100)
    }
}

struct ErrorNYTView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Connection Error")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Unable to load NYT bestsellers. Please check your internet connection and try again.")
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