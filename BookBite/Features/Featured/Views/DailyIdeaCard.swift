import SwiftUI

/// "Idea of the day": one short idea at the top of the Featured tab. Tap to open the book.
struct DailyIdeaCard: View {
    let dailyIdea: DailyIdea

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Idea of the day")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }

                Spacer()

                ShareLink(item: dailyIdea.shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                .accessibilityLabel("Share idea")
            }

            NavigationLink(destination: BookDetailView(book: dailyIdea.book)) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(dailyIdea.idea.idea)
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // Source book
                    HStack(spacing: 10) {
                        EnhancedBookCover(coverURL: dailyIdea.book.coverAssetName)
                            .frame(width: 36, height: 54)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(dailyIdea.book.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Text(dailyIdea.book.formattedAuthors)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text("Read more")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
