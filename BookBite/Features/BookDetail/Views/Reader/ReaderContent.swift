import SwiftUI

/// Type settings shared by the reader's pieces, derived once per render from the user's choices
/// and the Dynamic Type size.
struct ReaderStyle {
    let theme: ReaderTheme
    let typeface: ReaderTypeface
    /// Body size in points, already scaled for Dynamic Type
    let size: CGFloat

    var body: Font { .system(size: size, design: typeface.design) }
    /// ~1.6 leading: comfortable for long reading without the lines drifting apart
    var lineSpacing: CGFloat { size * 0.42 }
    var paragraphSpacing: CGFloat { size * 0.9 }
    var chapterTitle: Font { .system(size: size * 1.4, weight: .medium, design: typeface.design) }
    var bookTitle: Font { .system(size: size * 1.75, weight: .medium, design: .serif) }
    var caption: Font { .system(size: max(11, size * 0.62), weight: .semibold) }
}

// MARK: - Header

struct ReaderHeader: View {
    let book: Book
    let minutes: Int
    let style: ReaderStyle

    var body: some View {
        VStack(alignment: .leading, spacing: style.size * 0.5) {
            Text("Summary · \(minutes) min read")
                .font(style.caption)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(style.theme.secondaryInk)

            Text(book.title)
                .font(style.bookTitle)
                .tracking(-0.4)
                .foregroundStyle(style.theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHeading(.h1)

            if !book.authors.isEmpty {
                Text(book.formattedAuthors)
                    .font(.system(size: style.size * 0.95, design: .serif).italic())
                    .foregroundStyle(style.theme.secondaryInk)
            }

            ReaderRule(theme: style.theme)
                .padding(.top, style.size * 1.2)
        }
        .padding(.top, style.size * 1.4)
        .padding(.bottom, style.size * 1.6)
        .accessibilityElement(children: .contain)
    }
}

/// A short hairline: the reader's only ornament
struct ReaderRule: View {
    let theme: ReaderTheme
    var width: CGFloat = 36

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(theme.rule)
            .frame(width: width, height: max(1 / displayScale, 0.5))
            .accessibilityHidden(true)
    }
}

// MARK: - Chapter

struct ReaderChapterView: View {
    let chapter: ReaderDocument.Chapter
    /// The first chapter opens the summary with a raised initial
    let isOpening: Bool
    let style: ReaderStyle

