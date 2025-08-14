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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                bookHeader
                
                if viewModel.isLoadingSummary {
                    LoadingView()
                        .frame(height: 200)
                } else if let error = viewModel.summaryError {
                    ErrorView(error: error) {
                        Task {
                            await viewModel.loadSummary()
                        }
                    }
                } else if let summary = viewModel.summary {
                    summaryContent(summary)
                }
            }
            .padding()
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
        HStack(alignment: .top, spacing: 16) {
            BookCoverView(coverName: viewModel.book.coverAssetName, size: .large)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.book.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                if let subtitle = viewModel.book.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(viewModel.book.formattedAuthors)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(viewModel.publicationInfo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "clock.fill")
                    Text(viewModel.readingTime)
                }
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(20)
            }
            
            Spacer()
        }
    }
    
    func summaryContent(_ summary: Summary) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(summary.oneSentenceHook)
                .font(.headline)
                .italic()
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            
            SummaryTabView(summary: summary)
                .frame(minHeight: 400)
        }
    }
}