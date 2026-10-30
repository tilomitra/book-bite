import SwiftUI

/// Time left in a summary, from the reader's position and the summary's length.
enum ReadingTime {
    /// Whole minutes left (rounded up, at least 1), or nil when the summary's length is unknown.
    static func minutesLeft(fraction: Double, totalMinutes: Int?) -> Int? {
        guard let totalMinutes, totalMinutes > 0 else { return nil }
        let remaining = Double(totalMinutes) * (1 - min(max(fraction, 0), 1))
        return max(1, Int(remaining.rounded(.up)))
    }

    /// "12 min left", or a gentle prompt when the length is unknown.
    static func status(fraction: Double, totalMinutes: Int?) -> String {
        guard let minutes = minutesLeft(fraction: fraction, totalMinutes: totalMinutes) else {
            return "Pick up where you left off"
        }
        return "\(minutes) min left"
    }

    /// Minutes to read the summary's full text. Nil without full text: the stored `read_time_minutes`
    /// is an LLM guess, often the length of the whole book.
    static func totalMinutes(of summary: Summary?) -> Int? {
        guard let summary, summary.hasFullText else { return nil }
        return summary.summaryReadTimeMinutes
    }

    /// Summary length from what is already on device (the reader cached it when it was opened, or the
    /// book was downloaded). Never hits the network: Continue reading must not wait on the server.
    @MainActor
    static func cachedTotalMinutes(bookId: String) -> Int? {
        if let known = lengthCache[bookId] { return known }
        let summary = (try? CacheService.shared.getCachedSummary(bookId: bookId))
            ?? OfflineStorageService.shared.getOfflineSummary(bookId: bookId)
        let minutes = totalMinutes(of: summary)
        if let minutes { lengthCache[bookId] = minutes }
        return minutes
    }

    @MainActor private static var lengthCache: [String: Int] = [:]
}

/// A hairline progress bar: a faint track with the read part in the text colour.
struct ReadingProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(Color.primary)
                    .frame(width: max(2, proxy.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }
}

/// "Continue reading": unfinished summaries, newest first, as equal rows on one card.
/// Tapping opens the book page with the zoom transition from the cover.
struct ContinueReadingSection: View {
    let entries: [ReadingProgressStore.Entry]
    /// How many books to list
    var maxRows = 3

    @Namespace private var zoom

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                EditorialSectionTitle("Continue reading")

                let rows = Array(entries.prefix(maxRows))
                VStack(spacing: 0) {
                    ForEach(rows) { entry in
                        if entry.id != rows.first?.id {
                            // Starts at the text, so the covers read as one column
                            Divider().padding(.leading, 62)
                        }
                        NavigationLink {
                            BookDetailView(book: entry.book)
                                .navigationTransition(.zoom(sourceID: entry.book.id, in: zoom))
                        } label: {
                            ContinueReadingRow(entry: entry, zoom: zoom)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .background(Color.paperRaised, in: .rect(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
        }
    }
}

/// Minutes left for one entry, looked up once the row appears.
private struct ReadingStatusText: View {
    let entry: ReadingProgressStore.Entry
    @State private var totalMinutes: Int?

    var body: some View {
        Text(ReadingTime.status(fraction: entry.fraction, totalMinutes: totalMinutes))
            .monospacedDigit()
            .contentTransition(.numericText())
            .task(id: entry.book.id) {
                totalMinutes = entry.totalMinutes ?? ReadingTime.cachedTotalMinutes(bookId: entry.book.id)
            }
    }
}

/// Cover, title, time left and a hairline of progress. The whole row is the tap target.
private struct ContinueReadingRow: View {
    let entry: ReadingProgressStore.Entry
    let zoom: Namespace.ID

    var body: some View {
        HStack(spacing: 18) {
            EditorialCover(book: entry.book, width: 44)
                .zoomSource(id: entry.book.id, in: zoom)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.book.shelfTitle)
                    .font(.system(.body, design: .serif, weight: .medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                ReadingStatusText(entry: entry)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ReadingProgressBar(fraction: entry.fraction)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .multilineTextAlignment(.leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(entry.fraction, format: .percent.precision(.fractionLength(0))) read"))
        .accessibilityHint("Opens the book")
    }
}
