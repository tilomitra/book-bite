import Foundation

/// The user's kept ideas, arranged for the Notebook.
enum Notebook {
    typealias Idea = SavedIdeasStore.SavedIdea

    enum Arrangement: String, CaseIterable, Identifiable {
        case byBook
        case newest

        var id: String { rawValue }

        var title: String {
            switch self {
            case .byBook: return "By book"
            case .newest: return "Newest first"
            }
        }
    }

    struct Group: Identifiable, Equatable {
        let book: Book
        let ideas: [Idea]

        var id: String { book.id }
    }

    /// One group per book, the book with the most recently kept idea first; ideas newest first within a book.
    static func groupedByBook(_ ideas: [Idea]) -> [Group] {
        let sorted = newestFirst(ideas)
        var order: [String] = []
        var byBook: [String: [Idea]] = [:]
        for idea in sorted {
            if byBook[idea.book.id] == nil { order.append(idea.book.id) }
            byBook[idea.book.id, default: []].append(idea)
        }
        return order.compactMap { id in
            guard let ideas = byBook[id], let book = ideas.first?.book else { return nil }
            return Group(book: book, ideas: ideas)
        }
    }

    static func newestFirst(_ ideas: [Idea]) -> [Idea] {
        ideas.sorted { $0.savedAt > $1.savedAt }
    }

    /// Plain text for the share sheet: the idea in quotes, then the book.
    static func shareText(for idea: Idea) -> String {
        var credit = idea.book.shelfTitle
        if !idea.book.shelfAuthor.isEmpty {
            credit += " by \(idea.book.shelfAuthor)"
        }
        return "“\(idea.text)”\n\n— \(credit)"
    }
}

/// Quiet facts about finished summaries. No streaks, no targets.
enum FinishedStats {
    /// Summaries finished in the calendar year of `now`.
    static func finishedThisYear(_ entries: [ReadingProgressStore.Entry], now: Date = .now, calendar: Calendar = .current) -> Int {
        let year = calendar.component(.year, from: now)
        return entries.filter { entry in
            guard let finishedAt = entry.finishedAt else { return false }
            return calendar.component(.year, from: finishedAt) == year
        }.count
    }

    /// "12 finished this year", or nil when none were finished this year.
    static func caption(_ entries: [ReadingProgressStore.Entry], now: Date = .now, calendar: Calendar = .current) -> String? {
        let count = finishedThisYear(entries, now: now, calendar: calendar)
        return count > 0 ? "\(count) finished this year" : nil
    }
}
