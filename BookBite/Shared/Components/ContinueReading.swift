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

/// "Continue reading": the most recent unfinished summary large, the next few as compact rows.
/// Tapping opens the book page with the zoom transition from the cover.
struct ContinueReadingSection: View {
    let entries: [ReadingProgressStore.Entry]
    /// How many more books to list below the main one
    var maxCompactRows = 3

    @Namespace private var zoom

    var body: some View {
        if let first = entries.first {
            VStack(alignment: .leading, spacing: 14) {
                Text("Continue reading")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                link(to: first.book) {
                    ContinueReadingFeatureRow(entry: first, zoom: zoom)
                }

                let others = entries.dropFirst().prefix(maxCompactRows)
                if !others.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(others) { entry in
                            Divider()
                            link(to: entry.book) {
                                ContinueReadingCompactRow(entry: entry, zoom: zoom)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func link<Label: View>(to book: Book, @ViewBuilder label: () -> Label) -> some View {
        NavigationLink {
            BookDetailView(book: book)
                .navigationTransition(.zoom(sourceID: book.id, in: zoom))
        } label: {
            label()
        }
        .buttonStyle(.plain)
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
                totalMinutes = ReadingTime.cachedTotalMinutes(bookId: entry.book.id)
            }
    }
}

private struct ContinueReadingFeatureRow: View {
    let entry: ReadingProgressStore.Entry
    let zoom: Namespace.ID
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility text sizes the text goes under the cover instead of squeezing beside it
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 18))

        layout {
            EditorialCover(book: entry.book, width: 76)
                .zoomSource(id: entry.book.id, in: zoom)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.book.shelfTitle)
                    .font(.system(.title3, design: .serif, weight: .medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(entry.book.shelfAuthor)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 14)

                ReadingProgressBar(fraction: entry.fraction)
                    .padding(.bottom, 6)

                HStack {
                    ReadingStatusText(entry: entry)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .multilineTextAlignment(.leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(entry.fraction, format: .percent.precision(.fractionLength(0))) read"))
        .accessibilityHint("Opens the book")
    }
}

private struct ContinueReadingCompactRow: View {
    let entry: ReadingProgressStore.Entry
    let zoom: Namespace.ID

    var body: some View {
        HStack(spacing: 14) {
            EditorialCover(book: entry.book, width: 32)
                .zoomSource(id: entry.book.id, in: zoom)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.book.shelfTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                ReadingStatusText(entry: entry)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .multilineTextAlignment(.leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(entry.fraction, format: .percent.precision(.fractionLength(0))) read"))
        .accessibilityHint("Opens the book")
    }
}
