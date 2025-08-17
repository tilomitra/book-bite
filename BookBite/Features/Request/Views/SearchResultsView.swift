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
            HStack(spacing: 12) {
                // Book cover
                AsyncImage(url: URL(string: result.coverUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "book.closed")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 60, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(result.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Subtitle (if available)
                    if let subtitle = result.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Authors
                    if !result.authors.isEmpty {
                        Text(result.formattedAuthors)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Publisher and year
                    HStack {
                        if let publisher = result.publisher {
                            Text(publisher)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let year = result.publishedYear {
                            Text("• \(year)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Categories
                    if !result.categories.isEmpty {
                        Text(result.formattedCategories)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                
                Spacer()
                
                VStack {
                    // Status indicator
                    if result.inDatabase {
                        Label("View in Library", systemImage: "book.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Label("Add to Library", systemImage: "plus.circle")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
            }
            .padding(.vertical, 8)
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