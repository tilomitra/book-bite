import SwiftUI

struct SearchResultRow: View {
    let book: Book
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCoverView(coverURL: book.coverAssetName, size: .small)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(book.formattedAuthors)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    ForEach(book.categories.prefix(3), id: \.self) { category in
                        CategoryChip(category: category)
                    }
                }
                .padding(.top, 4)
                
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("8 min read")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.top, 2)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct CategoryChip: View {
    let category: String
    
    var body: some View {
        Text(category)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(6)
    }
}