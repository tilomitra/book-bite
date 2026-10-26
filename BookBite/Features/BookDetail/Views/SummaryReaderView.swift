import SwiftUI

/// The full summary as plain, comfortable reading text.
struct SummaryReaderView: View {
    let book: Book
    let summary: Summary

    @AppStorage("readerTextSize") private var textSize: Double = 18

    private let minTextSize: Double = 14
    private let maxTextSize: Double = 26

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.system(.title, design: .serif))
                        .fontWeight(.bold)

                    Text(book.formattedAuthors)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(summary.summaryReadTimeMinutes) min read")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(summary.extendedSummary ?? "")
                    .font(.system(size: textSize, design: .serif))
                    .lineSpacing(textSize * 0.4)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 40)
            // Keep lines a readable length on wide screens
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        textSize = min(maxTextSize, textSize + 2)
                    } label: {
                        Label("Larger text", systemImage: "textformat.size.larger")
                    }
                    .disabled(textSize >= maxTextSize)

                    Button {
                        textSize = max(minTextSize, textSize - 2)
                    } label: {
                        Label("Smaller text", systemImage: "textformat.size.smaller")
                    }
                    .disabled(textSize <= minTextSize)
                } label: {
                    Image(systemName: "textformat.size")
                }
                .accessibilityLabel("Text size")
            }
        }
    }
}
