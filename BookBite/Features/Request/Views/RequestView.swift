import SwiftUI

struct RequestView: View {
    @StateObject private var viewModel = RequestViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBarView(viewModel: viewModel)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Error banner
                if let error = viewModel.searchError {
                    ErrorBanner(message: error) {
                        viewModel.searchError = nil
                    }
                }
                
                // Main content based on state
                Group {
                    switch viewModel.requestState {
                    case .idle:
                        InitialRequestView()
                        
                    case .searching:
                        LoadingSearchView()
                        
                    case .searchResults(let results):
                        if results.isEmpty {
                            EmptySearchResultsView(searchText: viewModel.searchText)
                        } else {
                            GoogleBookSearchResultsView(results: results) { result in
                                viewModel.requestBook(result)
                            }
                        }
                        
                    case .requestingBook(let result):
                        GeneratingSummaryView(bookResult: result)
                        
                    case .bookRequested(let book):
                        BookRequestedSuccessView(book: book) {
                            viewModel.resetToSearchResults()
                        }
                        
                    case .error(let errorMessage):
                        ErrorStateView(
                            errorMessage: errorMessage,
                            onRetry: {
                                if !viewModel.searchText.isEmpty {
                                    viewModel.searchBooks(query: viewModel.searchText)
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("Request Books")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct InitialRequestView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Hero illustration
            VStack(spacing: 16) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.blue)
                
                VStack(spacing: 8) {
                    Text("Request Any Book")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Search for any book to add it to your library")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // How it works
            VStack(spacing: 20) {
                Text("How it works:")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                HowItWorksStep(
                    number: "1",
                    title: "Search",
                    description: "Search for any book using the search bar above"
                )
                
                HowItWorksStep(
                    number: "2",
                    title: "Select",
                    description: "Choose the book you want from the search results"
                )
                
                HowItWorksStep(
                    number: "3",
                    title: "AI Analysis",
                    description: "Our AI generates a comprehensive summary with key insights"
                )
                
                HowItWorksStep(
                    number: "4",
                    title: "Ready to Read",
                    description: "The book is added to your library with intelligent summaries"
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.top, 40)
    }
}

struct HowItWorksStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Step number
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

struct LoadingSearchView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching books...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BookRequestedSuccessView: View {
    let book: Book
    let onContinueSearching: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            // Success illustration
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Book Added Successfully!")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Book preview
            VStack(spacing: 12) {
                AsyncImage(url: book.coverAssetName != nil ? URL(string: book.coverAssetName!) : nil) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "book.closed")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 100, height: 133)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(book.formattedAuthors)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Action buttons
            VStack(spacing: 12) {
                NavigationLink(destination: BookDetailView(book: book)) {
                    Text("View Book Summary")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: onContinueSearching) {
                    Text("Request Another Book")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding()
    }
}

struct ErrorStateView: View {
    let errorMessage: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: onRetry) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 120, height: 44)
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct SearchBarView: View {
    @ObservedObject var viewModel: RequestViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Search text field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search for any book...", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                        viewModel.clearSearch()
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
            Button(action: performSearch) {
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
        .padding(.bottom, 8)
    }
    
    private func performSearch() {
        let trimmedText = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            viewModel.searchBooks(query: trimmedText)
        }
    }
}

#Preview {
    NavigationStack {
        RequestView()
    }
}