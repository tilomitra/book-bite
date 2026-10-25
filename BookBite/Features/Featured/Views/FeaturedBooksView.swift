import SwiftUI

struct FeaturedBooksView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    @StateObject private var viewModel: FeaturedBooksViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: FeaturedBooksViewModel(bookRepository: DependencyContainer.shared.bookRepository))
    }
    
    var body: some View {
        Group {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.featuredBooks.isEmpty {
                    ConsistentLoadingView(style: .primary, message: "Loading featured books...")
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
                        dailyIdea: viewModel.dailyIdea,
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
    }
}

struct FeaturedBooksContentView: View {
    let dailyIdea: DailyIdea?
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
                // Idea of the day - hidden while searching
                if let dailyIdea, searchText.isEmpty {
                    DailyIdeaCard(dailyIdea: dailyIdea)
                }

                // Noteworthy Section
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
            // Section Header - monochrome styling
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Noteworthy")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                // Refresh hint
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Pull to refresh")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.6))
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
    }
}

struct NoteworthyBookCard: View {
    let book: Book
    @EnvironmentObject var dependencies: DependencyContainer
    @State private var rating: BookRating?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Book Cover with badge
            ZStack(alignment: .topTrailing) {
                EnhancedBookCover(coverURL: book.coverAssetName)
                    .frame(width: 100, height: 150)

                // Popular/NYT badge - keeps color as it's a badge
                if book.popularityScore != nil || book.isNYTBestseller == true {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.nytGold)
                        .background(Circle().fill(Color.white))
                        .offset(x: 8, y: -8)
                }
            }
            .padding(.top, 8)

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

                // Rating display (keeps star color)
                if let rating = rating {
                    BookRatingDisplayView(rating: rating, showSource: false, compact: true)
                        .padding(.top, 1)
                }

                // Badges - keep colors as they're badges
                VStack(alignment: .leading, spacing: 2) {
                    if book.popularityScore != nil {
                        Text("Popular")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.badgeGreen)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.badgeGreen.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    // Popularity indicator
                    if let score = book.popularityScore, rating == nil {
                        HStack(spacing: 2) {
                            ForEach(0..<min(5, Int(score * 5)), id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(DesignSystem.Colors.starColor)
                            }
                        }
                    } else if book.isNYTBestseller == true {
                        Text("NYT Bestseller")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.nytGold)
                    }
                }
                .padding(.top, 2)

                Spacer(minLength: 0)
            }
            .frame(width: 100, height: 62, alignment: .top)
        }
        .frame(height: 232)
        .task {
            rating = await dependencies.ratingsService.getRatingForBook(book)
        }
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
    @EnvironmentObject var dependencies: DependencyContainer
    @State private var rating: BookRating?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Book Cover
            EnhancedBookCover(coverURL: book.coverAssetName)
                .frame(width: 90, height: 135)

            // Book Info
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

                // Rating display (keeps star color)
                if let rating = rating {
                    HStack(spacing: 4) {
                        StarRatingView(rating: rating.average, starSize: 8)
                        Text(rating.formattedAverage)
                            .font(.system(size: 8))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 1)
                }

                // Popular badge - keeps badge color
                if book.popularityScore != nil {
                    Text("Popular")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.badgeGreen)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.badgeGreen.opacity(0.15))
                        .clipShape(Capsule())
                        .padding(.top, 1)
                }

                Spacer(minLength: 0)
            }
            .frame(width: 90, height: 60, alignment: .top)
        }
        .frame(height: 199)
        .task {
            rating = await dependencies.ratingsService.getRatingForBook(book)
        }
    }
}

struct FeaturedBookCard: View {
    let book: Book
    @EnvironmentObject var dependencies: DependencyContainer
    @State private var rating: BookRating?

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

                // Rating display (keeps star color)
                if let rating = rating {
                    BookRatingDisplayView(rating: rating, showSource: false, compact: true)
                }

                // Badges - keep colors
                HStack(spacing: 4) {
                    if book.popularityScore != nil {
                        Text("Popular")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.badgeGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.badgeGreen.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    if let nytRank = book.nytRank {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.nytGold)

                            Text("NYT #\(nytRank)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.nytGold)
                        }
                    } else if let rank = book.popularityRank {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.starColor)

                            Text("#\(rank)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.starColor)
                        }
                    }
                }

                // Categories - monochrome
                Text(book.formattedCategories)
                    .font(.caption2)
                    .lineLimit(nil)
                    .foregroundColor(.secondary)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(height: 120)
        }
        .frame(maxWidth: 160)
        .frame(height: 280)
        .background(Color.clear)
        .task {
            rating = await dependencies.ratingsService.getRatingForBook(book)
        }
    }
}

struct InitialFeaturedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.primary.opacity(0.6))

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
                .foregroundColor(.primary.opacity(0.6))

            Text("Connection Error")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Unable to load featured books. Please check your internet connection and try again.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: retry) {
                Text("Try Again")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIColor.systemBackground))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.primary)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.top, 100)
    }
}