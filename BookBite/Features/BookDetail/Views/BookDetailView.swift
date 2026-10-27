import SwiftUI

/// The book page: who wrote it, what it promises, its key ideas as a deck of cards, how to use them,
/// and an honest counterpoint. The full summary opens in a reader.
struct BookDetailView: View {
    @StateObject private var viewModel: BookDetailViewModel
    @ObservedObject private var audioService = AudioPlaybackService.shared
    @ObservedObject private var progressStore = ReadingProgressStore.shared
    @State private var showingChatSheet = false
    @State private var showingAuthSheet = false
    @State private var showingAudioPlayer = false
    @State private var coverTint: Color?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var authService: SupabaseAuthService

    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookDetailViewModel(
            book: book,
            repository: DependencyContainer.shared.bookRepository
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                bookHeader

                summaryContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 48)
            // Keep lines a readable length on wide screens
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .background(alignment: .top) { coverWash }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: viewModel.summary?.id)
        }
        .background(Color.paper.ignoresSafeArea())
        .task {
            RecentBooksStore.shared.record(viewModel.book)
            // Without a cover image the page shows a TypographicCover: tint with its cloth colour
            let tint = await CoverTint.color(for: viewModel.book.coverAssetName)
                ?? Color(TypographicCover.cloth(for: viewModel.book.title))
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) { coverTint = tint }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: handleFavoriteButtonTapped) {
                    if viewModel.isLoadingFavorite {
                        ProgressView()
                    } else {
                        Image(systemName: viewModel.isFavorite ? "bookmark.fill" : "bookmark")
                    }
                }
                .accessibilityLabel(viewModel.isFavorite ? "Remove from saved" : "Save")

                Button(action: {
                    SharingService.shared.shareBook(viewModel.book)
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
        }
        .sheet(isPresented: $showingChatSheet) {
            NavigationStack {
                BookChatView(book: viewModel.book)
                    .navigationTitle(viewModel.book.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingChatSheet = false
                            }
                        }
                    }
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAuthSheet) {
            AuthenticationView(authService: authService)
        }
        .sheet(isPresented: $showingAudioPlayer) {
            AudioPlayerView(audioService: audioService)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    /// A wash of the cover's color behind the header, fading into the page. Scrolls with the content.
    private var coverWash: some View {
        LinearGradient(
            colors: [(coverTint ?? .clear).opacity(0.5), (coverTint ?? .clear).opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 760)
        // Extend above the content, under the navigation bar and into the overscroll area
        .offset(y: -300)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var bookHeader: some View {
        VStack(spacing: 22) {
            EditorialCover(book: viewModel.book, width: 168)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(viewModel.book.title)
                    .font(.system(.title, design: .serif))
                    .fontWeight(.medium)
                    .tracking(-0.3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle = viewModel.book.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(.callout, design: .serif))
                        .italic()
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !viewModel.book.authors.isEmpty {
                    Text(viewModel.book.formattedAuthors)
                        .font(.footnote.weight(.semibold))
                        .tracking(1)
                        .textCase(.uppercase)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .accessibilityLabel("By \(viewModel.book.formattedAuthors)")
                }

                if let year = viewModel.book.publishedYear {
                    Text(String(year))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Published \(String(year))")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Summary

    @ViewBuilder
    private var summaryContent: some View {
        if viewModel.isLoadingSummary {
            Group {
                if viewModel.isGeneratingSummary {
                    GeneratingView(message: viewModel.generationMessage)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 160)
        } else if let error = viewModel.summaryError {
            ContentUnavailableView {
                Label("Can't load the summary", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.loadSummary() }
                }
                .buttonStyle(.bordered)
            }
        } else if let summary = viewModel.summary {
            VStack(alignment: .leading, spacing: 44) {
                VStack(spacing: 28) {
                    if !summary.oneSentenceHook.isEmpty {
                        hook(summary.oneSentenceHook)
                    }
                    actions(for: summary)
                }
                summaryBody(summary)
            }
            .transition(.opacity)
        } else {
            noSummaryView
        }
    }

    /// The book's promise in one sentence, set like a magazine dek under the title.
    private func hook(_ text: String) -> some View {
        Text(text)
            .font(.system(.title3, design: .serif))
            .lineSpacing(5)
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
    }

    private func actions(for summary: Summary) -> some View {
        VStack(spacing: 12) {
            if summary.hasFullText {
                readButton(for: summary)
            }

            // Side by side when they fit; stacked at large text sizes
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { secondaryActions(for: summary) }
                VStack(spacing: 12) { secondaryActions(for: summary) }
            }
        }
    }

    @ViewBuilder
    private func secondaryActions(for summary: Summary) -> some View {
        if summary.hasAudio {
            secondaryButton(
                title: summary.formattedAudioDuration.map { "Listen · \($0)" } ?? "Listen",
                icon: "headphones"
            ) {
                audioService.loadAudio(for: viewModel.book, summary: summary, autoPlay: true)
                showingAudioPlayer = true
            }
        }

        secondaryButton(title: "Ask the book", icon: "bubble.left") {
            showingChatSheet = true
        }
    }

    private func secondaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .padding(.horizontal, 12)
                .foregroundStyle(.primary)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.18), lineWidth: 0.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Read button

    /// Where the reader stands with this summary: not started, part way, or finished.
    private enum ReadingState: Equatable {
        case unread(minutes: Int)
        case inProgress(fraction: Double, minutesLeft: Int)
        case finished
    }

    private func readingState(for summary: Summary) -> ReadingState {
        let total = max(1, summary.summaryReadTimeMinutes)
        guard let entry = progressStore.entry(for: viewModel.book.id) else { return .unread(minutes: total) }
        if entry.isFinished { return .finished }
        // Same threshold as the store's "in progress": a glance isn't a start
        guard entry.fraction >= 0.03 else { return .unread(minutes: total) }
        let left = max(1, Int((Double(total) * (1 - entry.fraction)).rounded(.up)))
        return .inProgress(fraction: entry.fraction, minutesLeft: left)
    }

    private func readButton(for summary: Summary) -> some View {
        let state = readingState(for: summary)
        let title: String
        let icon: String
        switch state {
        case .unread(let minutes):
            title = "Read summary · \(minutes) min"
            icon = "book"
        case .inProgress(_, let left):
            title = "Continue reading · \(left) min left"
            icon = "book"
        case .finished:
            title = "Read again"
            icon = "checkmark"
        }

        return NavigationLink(destination: SummaryReaderView(book: viewModel.book, summary: summary)) {
            Label {
                Text(title)
                    .contentTransition(.interpolate)
            } icon: {
                Image(systemName: icon)
                    .contentTransition(.symbolEffect(.replace))
            }
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 16)
            .foregroundStyle(Color.paper)
            .background(Color.primary)
            // How far through: a thin line along the bottom edge
            .overlay(alignment: .bottomLeading) {
                if case .inProgress(let fraction, _) = state {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(Color.paper.opacity(0.45))
                            .frame(width: proxy.size.width * fraction, height: 3)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .snappy, value: state)
        .accessibilityValue(readingAccessibilityValue(state))
    }

    private func readingAccessibilityValue(_ state: ReadingState) -> String {
        switch state {
        case .unread: return ""
        case .inProgress(let fraction, _): return "\(Int((fraction * 100).rounded())) percent read"
        case .finished: return "Finished"
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func summaryBody(_ summary: Summary) -> some View {
        if !summary.keyIdeas.isEmpty {
            DetailSection(title: "Key ideas") {
                KeyIdeaDeck(ideas: summary.keyIdeas, book: viewModel.book, tint: coverTint)
            }
        }

        if !summary.howToApply.isEmpty {
            DetailSection(title: "How to apply it") {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(summary.howToApply.enumerated()), id: \.offset) { index, point in
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text("\(index + 1)")
                                .font(.system(.body, design: .serif).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 14, alignment: .leading)

                            Text(point.action)
                                .font(.body)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Step \(index + 1). \(point.action)")
                    }
                }
            }
        }

        if !summary.whoShouldRead.isEmpty {
            DetailSection(title: "Who it's for") {
                Text(summary.whoShouldRead)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(5)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        OtherSideSection(summary: summary)
    }

    private var noSummaryView: some View {
        ContentUnavailableView {
            Label("No summary yet", systemImage: "doc.text")
        } description: {
            Text("Create a summary of the key ideas in this book. It can take a few minutes.")
        } actions: {
            Button("Create summary") {
                Task { await viewModel.generateSummary() }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Actions

    private func handleFavoriteButtonTapped() {
        if authService.authState.isAuthenticated {
            Task {
                await viewModel.toggleFavorite()
            }
        } else {
            // Saving needs an account
            showingAuthSheet = true
        }
    }
}

/// A headed block of the book page: a hairline, then a serif heading.
private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 0.5)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(.title2, design: .serif))
                    .fontWeight(.medium)
                    .accessibilityAddTraits(.isHeader)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "The other side": where the book has been criticised, what it leaves out, and how readers tend
/// to misapply it. An honest counterpoint, quieter than the rest of the page; folded when long,
/// hidden when the summary has none.
private struct OtherSideSection: View {
    let summary: Summary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    private struct PointGroup: Identifiable {
        let title: String
        let points: [String]
        var id: String { title }
    }

    private var groups: [PointGroup] {
        func clean(_ items: [String]) -> [String] {
            items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        let limitation = summary.limitations.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            PointGroup(title: "Critiques", points: clean(summary.critiques)),
            PointGroup(title: "What it leaves out", points: limitation.isEmpty ? [] : [limitation]),
            PointGroup(title: "Common pitfalls", points: clean(summary.commonPitfalls)),
        ].filter { !$0.points.isEmpty }
    }

    /// Long enough to fold: more than four points, or a lot of text
    private var isLong: Bool {
        let points = groups.flatMap(\.points)
        return points.count > 4 || points.reduce(0) { $0 + $1.count } > 480
    }

    /// Folded, only the first group's first two points show
    private var visibleGroups: [PointGroup] {
        guard isLong, !expanded, let first = groups.first else { return groups }
        return [PointGroup(title: first.title, points: Array(first.points.prefix(2)))]
    }

    var body: some View {
        if !groups.isEmpty {
            DetailSection(title: "The other side") {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Where the book has been criticised, what it leaves out, and where readers go wrong.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(visibleGroups) { group in
                        groupView(group)
                    }

                    if isLong {
                        foldButton
                    }
                }
            }
        }
    }

    private func groupView(_ group: PointGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(group.title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(group.points.enumerated()), id: \.offset) { _, point in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\u{2013}")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                    Text(point)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.8))
                .transition(.opacity)
            }
        }
        .transition(.opacity)
    }

    private var foldButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { expanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(expanded ? "Show less" : "Show all")
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(expanded ? "Show less" : "Show all critiques and pitfalls")
    }
}
