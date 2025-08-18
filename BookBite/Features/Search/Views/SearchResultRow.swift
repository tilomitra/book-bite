import SwiftUI

struct SearchResultRow: View {
    let book: Book
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCoverView(coverURL: book.coverAssetName, size: .small)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                Text(book.formattedAuthors)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(book.publishedYear != nil ? String(book.publishedYear!) : "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if book.isNYTBestseller == true {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("NYT Bestseller")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.trailing, 4)
        }
        .padding(.vertical, 8)
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