import SwiftUI

struct BookPickerView: View {
    @ObservedObject var viewModel: ComparisonViewModel
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return viewModel.availableBooks
        }
        
        return viewModel.availableBooks.filter { book in
            book.title.lowercased().contains(searchText.lowercased()) ||
            book.authors.contains { $0.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredBooks) { book in
                Button(action: {
                    Task {
                        await viewModel.selectSecondBook(book)
                        dismiss()
                    }
                }) {
                    HStack(spacing: 12) {
                        BookCoverView(coverName: book.coverAssetName, size: .small)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            Text(book.formattedAuthors)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(book.formattedCategories)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .searchable(text: $searchText, prompt: "Search books")
            .navigationTitle("Select Book to Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}