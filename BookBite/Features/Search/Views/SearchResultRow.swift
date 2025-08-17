import SwiftUI

struct SearchResultRow: View {
    let book: Book
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            BookCoverView(coverURL: book.coverAssetName, size: .medium)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                Text(book.formattedAuthors)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if !book.categories.isEmpty {
                    Text(book.categories.prefix(2).joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("8 min read")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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