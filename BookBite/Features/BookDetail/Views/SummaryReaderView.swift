import SwiftUI

/// The full summary as a book page: chapters, set type, reading themes, and a quiet record of where
/// the reader is. Chrome is the navigation bar only (current chapter and time left) with a hairline
/// of progress under it; the tab bar is hidden while reading.
struct SummaryReaderView: View {
    let book: Book
    let summary: Summary

    @AppStorage("readerTheme") private var theme: ReaderTheme = .paper
    @AppStorage("readerTypeface") private var typeface: ReaderTypeface = .serif
    @AppStorage("readerTextSize") private var textSize: Double = ReaderTextSize.standard

    /// Scales the chosen size with Dynamic Type, so the text reflows at every system size
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Parsed on appear rather than in init: BookDetailView builds this view eagerly for its link
    @State private var document: ReaderDocument?
    @State private var position = ScrollPosition(idType: Int.self)

    @State private var fraction: Double = 0
    @State private var currentChapter = 0
    /// Where to resume, applied once the content has been laid out
    @State private var pendingRestore: Double?
    /// Scrollable distance from the last layout, for keeping the place when the text reflows
    @State private var scrollRange: CGFloat = 0
    /// True while the text reflows after a size or typeface change; scroll events are ignored then
    @State private var isReflowing = false
    /// Progress is recorded only after any restore, and only once the reader has actually scrolled
    @State private var isRestored = false
    @State private var startFraction: Double = 0
    @State private var hasScrolled = false
    @State private var lastSaved = Date.distantPast
    @State private var isFinished = false
    @State private var showsSettings = false
    @State private var chapterJumps = 0
    /// Wide layout only: the contents column on the left and "Ask the book" on the right
    @State private var showsContents = true
    @State private var showsAsk = false

    /// iPad and other wide windows: room for the contents beside the text, and to ask about it without leaving
    private var isWide: Bool { horizontalSizeClass == .regular }

    private static let headerID = -1
    private static let endID = Int.max

