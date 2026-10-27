import Foundation
import SwiftUI

/// The Ask tab's question of the day and Explore topics.
@MainActor
final class AskHomeViewModel: ObservableObject {
    @Published private(set) var home: AskHome?
    @Published private(set) var didFail = false

    private let provider: AskProviding?

    init(bookRepository: BookRepository) {
        provider = bookRepository as? AskProviding
    }

    /// Starter questions for the compose screen when it isn't opened from a topic
    var suggestions: [String] {
        guard let home else { return [] }
        return Array(home.topics.prefix(3).compactMap(\.questions.first))
    }

    func load() async {
        guard let provider, home == nil else { return }
        do {
            home = try await provider.fetchAskHome(date: Self.localDate())
            didFail = false
        } catch {
            print("Failed to load Ask home: \(error)")
            didFail = true
        }
    }

    /// The user's local day, so the question changes at their midnight
    static func localDate(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// One Ask conversation: sends questions, streams answers into the newest turn and saves the conversation.
@MainActor
final class AskConversationViewModel: ObservableObject {
    @Published private(set) var conversation: AskConversation
    /// The turn whose answer is being written
    @Published private(set) var streamingTurnId: UUID?
    /// The turn whose answer failed; it shows a retry button
    @Published private(set) var failedTurnId: UUID?
    @Published var input = ""

    private let provider: AskProviding?
    private let store: AskHistoryStore
    private var pendingQuestion: String?
    private var task: Task<Void, Never>?

    /// The server keeps answers short; a few earlier turns are enough context for a follow-up
    static let historyTurns = 4

    init(question: String? = nil, conversation: AskConversation? = nil,
         bookRepository: BookRepository, store: AskHistoryStore = .shared) {
        self.conversation = conversation ?? AskConversation()
        self.pendingQuestion = question
        self.provider = bookRepository as? AskProviding
        self.store = store
    }

    var isStreaming: Bool { streamingTurnId != nil }

    var canSend: Bool {
        !isStreaming && input.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    /// Asks the question the view was opened with, once
    func start() {
        guard let question = pendingQuestion else { return }
        pendingQuestion = nil
        send(question)
    }

    func sendInput() {
        guard canSend else { return }
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        input = ""
        send(question)
    }

    func send(_ question: String) {
        guard !isStreaming else { return }
        if let failed = failedTurnId {
            conversation.turns.removeAll { $0.id == failed }
            failedTurnId = nil
        }
        let turn = AskTurn(question: question)
        conversation.turns.append(turn)
        stream(into: turn.id)
    }

    func retry() {
        guard let failed = failedTurnId, let turn = conversation.turns.first(where: { $0.id == failed }) else { return }
        failedTurnId = nil
        conversation.turns.removeAll { $0.id == failed }
        send(turn.question)
    }

    /// Stops writing; what was written so far stays
    func stop() {
        task?.cancel()
    }

    private func stream(into turnId: UUID) {
        guard let provider else {
            failedTurnId = turnId
            return
        }
        let history = conversation.turns
            .filter { $0.id != turnId && !$0.answer.isEmpty }
            .suffix(Self.historyTurns)
            .map { AskRequest.Turn(question: $0.question, answer: $0.answer) }
        let question = conversation.turns.first { $0.id == turnId }?.question ?? ""
        let request = AskRequest(question: question, history: Array(history))

        streamingTurnId = turnId
        task = Task { [weak self] in
            do {
                for try await event in provider.ask(request) {
                    guard let self else { return }
                    self.update(turnId) { turn in
                        switch event {
                        case .sources(let books): turn.sources = books
                        case .delta(let text): turn.answer += text
                        }
                    }
                }
            } catch is CancellationError {
            } catch {
                print("Ask failed: \(error)")
                guard let self else { return }
                if Task.isCancelled == false,
                   self.conversation.turns.first(where: { $0.id == turnId })?.answer.isEmpty ?? true {
                    self.failedTurnId = turnId
                }
            }
            guard let self else { return }
            self.streamingTurnId = nil
            self.store.save(self.conversation)
        }
    }

    private func update(_ turnId: UUID, _ change: (inout AskTurn) -> Void) {
        guard let index = conversation.turns.firstIndex(where: { $0.id == turnId }) else { return }
        change(&conversation.turns[index])
    }
}
