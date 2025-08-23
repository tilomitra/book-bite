import SwiftUI

struct BookDetailView: View {
    @StateObject private var viewModel: BookDetailViewModel
    @StateObject private var colorExtractor = ColorExtractor()
    
    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookDetailViewModel(
            book: book,
            repository: DependencyContainer.shared.bookRepository
        ))
    }
    
    var body: some View {
        ZStack {
            // Background gradient based on book cover colors
            LinearGradient(
                colors: colorExtractor.backgroundGradient,
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea(.all, edges: .top)
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Clean book header section
                    bookHeader
                        .padding(.horizontal)
                        .padding(.top)
                        .padding(.bottom, 24)
                
                // Loading or error states
                if viewModel.isLoadingSummary {
                    VStack(spacing: 16) {
                        if viewModel.isGeneratingSummary {
                            GeneratingView(message: viewModel.generationMessage)
                        } else {
                            LoadingView()
                        }
                    }
                    .frame(height: 200)
                    .padding()
                } else if let error = viewModel.summaryError {
                    ErrorView(error: error) {
                        Task {
                            await viewModel.loadSummary()
                        }
                    }
                    .padding()
                } else if let summary = viewModel.summary {
                    // Extended summary section
                    summaryContent(summary)
                } else {
                    // No summary available - show generate button
                    noSummaryView
                }
            }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Share button
                Button(action: {
                    SharingService.shared.shareBook(viewModel.book)
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.primary)
                }
            }
        }
        .task {
            await colorExtractor.extractColors(from: viewModel.book.coverAssetName)
        }
    }
    
    var bookHeader: some View {
        VStack(spacing: 20) {
            // Book cover centered
            BookCoverView(coverURL: viewModel.book.coverAssetName, size: .large)
                .frame(height: 200)
                .shadow(radius: 10)
            
            // Book information
            VStack(spacing: 12) {
                Text(viewModel.book.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if let subtitle = viewModel.book.subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Text(viewModel.book.formattedAuthors)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary.opacity(0.8))
                
                VStack(spacing: 8) {
                    HStack(spacing: 20) {
                        // Publication info
                        Text(viewModel.publicationInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Reading time
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(viewModel.readingTime)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    // Book rating
                    if viewModel.isLoadingRating {
                        RatingLoadingView(compact: true)
                    } else if let rating = viewModel.rating {
                        BookRatingDisplayView(rating: rating, showSource: false, compact: true)
                    }
                }
            }
        }
    }
    
    var noSummaryView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary.opacity(0.7))
                
                VStack(spacing: 8) {
                    Text("No Summary Available")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("This book doesn't have an extended summary yet. Generate one to get key insights, ideas, and a detailed breakdown.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            Button(action: {
                Task {
                    await viewModel.generateSummary()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))
                    Text("Generate a summary")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(Color(UIColor.systemBackground))
    }
    
    func summaryContent(_ summary: Summary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hook section with clean design
            if !summary.oneSentenceHook.isEmpty {
                Text(summary.oneSentenceHook)
                    .font(.callout)
                    .italic()
                    .foregroundColor(.primary.opacity(0.9))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.systemGray6))
            }
            
            // Rating section
            if let rating = viewModel.rating {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Reader Reviews")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    
                    BookRatingDisplayView(rating: rating, showSource: true, compact: false)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
                .background(Color(UIColor.systemBackground))
            }
            
            // Replace SummaryTabView with new elegant design
            EnhancedSummaryView(
                summary: summary, 
                book: viewModel.book,
                dominantColor: colorExtractor.dominantColor,
                secondaryColor: colorExtractor.secondaryColor,
                onGenerateSummary: {
                    await viewModel.generateSummary()
                }
            )
        }
    }
}