    private var style: ReaderStyle {
        ReaderStyle(theme: theme,
                    typeface: typeface,
                    size: CGFloat(textSize) * typeScale * typeface.sizeAdjustment)
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if let document, !document.isEmpty {
                if isWide && showsContents && document.titledChapters.count > 1 {
                    HStack(spacing: 0) {
                        contentsColumn(document)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        reader(document)
                    }
                } else {
                    reader(document)
                }
            } else if document != nil {
                Text("This summary isn't available yet.")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(theme.secondaryInk)
                    .padding()
            }
        }
        .environment(\.colorScheme, theme.colorScheme ?? systemColorScheme)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
        .toolbar { toolbarContent }
        // Off on iPhone, where the reader keeps only its text (showsAsk is only set in wide layout).
        // A plain binding: one built in `body` is a new value on every pass and loops the layout
        .inspector(isPresented: $showsAsk) {
            BookChatView(book: book)
                .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
        }
        .tint(theme.ink)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: theme)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: isFinished) { _, finished in finished }
        .sensoryFeedback(.selection, trigger: chapterJumps)
        .onAppear(perform: load)
        .onDisappear { record(force: true) }
        .onChange(of: horizontalSizeClass) { _, sizeClass in
            if sizeClass != .regular { showsAsk = false }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { record(force: true) }
        }
    }

    // MARK: - Reader

    private func reader(_ document: ReaderDocument) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ReaderHeader(book: book, minutes: summary.summaryReadTimeMinutes, style: style)
                    .id(Self.headerID)

                ForEach(document.chapters) { chapter in
                    ReaderChapterView(chapter: chapter, isOpening: chapter.id == 0, style: style)
                        .id(chapter.id)
                }

                ReaderEndSection(book: book, isFinished: isFinished, style: style) {
                    dismiss()
                }
                .id(Self.endID)
            }
            .scrollTargetLayout()
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition($position)
        .scrollIndicators(.hidden)
        .onScrollTargetVisibilityChange(idType: Int.self, threshold: 0.01) { ids in
            updateCurrentChapter(visible: ids, in: document)
        }
        .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
            ScrollMetrics(
                offset: geometry.contentOffset.y + geometry.contentInsets.top,
                range: geometry.contentSize.height + geometry.contentInsets.top
                    + geometry.contentInsets.bottom - geometry.containerSize.height)
        } action: { _, metrics in
            scrolled(to: metrics)
        }
        .overlay(alignment: .top) {
            ProgressHairline(fraction: fraction, theme: theme)
        }
        .onChange(of: textSize) { keepPlace() }
        .onChange(of: typeface) { keepPlace() }
        .onChange(of: typeScale) { keepPlace() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if let document {
                VStack(spacing: 1) {
                    Text(currentTitle(in: document))
                        .font(.system(.footnote, design: .serif).weight(.semibold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                        .id(currentTitle(in: document))
                        .transition(.opacity)
                    Text(timeLeft(in: document))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(theme.secondaryInk)
                        .contentTransition(.numericText(countsDown: true))
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: currentChapter)
                .animation(reduceMotion ? nil : .default, value: timeLeft(in: document))
                .accessibilityElement(children: .combine)
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            if let document, document.titledChapters.count > 1 {
                if isWide {
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy) { showsContents.toggle() }
                    } label: {
                        Image(systemName: "sidebar.leading")
                    }
                    .accessibilityLabel(showsContents ? "Hide contents" : "Show contents")
                } else {
                    contentsMenu(document)
                }
            }

            if isWide {
                Button {
                    showsAsk.toggle()
                } label: {
                    Image(systemName: showsAsk ? "bubble.left.fill" : "bubble.left")
                }
                .accessibilityLabel(showsAsk ? "Hide Ask the book" : "Ask the book")
            }

            Button {
                showsSettings = true
            } label: {
                Image(systemName: "textformat.size")
            }
            .accessibilityLabel("Reading settings")
            .popover(isPresented: $showsSettings, arrowEdge: .top) {
                ReaderSettingsPanel(systemColorScheme: systemColorScheme)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    private func contentsMenu(_ document: ReaderDocument) -> some View {
        Menu {
            Section("Contents") {
                Button("Beginning") { jump(to: Self.headerID) }

                ForEach(document.titledChapters) { chapter in
                    Button {
                        jump(to: chapter.id)
                    } label: {
                        if chapter.id == currentChapter {
                            Label(chapter.title ?? "", systemImage: "checkmark")
                        } else {
                            Text(chapter.title ?? "")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "list.bullet")
        }
        .accessibilityLabel("Contents")
    }

    /// The chapters as a column beside the text (wide layout); the current one is marked
    private func contentsColumn(_ document: ReaderDocument) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text("Contents")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.secondaryInk)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .accessibilityAddTraits(.isHeader)

                contentsRow("Beginning", isCurrent: false) { jump(to: Self.headerID) }

                ForEach(document.titledChapters) { chapter in
                    contentsRow(chapter.title ?? "", isCurrent: chapter.id == currentChapter) {
                        jump(to: chapter.id)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
        .frame(width: 260)
        .overlay(alignment: .trailing) {
            Rectangle().fill(theme.rule).frame(width: 0.5)
        }
    }

    private func contentsRow(_ title: String, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .serif).weight(isCurrent ? .semibold : .regular))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isCurrent ? theme.rule.opacity(0.6) : .clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isCurrent)
    }

    private func currentTitle(in document: ReaderDocument) -> String {
        guard document.chapters.indices.contains(currentChapter),
              let title = document.chapters[currentChapter].title else {
            return book.shelfTitle
        }
        return title
    }

    private func timeLeft(in document: ReaderDocument) -> String {
        if isFinished && fraction > 0.98 { return "Finished" }
        let minutes = document.minutesLeft(at: fraction)
        return minutes == 0 ? "Finished" : "\(minutes) min left"
    }

    // MARK: - Position

    private func load() {
        guard document == nil else { return }
        document = ReaderDocument(markdown: summary.extendedSummary ?? "")
            .hyphenated(locale: Locale(identifier: "en_US"))

        let entry = ReadingProgressStore.shared.entry(for: book.id)
        if let entry, !entry.isFinished, entry.fraction >= 0.03, entry.fraction < 0.97 {
            // Resume where they left off
            startFraction = entry.fraction
            fraction = entry.fraction
            currentChapter = entry.chapterIndex
            pendingRestore = entry.fraction
        } else {
            isRestored = true
        }
    }

    private func scrolled(to metrics: ScrollMetrics) {
        if metrics.range != scrollRange { scrollRange = metrics.range }
        guard metrics.range > 0, !isReflowing else { return }

        if let pending = pendingRestore {
            pendingRestore = nil
            position.scrollTo(y: pending * metrics.range)
            fraction = pending
            isRestored = true
            return
        }

        fraction = min(max(metrics.offset / metrics.range, 0), 1)

        guard isRestored else { return }
        if !hasScrolled, abs(fraction - startFraction) > 0.005 {
            hasScrolled = true
        }
        guard hasScrolled else { return }

        // Reaching the end section finishes the book
        if !isFinished, metrics.range - metrics.offset < 80 {
            isFinished = true
            ReadingProgressStore.shared.markFinished(book)
            return
        }
        record()
    }

    /// Keeps the reading position when the text reflows (size, typeface, Dynamic Type)
    private func keepPlace() {
        guard isRestored, pendingRestore == nil, fraction > 0, !isReflowing else { return }
        let target = fraction
        isReflowing = true
        Task { @MainActor in
            // Let the new layout land, then return to the same place in the text
            try? await Task.sleep(for: .milliseconds(60))
            position.scrollTo(y: target * scrollRange)
            fraction = target
            isReflowing = false
        }
    }

    private func updateCurrentChapter(visible ids: [Int], in document: ReaderDocument) {
        let chapterIDs = ids.filter { document.chapters.indices.contains($0) }
        if let first = chapterIDs.min() {
            currentChapter = first
        } else if ids.contains(Self.headerID) {
            currentChapter = 0
        } else if ids.contains(Self.endID) {
            currentChapter = max(document.chapters.count - 1, 0)
        }
    }

    private func jump(to id: Int) {
        chapterJumps += 1
        // A long animated scroll through the text is disorienting; jump like a book's contents page
        position.scrollTo(id: id, anchor: .top)
    }

    /// Saves the position at most every 2 seconds while scrolling, and always when leaving
    private func record(force: Bool = false) {
        guard isRestored, hasScrolled, !isReflowing else { return }
        let now = Date()
        guard force || now.timeIntervalSince(lastSaved) > 2 else { return }
        lastSaved = now
        ReadingProgressStore.shared.update(book, fraction: fraction, chapterIndex: currentChapter,
                                           totalMinutes: summary.summaryReadTimeMinutes)
    }
}

private struct ScrollMetrics: Equatable {
    /// Distance scrolled from the top, 0...range
    let offset: CGFloat
    /// Total scrollable distance
    let range: CGFloat
}

/// A hairline under the navigation bar that fills as you read
private struct ProgressHairline: View {
    let fraction: Double
    let theme: ReaderTheme

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(theme.ink.opacity(0.55))
                .frame(width: proxy.size.width * fraction)
        }
        .frame(height: 1.5)
        .background(theme.rule.opacity(0.5))
        .accessibilityHidden(true)
    }
}
