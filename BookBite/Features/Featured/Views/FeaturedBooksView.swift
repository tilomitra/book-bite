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
                    InitialFeaturedView()
                } else {
                    FeaturedBooksContentView(
                        noteworthyBooks: viewModel.noteworthyBooks,
                        featuredBooks: viewModel.featuredBooks,
                        booksByGenre: viewModel.booksByGenre,
                        searchText: viewModel.searchText
                    )
                }
            }
            .navigationTitle("Featured")
            .refreshable {
                await viewModel.refreshFeaturedBooks()
            }
        }
        .onAppear {
            Task {
                await viewModel.loadFeaturedBooks()
            }
        }
    }
}

struct FeaturedBooksContentView: View {
    let noteworthyBooks: [Book]
    let featuredBooks: [Book]
    let booksByGenre: [(genre: String, books: [Book])]
    let searchText: String
    
    var filteredNoteworthyBooks: [Book] {
        if searchText.isEmpty {
            return noteworthyBooks
        }
        
        let lowercasedQuery = searchText.lowercased()
        return noteworthyBooks.filter { book in
            book.title.lowercased().contains(lowercasedQuery) ||
            book.authors.contains { $0.lowercased().contains(lowercasedQuery) } ||
            book.categories.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
    
    var filteredFeaturedBooks: [Book] {
        if searchText.isEmpty {
            return featuredBooks
        }
        
        let lowercasedQuery = searchText.lowercased()
        return featuredBooks.filter { book in
            book.title.lowercased().contains(lowercasedQuery) ||
            book.authors.contains { $0.lowercased().contains(lowercasedQuery) } ||
            book.categories.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Noteworthy Section - Always at the top
                if !filteredNoteworthyBooks.isEmpty {
                    NoteworthySection(books: filteredNoteworthyBooks)
                }
                
                // Featured Books Section
                if !filteredFeaturedBooks.isEmpty {
                    FeaturedSection(books: filteredFeaturedBooks)
                }
                
                // NYT Bestsellers by Genre
                FeaturedBooksGenreView(booksByGenre: booksByGenre, searchText: searchText)
            }
            .padding(.vertical, 4)
        }
    }
}

struct NoteworthySection: View {
    let books: [Book]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section Header with special styling
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.orange)
                    
                    Text("Noteworthy")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Refresh hint
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.8))
                    Text("Pull to refresh")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .padding(.horizontal)
            
            // Horizontal Scroll View of Books
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(books) { book in
                        NavigationLink(destination: BookDetailView(book: book)) {
                            NoteworthyBookCard(book: book)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.orange.opacity(0.05),
                    Color.clear
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct NoteworthyBookCard: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Book Cover with badge - added padding to prevent cutoff
            ZStack(alignment: .topTrailing) {
                EnhancedBookCover(coverURL: book.coverAssetName)
                    .frame(width: 100, height: 150)
                
                // Popular badge
                if book.popularityScore != nil || book.isNYTBestseller == true {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                        .background(Circle().fill(Color.white))
                        .offset(x: 8, y: -8)
                }
            }
            .padding(.top, 8) // Add padding to accommodate the badge
            
            // Book Info
            VStack(alignment: .leading, spacing: 1) {
                Text(book.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                Text(book.formattedAuthors)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
                
                // Popularity indicator
                if let score = book.popularityScore {
                    HStack(spacing: 2) {
                        ForEach(0..<min(5, Int(score * 5)), id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.top, 2)
                } else if book.isNYTBestseller == true {
                    Text("NYT Bestseller")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                }
                
                Spacer(minLength: 0)
            }
            .frame(width: 100, height: 62, alignment: .top) // Reduced height to compensate for top padding
        }
        .frame(height: 232) // Increased total height to accommodate padding
    }
}

struct FeaturedSection: View {
    let books: [Book]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section Header
            HStack {
                Text("Featured Books")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if books.count > 6 {
                    NavigationLink(destination: FeaturedDetailView(books: books)) {
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
                HStack(spacing: 8) {
                    ForEach(books.prefix(15)) { book in
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

struct FeaturedDetailView: View {
    let books: [Book]
    
    var sortedBooks: [Book] {
        books.sorted { book1, book2 in
            // First priority: books with popularity_score
            if let score1 = book1.popularityScore, let score2 = book2.popularityScore {
                return score1 > score2  // Higher scores first
            }
            
            // Second priority: books with popularity_score over those without
            if book1.popularityScore != nil && book2.popularityScore == nil {
                return true
            }
            if book1.popularityScore == nil && book2.popularityScore != nil {
                return false
            }
            
            // Final fallback: alphabetical by title
            return book1.title.localizedCaseInsensitiveCompare(book2.title) == .orderedAscending
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
                ],
                spacing: 20
            ) {
                ForEach(sortedBooks) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        FeaturedBookCard(book: book)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .navigationTitle("Featured Books")
        .navigationBarTitleDisplayMode(.large)
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
            VStack(alignment: .leading, spacing: 16) {
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
                HStack(spacing: 8) {
                    ForEach(books.prefix(15)) { book in
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
    
    var sortedBooks: [Book] {
        books.sorted { book1, book2 in
            // First priority: books with popularity_score
            if let score1 = book1.popularityScore, let score2 = book2.popularityScore {
                return score1 > score2  // Higher scores first
            }
            
            // Second priority: books with popularity_score over those without
            if book1.popularityScore != nil && book2.popularityScore == nil {
                return true
            }
            if book1.popularityScore == nil && book2.popularityScore != nil {
                return false
            }
            
            // Final fallback: alphabetical by title
            return book1.title.localizedCaseInsensitiveCompare(book2.title) == .orderedAscending
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
                ],
                spacing: 20
            ) {
                ForEach(sortedBooks) { book in
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
        VStack(alignment: .leading, spacing: 4) {
            // Book Cover - Smaller for more content
            EnhancedBookCover(coverURL: book.coverAssetName)
                .frame(width: 90, height: 135)
            
            // Book Info - Simplified
            VStack(alignment: .leading, spacing: 1) {
                Text(book.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                Text(book.formattedAuthors)
                    .font(.system(size: 9))
                    .lineLimit(nil)
                    .foregroundColor(.secondary)
                
                // Add spacer to push content to top
                Spacer(minLength: 0)
            }
            .frame(width: 90, height: 60, alignment: .top)
        }
        .frame(height: 199) // Fixed height: 135 (cover) + 4 (spacing) + 60 (text area)
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
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                Text(book.formattedAuthors)
                    .font(.caption2)
                    .lineLimit(nil)
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
                    .lineLimit(nil)
                    .foregroundColor(.secondary)
                
                // Add spacer to push content to top
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(height: 120)
        }
        .frame(maxWidth: 160)
        .frame(height: 280) // Fixed height for consistent alignment
        .background(Color.clear)
    }
}

struct InitialFeaturedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Featured Books")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Discover hand-picked featured books and New York Times bestselling non-fiction books, organized by genre and ranked by popularity.")
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
            
            Text("No featured books match \"\(searchText)\"")
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
            
            Text("Unable to load featured books. Please check your internet connection and try again.")
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