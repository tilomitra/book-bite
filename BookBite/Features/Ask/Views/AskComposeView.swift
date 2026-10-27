import SwiftUI

/// Writing a question. Books that look like they answer it rise in under the text as it is typed.
struct AskComposeView: View {
    let suggestions: [String]
    let onAsk: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var matches: [Book] = []
    @FocusState private var focused: Bool

    private let provider = DependencyContainer.shared.bookRepository as? AskProviding

    private var question: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canAsk: Bool { question.count >= 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .askGlass(in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                Spacer()
                AskSendButton(size: 44, enabled: canAsk, action: ask)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            TextField("What’s on your mind?", text: $text, axis: .vertical)
                .font(.system(size: 30, design: .serif))
                .tracking(-0.4)
                .lineLimit(1...7)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit(ask)
                .padding(.horizontal, 24)
                .padding(.top, 26)

            if !matches.isEmpty {
                HStack(spacing: 12) {
                    CoverStack(books: matches, width: 30)
                    Text(matches.map(\.shelfTitle).joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Matching books: \(matches.map(\.title).joined(separator: ", "))")
            }

            if question.isEmpty && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            text = suggestion
                            ask()
                        } label: {
                            Text(suggestion)
                                .font(.system(size: 18, design: .serif))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
            }

            Spacer(minLength: 0)
        }
        .background(Color.paper)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: matches.map(\.id))
        .onAppear { focused = true }
        .task(id: question) { await updateMatches() }
    }

    private func ask() {
        guard canAsk else { return }
        onAsk(question)
    }

    /// Waits for a pause in typing, then looks up books for what's written so far
    private func updateMatches() async {
        guard question.count >= 12, let provider else {
            if question.count < 12 { matches = [] }
            return
        }
        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }
        if let books = try? await provider.fetchAskMatches(for: question), !Task.isCancelled {
            matches = books
        }
    }
}
