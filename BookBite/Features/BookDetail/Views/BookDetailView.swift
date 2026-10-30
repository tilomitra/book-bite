import SwiftUI

/// The book page: who wrote it, what it promises, its key ideas as a deck of cards, how to use them,
/// and an honest counterpoint. The full summary opens in a reader.
struct BookDetailView: View {
    @StateObject private var viewModel: BookDetailViewModel
    @ObservedObject private var audioService = AudioPlaybackService.shared
    @ObservedObject private var progressStore = ReadingProgressStore.shared
    @ObservedObject private var passStore = ReadingPassStore.shared
    /// The reading pass sheet, when the book is out of free books
    @State private var showingPass = false
    @State private var signInPrompt: SignInPrompt?
    @State private var showingAudioPlayer = false
    @State private var coverTint: Color?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var authService: SupabaseAuthService

    /// iPad and other wide windows: the cover and actions stay in a column on the left, the summary scrolls beside them
    private var isWide: Bool { horizontalSizeClass == .regular }

    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookDetailViewModel(
            book: book,
            repository: DependencyContainer.shared.bookRepository
        ))
    }

    var body: some View {
        Group {
            if isWide {
                wideLayout
            } else {
                compactLayout
            }
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
        .signInPrompt($signInPrompt)
        .sheet(isPresented: $showingAudioPlayer) {
            AudioPlayerView(audioService: audioService)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingPass) {
            ReadingPassView(book: viewModel.book)
        }
    }

    // MARK: - Layouts

    private var compactLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                bookHeader(coverWidth: 168)

                summaryContent(showsActions: true)
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
    }

    /// Two columns: the book and what you can do with it on a wash of the cover's colour, the summary on paper
    private var wideLayout: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    bookHeader(coverWidth: 220)

                    if let summary = viewModel.summary, !viewModel.isLoadingSummary {
                        actions(for: summary)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(width: 400)
            .background {
                (coverTint ?? .clear).opacity(0.3)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }

            ScrollView {
                summaryContent(showsActions: false)
                    .padding(.horizontal, 48)
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: viewModel.summary?.id)
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

    private func bookHeader(coverWidth: CGFloat) -> some View {
        VStack(spacing: 22) {
            EditorialCover(book: viewModel.book, width: coverWidth)
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

    /// The summary sections. With `showsActions` false (wide layout) the read and listen buttons live in the left column.
    @ViewBuilder
    private func summaryContent(showsActions: Bool) -> some View {
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
                        hook(summary.oneSentenceHook, centered: showsActions)
                    }
                    if showsActions {
                        actions(for: summary)
                    }
                }
                summaryBody(summary)
            }
            .transition(.opacity)
        } else {
            noSummaryView
        }
    }

    /// The book's promise in one sentence, set like a magazine dek under the title.
    /// Centered under the title on iPhone; on the wide layout it opens the right column, larger and flush left.
    private func hook(_ text: String, centered: Bool) -> some View {
        Text(text)
            .font(.system(centered ? .title3 : .title, design: .serif))
            .lineSpacing(centered ? 5 : 6)
            .multilineTextAlignment(centered ? .center : .leading)
            .foregroundStyle(.primary.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            .padding(.horizontal, centered ? 4 : 0)
    }

    private func actions(for summary: Summary) -> some View {
        VStack(spacing: 12) {
            if summary.hasFullText {
                readButton(for: summary)
            }

            if summary.hasAudio {
                secondaryButton(
                    title: summary.formattedAudioDuration.map { "Listen · \($0)" } ?? "Listen",
                    icon: access == .locked ? "lock" : "headphones"
                ) {
                    listen(to: summary)
                }
            }

            if summary.hasFullText || summary.hasAudio, let caption = passCaption {
                Button { showingPass = true } label: {
                    Text(caption)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows your reading pass")
            }
        }
    }

    // MARK: - Reading pass

    private var access: ReadingAccess {
        passStore.access(for: viewModel.book.id)
    }

    /// What opening this book means for the pass, under the buttons. Nothing once it's on the shelf.
    private var passCaption: String? {
        switch access {
        case .unlimited, .unlocked: return nil
        case .free(let remaining) where remaining == 1: return "This is your last free book · Give 5, get 5"
        case .free(let remaining): return "Uses 1 of your \(remaining) free books"
        case .locked: return "You've read your free books · Give a friend 5, get 5"
        }
    }

    private func listen(to summary: Summary) {
        guard access != .locked else {
            showingPass = true
            return
        }
        Task {
            guard await passStore.open(viewModel.book.id) else {
                showingPass = true
                return
            }
            audioService.loadAudio(for: viewModel.book, summary: summary, autoPlay: true)
            showingAudioPlayer = true
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

    private func readTitle(for state: ReadingState) -> (title: String, icon: String) {
        switch state {
        case .unread(let minutes): return ("Read summary · \(minutes) min", "book")
        case .inProgress(_, let left): return ("Continue reading · \(left) min left", "book")
        case .finished: return ("Read again", "checkmark")
        }
    }

    @ViewBuilder
    private func readButton(for summary: Summary) -> some View {
        let state = readingState(for: summary)
        let label = readTitle(for: state)

        if access == .locked {
            // Out of free books: the button opens the pass instead of the reader
            Button { showingPass = true } label: {
                readLabel(title: label.title, icon: "lock", state: state)
            }
            .buttonStyle(.plain)
            .accessibilityHint("You've read your free books. Shows ways to read more.")
        } else {
            // The reader takes a free book from the pass when it opens
            NavigationLink(destination: SummaryReaderView(book: viewModel.book, summary: summary)) {
                readLabel(title: label.title, icon: label.icon, state: state)
            }
            .buttonStyle(.plain)
            .animation(reduceMotion ? nil : .snappy, value: state)
            .accessibilityValue(readingAccessibilityValue(state))
        }
    }

    private func readLabel(title: String, icon: String, state: ReadingState) -> some View {
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

        SourcesSection(citations: summary.displayCitations)
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
            // Saving needs an account; the book is saved as soon as they have one
            signInPrompt = SignInPrompt(reason: .save(viewModel.book)) {
                Task { await viewModel.saveAfterSignIn() }
            }
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

/// "Sources": what the summary draws on, quiet and last on the page. Hidden when there are none.
private struct SourcesSection: View {
    let citations: [Citation]

    var body: some View {
        if !citations.isEmpty {
            DetailSection(title: "Sources") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(citations, id: \.self) { citation in
                        if let link = citation.link {
                            Link(destination: link) {
                                Text("\(citation.source) \(Image(systemName: "arrow.up.right"))")
                            }
                            .foregroundStyle(.primary)
                        } else {
                            Text(citation.source)
                        }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
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
