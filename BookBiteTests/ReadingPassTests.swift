import Combine
import Foundation
import Testing
@testable import BookBite

/// A server that keeps one account's pass in memory
private final class FakePassServer: ReadingPassProviding {
    var limit = 5
    var unlocked: [String] = []
    var friendsJoined = 0
    var joinedWithCode = false
    var isOffline = false
    var unlockRequests: [[String]] = []

    private var pass: ReadingPass {
        ReadingPass(limit: limit, unlockedBookIds: unlocked, invite: .init(
            code: "K7QM2P", url: URL(string: "https://book-bite.onrender.com/invite/K7QM2P")!,
            friendsJoined: friendsJoined, maxFriends: 20,
            joinedWithCode: joinedWithCode, canJoinWithCode: !joinedWithCode))
    }

    func fetchReadingPass() async throws -> ReadingPass {
        if isOffline { throw URLError(.notConnectedToInternet) }
        return pass
    }

    func unlockBooks(_ bookIds: [String]) async throws -> ReadingPass {
        if isOffline { throw URLError(.notConnectedToInternet) }
        unlockRequests.append(bookIds)
        for id in bookIds where !unlocked.contains(id) && unlocked.count < limit {
            unlocked.append(id)
        }
        return pass
    }

    func redeemInviteCode(_ code: String) async throws -> ReadingPass {
        if code == "K7QM2P" { throw ReadingPassError.rejected("That's your own code.") }
        guard !joinedWithCode else { throw ReadingPassError.rejected("Already used a code.") }
        joinedWithCode = true
        limit += 5
        return pass
    }
}

