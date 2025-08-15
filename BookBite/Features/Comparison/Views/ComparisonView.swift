import SwiftUI

struct ComparisonView: View {
    @StateObject private var viewModel: ComparisonViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showBookPicker = false
    
    init(firstBook: Book) {
        _viewModel = StateObject(wrappedValue: ComparisonViewModel(
            firstBook: firstBook,
            repository: DependencyContainer.shared.bookRepository
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                comparisonHeader
                
                if viewModel.secondBook != nil {
                    comparisonControls
                    comparisonContent
                } else {
                    emptySecondBookView
                }
            }
            .navigationTitle("Compare Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if viewModel.secondBook != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Change") {
                            showBookPicker = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showBookPicker) {
                BookPickerView(viewModel: viewModel)
            }
        }
    }
    
    var comparisonHeader: some View {
        HStack(spacing: 16) {
            bookCard(book: viewModel.firstBook, summary: viewModel.firstSummary)
            
            Image(systemName: "arrow.left.arrow.right")
                .font(.title2)
                .foregroundColor(.secondary)
            
            if let secondBook = viewModel.secondBook {
                bookCard(book: secondBook, summary: viewModel.secondSummary)
            } else {
                emptyBookCard
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
    }
    
    func bookCard(book: Book, summary: Summary?) -> some View {
        VStack(spacing: 8) {
            BookCoverView(coverURL: book.coverAssetName, size: .small)
            
            Text(book.title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            if let summary = summary {
                Text("\(summary.readTimeMinutes) min")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    var emptyBookCard: some View {
        VStack(spacing: 8) {
            Button(action: { showBookPicker = true }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundColor(.secondary)
                        .frame(width: 60, height: 90)
                    
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Select Book")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    var comparisonControls: some View {
        HStack {
            Toggle("Synchronized Scrolling", isOn: $viewModel.synchronizedScrolling)
                .font(.caption)
            
            Spacer()
            
            if !viewModel.findCommonThemes().isEmpty {
                Label("\(viewModel.findCommonThemes().count) Common Themes", systemImage: "link")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.05))
    }
    
    var comparisonContent: some View {
        GeometryReader { geometry in
            if UIDevice.current.userInterfaceIdiom == .pad {
                HStack(spacing: 16) {
                    bookSummaryView(
                        book: viewModel.firstBook,
                        summary: viewModel.firstSummary,
                        width: geometry.size.width / 2 - 16
                    )
                    
                    Divider()
                    
                    if let secondBook = viewModel.secondBook,
                       let secondSummary = viewModel.secondSummary {
                        bookSummaryView(
                            book: secondBook,
                            summary: secondSummary,
                            width: geometry.size.width / 2 - 16
                        )
                    }
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        bookSummaryView(
                            book: viewModel.firstBook,
                            summary: viewModel.firstSummary,
                            width: geometry.size.width - 32
                        )
                        
                        if let secondBook = viewModel.secondBook,
                           let secondSummary = viewModel.secondSummary {
                            Divider()
                                .padding(.vertical)
                            
                            bookSummaryView(
                                book: secondBook,
                                summary: secondSummary,
                                width: geometry.size.width - 32
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    func bookSummaryView(book: Book, summary: Summary?, width: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let summary = summary {
                    Text(summary.oneSentenceHook)
                        .font(.headline)
                        .italic()
                    
                    Text("Key Ideas")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.top)
                    
                    ForEach(summary.keyIdeas) { idea in
                        ComparisonIdeaRow(
                            idea: idea,
                            isUnique: viewModel.findUniqueIdeas(for: book).contains(where: { $0.id == idea.id })
                        )
                    }
                }
            }
            .frame(width: width)
        }
    }
    
    var emptySecondBookView: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Select a second book to compare")
                .font(.headline)
            
            Button(action: { showBookPicker = true }) {
                Label("Choose Book", systemImage: "plus.circle.fill")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding(.top, 60)
    }
}

struct ComparisonIdeaRow: View {
    let idea: KeyIdea
    let isUnique: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUnique {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(idea.idea)
                    .font(.body)
                
                ConfidenceBadge(confidence: idea.confidence)
            }
        }
        .padding(8)
        .background(isUnique ? Color.yellow.opacity(0.1) : Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}