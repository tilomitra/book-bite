import SwiftUI

struct BookDetailView: View {
    @StateObject private var viewModel: BookDetailViewModel
    @State private var showExportSheet = false
    @State private var showComparisonView = false
    
    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookDetailViewModel(
            book: book,
            repository: DependencyContainer.shared.bookRepository
        ))
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                // Clean book header section
                bookHeader
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 24)
                
                // Loading or error states
                if viewModel.isLoadingSummary {
                    LoadingView()
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
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showExportSheet = true }) {
                        Label("Export Summary", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { showComparisonView = true }) {
                        Label("Compare Books", systemImage: "rectangle.split.2x1")
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.regenerateSummary()
                        }
                    }) {
                        Label("Regenerate Summary", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportOptionsSheet(book: viewModel.book, summary: viewModel.summary)
        }
        .sheet(isPresented: $showComparisonView) {
            ComparisonView(firstBook: viewModel.book)
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
            }
        }
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
            
            // Replace SummaryTabView with new elegant design
            EnhancedSummaryView(summary: summary, book: viewModel.book)
        }
    }
}