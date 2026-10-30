import Foundation

/// How many books a reader can open in full. Everyone gets 5; an invite adds 5 to both sides (see
/// `server/src/services/readingPass.ts`). Signed in, the server holds it; as a guest it lives on device.
struct ReadingPass: Codable, Equatable {
    static let freeBooks = 5
    static let booksPerInvite = 5

    var limit: Int
    /// In the order they were opened. Lower-cased ids, so the server's and the app's spellings match.
    var unlockedBookIds: [String]
    /// Signed in only
    var invite: Invite?

    struct Invite: Codable, Equatable {
        let code: String
        let url: URL
        let friendsJoined: Int
        let maxFriends: Int
        /// This account joined with a friend's code (and got 5 books for it)
        let joinedWithCode: Bool
        /// A new account that hasn't used a code yet
        let canJoinWithCode: Bool
    }

    static let guest = ReadingPass(limit: freeBooks, unlockedBookIds: [], invite: nil)

    init(limit: Int, unlockedBookIds: [String], invite: Invite?) {
        self.limit = limit
        self.unlockedBookIds = unlockedBookIds.map { $0.lowercased() }
        self.invite = invite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            limit: try container.decodeIfPresent(Int.self, forKey: .limit) ?? Self.freeBooks,
            unlockedBookIds: try container.decodeIfPresent([String].self, forKey: .unlockedBookIds) ?? [],
            invite: try container.decodeIfPresent(Invite.self, forKey: .invite)
        )
    }

    var used: Int { unlockedBookIds.count }
    var remaining: Int { max(0, limit - used) }

    /// Books earned from friends who joined with this account's code
    var booksFromFriends: Int {
        guard let invite else { return 0 }
        return min(invite.friendsJoined, invite.maxFriends) * Self.booksPerInvite
    }

    func isUnlocked(_ bookId: String) -> Bool {
        unlockedBookIds.contains(bookId.lowercased())
    }

    /// Uses a free book on `bookId` if it isn't unlocked yet. False when none are left.
    mutating func unlock(_ bookId: String) -> Bool {
        if isUnlocked(bookId) { return true }
        guard remaining > 0 else { return false }
        unlockedBookIds.append(bookId.lowercased())
        return true
    }

    /// Upper-cases and drops spaces and dashes; nil if it can't be a code. Same rule as the server.
    static func normalizeCode(_ input: String) -> String? {
        var code = input.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        if code.hasPrefix("BOOKBITE") { code.removeFirst("BOOKBITE".count) }
        let allowed = Set("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        guard code.count == 6, code.allSatisfy(allowed.contains) else { return nil }
        return code
    }

    /// The code in `bookbite://invite/<code>` links
    static func code(fromInviteLink url: URL) -> String? {
        guard url.scheme == "bookbite", url.host == "invite", url.pathComponents.count > 1 else { return nil }
        return normalizeCode(url.pathComponents[1])
    }
}

/// What opening a book in full means for this reader right now
enum ReadingAccess: Equatable {
    /// Subscriber
    case unlimited
    /// Opened before (or read before the pass existed): free to open again
    case unlocked
    /// Opening it uses one of `remaining` free books
    case free(remaining: Int)
    /// No books left
    case locked
}

// MARK: - Shelf

extension ReadingPass {
    /// One row of the pass shelf: five places, filled in the order books were opened
    struct ShelfRow: Identifiable, Equatable {
        let id: Int
        let title: String
        /// Book id per place; nil = still free
        let bookIds: [String?]

        var isFull: Bool { !bookIds.contains(nil) }
    }

    /// The free row, a row for joining with a friend's code, a row per friend who joined with this
    /// code, and a row for any books opened beyond the limit (a friend deleted their account)
    var shelfRows: [ShelfRow] {
        var titles = ["Free"]
        if invite?.joinedWithCode == true { titles.append("For joining") }
        let friends = invite.map { min($0.friendsJoined, $0.maxFriends) } ?? 0
        titles += (0..<friends).map { friends == 1 ? "From a friend" : "Friend \($0 + 1)" }

        var rows: [ShelfRow] = []
        var remainingIds = unlockedBookIds[...]
        for (index, title) in titles.enumerated() {
            let size = index == 0 ? max(0, limit - (titles.count - 1) * Self.booksPerInvite) : Self.booksPerInvite
            let ids = remainingIds.prefix(size)
            remainingIds = remainingIds.dropFirst(ids.count)
            let filled: [String?] = ids.map { $0 }
            rows.append(ShelfRow(id: index, title: title,
                                 bookIds: filled + [String?](repeating: nil, count: size - ids.count)))
        }
        if !remainingIds.isEmpty {
            let extra: [String?] = remainingIds.map { $0 }
            rows.append(ShelfRow(id: rows.count, title: "Earlier", bookIds: extra))
        }
        return rows
    }

    /// The row being filled now (the first with a free place), else the last
    var currentShelfRow: ShelfRow? {
        let rows = shelfRows
        return rows.first { !$0.isFull } ?? rows.last
    }
}

// MARK: - Invite message

enum InviteMessage {
    /// What goes in the share sheet with the invite link. With `book`, it comes from finishing that book.
    static func text(code: String, url: URL, book: Book? = nil) -> String {
        let opener: String
        if let book {
            opener = "I just finished “\(book.shelfTitle)” on BookBite and thought of you."
        } else {
            opener = "I've been reading the key ideas of great non-fiction on BookBite."
        }
        return "\(opener) Here are 5 free books to start, on me: \(url.absoluteString) (code \(code))"
    }
}
