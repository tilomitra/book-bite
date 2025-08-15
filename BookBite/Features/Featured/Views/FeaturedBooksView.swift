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
                    ErrorFeaturedView(error: error) {
                        Task {
                            await viewModel.loadFeaturedBooks()
                        }
                    }
                } else if viewModel.showEmptyState {
                    EmptyFeaturedSearchView(searchText: viewModel.searchText)
                } else if viewModel.showInitialState {
                    InitialFeaturedView()
                } else {
                    FeaturedBooksList(books: viewModel.filteredBooks)
                }
            }
            .navigationTitle("Featured Books")
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search featured books"
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

struct FeaturedBooksList: View {
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
    }
}

struct FeaturedBookCard: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Book Cover
            BookCoverView(coverName: book.coverAssetName, size: .medium)
            
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
                
                if let rank = book.popularityRank {
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

struct InitialFeaturedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Featured Books")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Discover the top 100 management and software development books, curated for technology professionals.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(.top, 100)
    }
}

struct EmptyFeaturedSearchView: View {
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

struct ErrorFeaturedView: View {
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