@MainActor
struct ReadingPassTests {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ReadingPassTests-\(UUID().uuidString)")!
    }

    private func makeStore(defaults: UserDefaults, server: FakePassServer? = nil, unlimited: Bool = false,
                           existing: [String] = []) -> ReadingPassStore {
        ReadingPassStore(defaults: defaults, repository: { server }, unlimited: Just(unlimited).eraseToAnyPublisher(),
                         existingProgress: { existing })
    }

    @Test("A guest opens 5 books; opened books stay open and the pass survives a relaunch")
    func testGuestPass() async {
        let defaults = freshDefaults()
        let store = makeStore(defaults: defaults)
        #expect(store.access(for: "b1") == .free(remaining: 5))

        for index in 1...5 {
            #expect(await store.open("b\(index)"))
        }
        #expect(store.access(for: "b6") == .locked)
        #expect(await store.open("b6") == false)
        #expect(await store.open("B3"))
        #expect(store.access(for: "b3") == .unlocked)

        let reloaded = makeStore(defaults: defaults)
        #expect(reloaded.pass.used == 5)
        #expect(reloaded.access(for: "b6") == .locked)
    }

    @Test("Books started before the pass existed stay open without using free books")
    func testGrandfathered() async {
        let defaults = freshDefaults()
        let store = makeStore(defaults: defaults, existing: ["OLD-1"])
        #expect(store.access(for: "old-1") == .unlocked)
        #expect(await store.open("old-1"))
        #expect(store.pass.remaining == 5)

        // Only the first launch with the pass counts: later progress isn't free
        let reloaded = makeStore(defaults: defaults, existing: ["old-1", "new-1"])
        #expect(reloaded.access(for: "new-1") == .free(remaining: 5))
    }

    @Test("Subscribers can open everything")
    func testUnlimited() async {
        let store = makeStore(defaults: freshDefaults(), unlimited: true)
        #expect(store.access(for: "b1") == .unlimited)
        #expect(await store.open("b1"))
        #expect(store.pass.used == 0)
    }

    @Test("Signing in moves guest books to the account")
    func testSignInSyncsGuestBooks() async {
        let server = FakePassServer()
        let store = makeStore(defaults: freshDefaults(), server: server)
        #expect(await store.open("b1"))
        #expect(await store.open("b2"))

        await store.setUser("user-1")
        #expect(server.unlocked.sorted() == ["b1", "b2"])
        #expect(store.pass.remaining == 3)
        #expect(store.pass.invite?.code == "K7QM2P")

        // Already synced: nothing is sent again
        await store.refresh()
        #expect(server.unlockRequests.count == 1)
    }

    @Test("Offline, a signed-in reader still opens books, and they sync later")
    func testOfflineUnlock() async {
        let server = FakePassServer()
        let store = makeStore(defaults: freshDefaults(), server: server)
        await store.setUser("user-1")

        server.isOffline = true
        #expect(await store.open("b1"))
        #expect(store.access(for: "b1") == .unlocked)

        server.isOffline = false
        await store.refresh()
        #expect(server.unlocked == ["b1"])
    }

    @Test("A friend's code from an invite link is used after sign-in")
    func testPendingInvite() async throws {
        let server = FakePassServer()
        let store = makeStore(defaults: freshDefaults(), server: server)
        store.receiveInvite("ABC234")
        #expect(store.pendingInviteCode == "ABC234")
        #expect(store.isPresentingPass)

        await store.setUser("user-1")
        #expect(store.pendingInviteCode == nil)
        #expect(store.pass.limit == 10)
        #expect(store.pass.invite?.joinedWithCode == true)

        await #expect(throws: ReadingPassError.self) {
            _ = try await store.redeem("XYZ234")
        }
    }

    @Test("Friends who joined since the last look are counted once")
    func testNewFriends() async {
        let server = FakePassServer()
        server.friendsJoined = 2
        let store = makeStore(defaults: freshDefaults(), server: server)
        await store.setUser("user-1")
        #expect(store.newFriends == 0)

        server.friendsJoined = 3
        server.limit = 10
        await store.refresh()
        #expect(store.newFriends == 1)
        store.markFriendsSeen()
        #expect(store.newFriends == 0)
    }

    @Test("Codes are normalized like the server does")
    func testNormalizeCode() {
        #expect(ReadingPass.normalizeCode("k7qm2p") == "K7QM2P")
        #expect(ReadingPass.normalizeCode(" k7 qm-2p ") == "K7QM2P")
        #expect(ReadingPass.normalizeCode("BOOKBITE-K7QM2P") == "K7QM2P")
        #expect(ReadingPass.normalizeCode("K7QM2O") == nil)
        #expect(ReadingPass.normalizeCode("K7QM2") == nil)
        #expect(ReadingPass.code(fromInviteLink: URL(string: "bookbite://invite/k7qm2p")!) == "K7QM2P")
        #expect(ReadingPass.code(fromInviteLink: URL(string: "bookbite://book/k7qm2p")!) == nil)
    }

    @Test("The shelf has a row of five per allowance, filled in order")
    func testShelfRows() {
        let invite = ReadingPass.Invite(code: "K7QM2P", url: URL(string: "https://example.com")!,
                                        friendsJoined: 2, maxFriends: 20, joinedWithCode: true, canJoinWithCode: false)
        let ids = (1...7).map { "b\($0)" }
        let pass = ReadingPass(limit: 20, unlockedBookIds: ids, invite: invite)
        let rows = pass.shelfRows

        #expect(rows.map(\.title) == ["Free", "For joining", "Friend 1", "Friend 2"])
        #expect(rows.allSatisfy { $0.bookIds.count == 5 })
        #expect(rows[0].isFull)
        #expect(rows[1].bookIds == ["b6", "b7", nil, nil, nil])
        #expect(pass.currentShelfRow?.id == 1)
        #expect(pass.booksFromFriends == 10)

        // More books than the limit (a friend deleted their account): they go on an extra row
        let over = ReadingPass(limit: 5, unlockedBookIds: ids, invite: nil)
        #expect(over.shelfRows.map(\.title) == ["Free", "Earlier"])
        #expect(over.shelfRows[1].bookIds == ["b6", "b7"])
    }

    @Test("The server's pass decodes, ids lower-cased")
    func testDecoding() throws {
        let json = """
        {"freeBooks":5,"booksPerInvite":5,"limit":10,"unlockedBookIds":["ABC-1"],
         "invite":{"code":"K7QM2P","url":"https://book-bite.onrender.com/invite/K7QM2P","friendsJoined":1,
                   "maxFriends":20,"joinedWithCode":false,"canJoinWithCode":true}}
        """
        let pass = try NetworkService.makeDecoder().decode(ReadingPass.self, from: Data(json.utf8))
        #expect(pass.limit == 10)
        #expect(pass.isUnlocked("abc-1"))
        #expect(pass.invite?.friendsJoined == 1)
    }

    @Test("The invite message carries the link and the code")
    func testInviteMessage() {
        let url = URL(string: "https://book-bite.onrender.com/invite/K7QM2P")!
        let book = Book(id: "b1", title: "Atomic Habits: An Easy & Proven Way", authors: ["James Clear"])
        let text = InviteMessage.text(code: "K7QM2P", url: url, book: book)
        #expect(text.contains("“Atomic Habits”"))
        #expect(text.contains(url.absoluteString))
        #expect(text.contains("K7QM2P"))
    }
}

struct InviteMilestoneTests {
    @Test("The next milestone and the progress toward it")
    func testMilestones() {
        #expect(InviteMilestone.next(after: 0)?.title == "Reader")
        #expect(InviteMilestone.next(after: 1)?.title == "Bookworm")
        #expect(InviteMilestone.progress(friendsJoined: 2) == 0.5)
        #expect(InviteMilestone.progress(friendsJoined: 0) == 0)
        #expect(InviteMilestone.next(after: 20) == nil)
        #expect(InviteMilestone.progress(friendsJoined: 25) == 1)
        #expect(InviteMilestone.all.last?.friends == 20)
    }

    @Test("Friends' join dates decode, and older servers without them still decode")
    func testFriendDates() throws {
        let json = """
        {"code":"K7QM2P","url":"https://book-bite.onrender.com/invite/K7QM2P","friendsJoined":1,"maxFriends":20,
         "joinedWithCode":false,"canJoinWithCode":true,"friends":[{"joinedAt":"2026-10-30T12:00:00.123+00:00"}]}
        """
        let invite = try NetworkService.makeDecoder().decode(ReadingPass.Invite.self, from: Data(json.utf8))
        #expect(invite.friends?.count == 1)

        let old = json.replacingOccurrences(of: #","friends":[{"joinedAt":"2026-10-30T12:00:00.123+00:00"}]"#, with: "")
        let oldInvite = try NetworkService.makeDecoder().decode(ReadingPass.Invite.self, from: Data(old.utf8))
        #expect(oldInvite.friends == nil)
    }
}
