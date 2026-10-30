import SwiftUI
import UIKit

/// A conversation like a chat: each question on the right, the answer written in under it, follow-ups below.
struct AskConversationView: View {
    @StateObject private var viewModel: AskConversationViewModel
    @FocusState private var inputFocused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Wide layout only: the cited books in a column beside the answer
    @State private var showsSources = true
    @State private var signInPrompt: SignInPrompt?
    @EnvironmentObject private var authService: SupabaseAuthService

    private var isWide: Bool { horizontalSizeClass == .regular }

    init(route: AskRoute) {
        _viewModel = StateObject(wrappedValue: AskConversationViewModel(
            question: route.question,
            conversation: route.conversation,
            bookRepository: DependencyContainer.shared.bookRepository
        ))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 36) {
                    ForEach(viewModel.conversation.turns) { turn in
                        AskTurnView(
                            turn: turn,
                            isStreaming: viewModel.streamingTurnId == turn.id,
                            failed: viewModel.failedTurnId == turn.id,
                            retry: viewModel.retry
                        )
                        .id(turn.id)
                    }
                }
                .padding(.horizontal, isWide ? 40 : 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
                // A readable line length beside the sources column
                .frame(maxWidth: isWide ? 720 : CGFloat.infinity)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.conversation.turns.count) { _, _ in
                guard let last = viewModel.conversation.turns.last else { return }
                // After the new turn is laid out, or the lazy stack scrolls to a stale position
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(80))
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(last.id, anchor: .top) }
                }
            }
        }
        .background(Color.paper)
        .safeAreaInset(edge: .bottom) { followUpBar }
        .navigationTitle(shortTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if isWide {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSources.toggle()
                    } label: {
                        Image(systemName: "sidebar.trailing")
                    }
                    .accessibilityLabel(showsSources ? "Hide sources" : "Show sources")
                }
            }
        }
        // Off on iPhone, where the chips under each point open the books
        .inspector(isPresented: Binding(get: { isWide && showsSources }, set: { showsSources = $0 })) {
            AskSourcesPanel(books: viewModel.conversation.turns.last?.sources ?? [])
                .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
        }
        .signInPrompt($signInPrompt)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    /// The first question, cut to a few words for the navigation bar
    private var shortTitle: String {
        let words = viewModel.conversation.title.split(separator: " ")
        return words.count > 5 ? words.prefix(5).joined(separator: " ") + "…" : words.joined(separator: " ")
    }

    /// A conversation from history can be open after signing out, so follow-ups ask for sign-in too
    private func sendFollowUp() {
        guard viewModel.canSend else { return }
        let question = viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines)
        let books = viewModel.conversation.turns.last?.sources ?? []
        signInPrompt = SignInPrompt.gate(.ask(question: question, books: books), auth: authService) {
            viewModel.sendInput()
        }
    }

    private var followUpBar: some View {
        HStack(spacing: 10) {
            TextField("Ask a follow-up", text: $viewModel.input, axis: .vertical)
                .font(.body)
                .lineLimit(1...4)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit(sendFollowUp)
                .padding(.leading, 20)
                .padding(.vertical, 15)
            if viewModel.isStreaming {
                Button(action: viewModel.stop) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.paper)
                        .frame(width: 13, height: 13)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.primary))
                }
                .accessibilityLabel("Stop")
                .padding(.trailing, 7)
            } else {
                AskSendButton(enabled: viewModel.canSend, action: sendFollowUp)
                    .padding(.trailing, 7)
            }
        }
        .frame(minHeight: 54)
        .askGlass(in: RoundedRectangle(cornerRadius: 27, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// The books behind the latest answer, numbered as the answer cites them. Tapping one opens it.
private struct AskSourcesPanel: View {
    let books: [Book]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Sources")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                if books.isEmpty {
                    Text("The books behind the answer show here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                    NavigationLink(value: BookRoute(book: book)) {
                        HStack(alignment: .top, spacing: 14) {
                            EditorialCover(book: book, width: 60)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(index + 1)")
                                    .font(.footnote.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text(book.shelfTitle)
                                    .font(.system(size: 18, weight: .medium, design: .serif))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(book.shelfAuthor)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Source \(index + 1), \(book.title)")
                    .accessibilityHint("Opens the book")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.paper.ignoresSafeArea())
        .animation(.default, value: books.map(\.id))
    }
}

/// One question and its answer
private struct AskTurnView: View {
    let turn: AskTurn
    let isStreaming: Bool
    let failed: Bool
    let retry: () -> Void

    private var answer: AskAnswer { AskAnswer(parsing: turn.answer, streaming: isStreaming) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(turn.question)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.primary.opacity(0.065)))
                .frame(maxWidth: 300, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if failed {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Couldn’t answer that right now.")
                        .font(.system(size: 18, design: .serif))
                        .foregroundStyle(.secondary)
                    Button("Try again", action: retry)
                        .font(.subheadline.weight(.semibold))
                }
            } else {
                SourcesLine(books: turn.sources, reading: isStreaming && answer.isEmpty)
                if !answer.isEmpty {
                    AskAnswerView(answer: answer, sources: turn.sources, isStreaming: isStreaming)
                }
                if !isStreaming && !turn.answer.isEmpty {
                    AnswerActions(turn: turn, answer: answer)
                }
            }
        }
    }
}

/// "Reading 4 books" while the answer is being prepared, "Read 4 books" after
private struct SourcesLine: View {
    let books: [Book]
    let reading: Bool
    @State private var pulse = false

    private var label: String {
        if books.isEmpty { return "Reading the library" }
        let count = books.count == 1 ? "1 book" : "\(books.count) books"
        return reading ? "Reading \(count)" : "Read \(count)"
    }

    var body: some View {
        HStack(spacing: 10) {
            if !books.isEmpty {
                CoverStack(books: books)
            }
            Text(label)
                .font(.subheadline.weight(reading ? .medium : .regular))
                .foregroundStyle(.secondary)
                .opacity(reading && pulse ? 0.35 : 1)
        }
        .frame(height: 28)
        .onAppear { pulse = true }
        .animation(reading ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default, value: pulse)
        .accessibilityElement(children: .combine)
    }
}

/// Share and copy, under a finished answer
private struct AnswerActions: View {
    let turn: AskTurn
    let answer: AskAnswer
    @State private var copied = false

    var body: some View {
        HStack(spacing: 4) {
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Share")
            Button {
                UIPasteboard.general.string = shareText
                copied = true
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .frame(width: 36, height: 36)
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(copied ? "Copied" : "Copy")
            .sensoryFeedback(.success, trigger: copied) { _, new in new }
        }
        .font(.system(size: 15))
        .foregroundStyle(.secondary)
        .padding(.leading, -8)
        .padding(.top, -12)
    }

    private var shareText: String {
        AskShareText.make(question: turn.question, answer: answer, sources: turn.sources)
    }
}

/// Plain text of an answer for the share sheet and the clipboard
enum AskShareText {
    static func make(question: String, answer: AskAnswer, sources: [Book]) -> String {
        var parts = [question, answer.lead]
        parts += answer.paragraphs
        for point in answer.points {
            let books = point.sources.compactMap { sources[safe: $0 - 1]?.title }
            let cite = books.isEmpty ? "" : " (\(books.joined(separator: ", ")))"
            parts.append("• \(point.lead.isEmpty ? "" : point.lead + " ")\(point.body)\(cite)")
        }
        if let week = answer.thisWeek { parts.append("This week: \(week)") }
        if let other = answer.otherSide { parts.append(other) }
        parts.append("From BookBite")
        return parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
