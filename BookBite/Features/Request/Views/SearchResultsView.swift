import SwiftUI

struct GoogleBookSearchResultsView: View {
    let results: [GoogleBookSearchResult]
    let onBookSelected: (GoogleBookSearchResult) -> Void
    
    var body: some View {
        List(results) { result in
            GoogleBookSearchResultRow(
                result: result,
                onTap: { onBookSelected(result) }
            )
        }
        .listStyle(PlainListStyle())
    }
}

struct GoogleBookSearchResultRow: View {
    let result: GoogleBookSearchResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 16) {
                BookCoverView(coverURL: result.coverUrl, size: .medium)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    Text(result.formattedAuthors)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if !result.categories.isEmpty {
                        Text(result.categories.prefix(2).joined(separator: " · "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .padding(.top, 2)
                    }
                    
                    HStack(spacing: 4) {
                        if result.inDatabase {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text("In Library")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "plus.circle")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("Add to Library")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptySearchResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No books found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("No books match \"\(searchText)\"")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Try different keywords or check your spelling")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(.top, 100)
        .padding(.horizontal, 40)
    }
}

#Preview {
    GoogleBookSearchResultsView(
        results: [
            GoogleBookSearchResult(
                googleBooksId: "1",
                title: "Sample Book",
                subtitle: "A Great Read",
                authors: ["Author Name"],
                description: "Description",
                categories: ["Business", "Self-Help"],
                publisher: "Publisher",
                publishedYear: 2023,
                isbn10: nil,
                isbn13: nil,
                coverUrl: nil,
                inDatabase: false
            )
        ],
        onBookSelected: { _ in }
    )
}