    var body: some View {
        VStack(alignment: .leading, spacing: style.paragraphSpacing) {
            if let title = chapter.title {
                VStack(alignment: .leading, spacing: style.size * 0.9) {
                    if !isOpening {
                        ReaderRule(theme: style.theme)
                    }
                    Text(title)
                        .font(style.chapterTitle)
                        .tracking(-0.2)
                        .foregroundStyle(style.theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityHeading(.h2)
                }
                .padding(.top, isOpening ? 0 : style.size * 1.6)
                .padding(.bottom, style.size * 0.1)
            }

            ForEach(Array(chapter.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                paragraphText(paragraph, isFirst: index == 0)
                    .font(style.body)
                    .lineSpacing(style.lineSpacing)
                    .foregroundStyle(style.theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(.bottom, style.paragraphSpacing)
    }

    /// The first paragraph of a chapter opens with its first words in small caps; the summary's very
    /// first paragraph also gets a raised initial.
    private func paragraphText(_ paragraph: String, isFirst: Bool) -> Text {
        guard isFirst, let lead = ReaderLeadIn(paragraph: paragraph, withInitial: isOpening) else {
            return Text(paragraph)
        }
        let smallCaps = Text(lead.smallCaps).font(style.body.lowercaseSmallCaps()).tracking(style.size * 0.03)
        if let initial = lead.initial {
            let initialText = Text(initial)
                .font(.system(size: style.size * 2.3, weight: .regular, design: style.typeface.design))
            return Text("\(initialText)\(smallCaps)\(lead.rest)")
        }
        return Text("\(smallCaps)\(lead.rest)")
    }
}

/// Splits an opening paragraph into an optional initial, a few small-caps words, and the rest.
struct ReaderLeadIn: Equatable {
    let initial: String?
    let smallCaps: String
    let rest: String

    static let maxWords = 3

    init?(paragraph: String, withInitial: Bool) {
        // The rest keeps its soft hyphens; the small-caps words never break
        let text = paragraph
        // Don't decorate list items or very short lines
        guard !text.hasPrefix("•"), text.count > 24 else { return nil }

        var words: [Substring] = []
        var index = text.startIndex
        while words.count < Self.maxWords, index < text.endIndex {
            let end = text[index...].firstIndex(of: " ") ?? text.endIndex
            let word = text[index..<end]
            words.append(word)
            index = end < text.endIndex ? text.index(after: end) : end
            // Stop at a natural pause
            if let last = word.last, ",.;:!?—".contains(last) { break }
        }
        guard !words.isEmpty, index < text.endIndex else { return nil }

        var lead = words.joined(separator: " ")
            .replacingOccurrences(of: String(Hyphenator.softHyphen), with: "")
        let rest = " " + text[index...]

        if withInitial {
            // Keep an opening quotation mark with its letter
            var initialEnd = lead.startIndex
            while initialEnd < lead.endIndex, "\"“‘'(".contains(lead[initialEnd]) {
                initialEnd = lead.index(after: initialEnd)
            }
            guard initialEnd < lead.endIndex, lead[initialEnd].isLetter || lead[initialEnd].isNumber else {
                self.initial = nil
                self.smallCaps = lead
                self.rest = rest
                return
            }
            initialEnd = lead.index(after: initialEnd)
            self.initial = String(lead[..<initialEnd])
            lead = String(lead[initialEnd...])
        } else {
            self.initial = nil
        }
        self.smallCaps = lead
        self.rest = rest
    }
}

// MARK: - End

/// The close of the summary: a rule, a quiet line of acknowledgement, the full book, a way back.
struct ReaderEndSection: View {
    let book: Book
    let isFinished: Bool
    let style: ReaderStyle
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: style.size * 0.9) {
            ReaderRule(theme: style.theme, width: 48)
                .padding(.bottom, style.size * 0.8)

            FinishedMark(isFinished: isFinished, color: style.theme.ink, size: style.size * 1.9)

            VStack(spacing: style.size * 0.3) {
                Text("You've finished")
                    .font(style.caption)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(style.theme.secondaryInk)

                Text(book.title)
                    .font(.system(size: style.size * 1.3, weight: .medium, design: .serif))
                    .foregroundStyle(style.theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Menu {
                ForEach(BookStore.allCases) { store in
                    Button {
                        if let url = book.purchaseURL(store: store, source: "reader") { openURL(url) }
                    } label: {
                        Text(store.name)
                        Text(store.caption)
                    }
                }
            } label: {
                Text("Get the full book")
                    .font(.system(size: style.size * 0.85, weight: .medium, design: style.typeface.design))
                    .foregroundStyle(style.theme.background)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(style.theme.ink))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, style.size * 0.6)
            .accessibilityHint("Opens a bookstore")

            Button(action: onClose) {
                Text("Back to the book")
                    .font(.system(size: style.size * 0.85, design: style.typeface.design))
                    .foregroundStyle(style.theme.ink)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 44)
                    .overlay(Capsule().strokeBorder(style.theme.rule, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, style.size * 2)
        .padding(.bottom, style.size * 4)
        .opacity(isFinished ? 1 : 0.55)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: isFinished)
    }
}

/// A thin circle that draws itself closed around a check when the summary is finished
private struct FinishedMark: View {
    let isFinished: Bool
    let color: Color
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.12), lineWidth: 1)
            Circle()
                .trim(from: 0, to: isFinished ? 1 : 0)
                .stroke(color.opacity(0.7), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.38, weight: .light))
                .foregroundStyle(color)
                .opacity(isFinished ? 1 : 0)
                .scaleEffect(isFinished || reduceMotion ? 1 : 0.85)
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9), value: isFinished)
        .accessibilityHidden(true)
    }
}
