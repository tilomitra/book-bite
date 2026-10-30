import Combine
import Foundation

enum ReadingPassError: LocalizedError {
    /// The server turned the code down; the message is written for the reader
    case rejected(String)
    case invalidCode
    case signInRequired

    var errorDescription: String? {
        switch self {
        case .rejected(let message): return message
        case .invalidCode: return "Codes are 6 letters and numbers, like K7QM2P."
        case .signInRequired: return "Sign in to use a code."
        }
    }
}

/// The reading pass (see `ReadingPass`): which books the reader can open in full, and their invite code.
/// Signed in, the server is the source of truth and a copy is kept for offline use; as a guest, the pass
/// lives in UserDefaults and its books move to the account at sign-in. Subscribers skip all of it.
@MainActor
final class ReadingPassStore: ObservableObject {
    static let shared = ReadingPassStore()

    @Published private(set) var guestPass: ReadingPass
    /// The signed-in account's pass, nil until the server answers once
    @Published private(set) var accountPass: ReadingPass?
    @Published private(set) var hasUnlimited = false
    /// From a `bookbite://invite/<code>` link; used as soon as the reader is signed in
    @Published private(set) var pendingInviteCode: String?
    /// Friends who joined with the code since the reader last looked at their pass
    @Published private(set) var newFriends = 0
    /// Shows the pass sheet from anywhere (invite links, Library)
    @Published var isPresentingPass = false

    private(set) var userId: String?
    /// Books with reading progress before the pass existed stay open, without using free books
    private var grandfathered: Set<String>
    /// Books opened while the server couldn't be reached; sent at the next refresh
    private var pendingSync: Set<String>

    private let defaults: UserDefaults
    private let repository: @MainActor () -> ReadingPassProviding?
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let guest = "readingPassGuest"
        static let account = "readingPassAccount"
        static let accountUser = "readingPassAccountUser"
        static let pendingCode = "pendingInviteCode"
        static let pendingSync = "readingPassPendingSync"
        static let grandfathered = "readingPassGrandfathered"
        static let seenFriends = "readingPassSeenFriends"
    }

    init(
        defaults: UserDefaults = .standard,
        repository: @escaping @MainActor () -> ReadingPassProviding? = { DependencyContainer.shared.bookRepository as? ReadingPassProviding },
        unlimited: AnyPublisher<Bool, Never>? = nil,
        existingProgress: @MainActor () -> [String] = { ReadingProgressStore.shared.entries.map(\.book.id) }
    ) {
        self.defaults = defaults
        self.repository = repository
        let decoder = NetworkService.makeDecoder()
        guestPass = defaults.data(forKey: Keys.guest).flatMap { try? decoder.decode(ReadingPass.self, from: $0) } ?? .guest
        pendingInviteCode = defaults.string(forKey: Keys.pendingCode)
        pendingSync = Set(defaults.stringArray(forKey: Keys.pendingSync) ?? [])

        // First launch with the pass: whatever was already started stays readable
        if let saved = defaults.stringArray(forKey: Keys.grandfathered) {
            grandfathered = Set(saved)
        } else {
            grandfathered = Set(existingProgress().map { $0.lowercased() })
            defaults.set(Array(grandfathered), forKey: Keys.grandfathered)
        }

        (unlimited ?? SubscriptionStore.shared.$isSubscribed.eraseToAnyPublisher())
            .removeDuplicates()
            .sink { [weak self] in self?.hasUnlimited = $0 }
            .store(in: &cancellables)
    }

    /// The pass that applies now: the account's once known, else the guest's
    var pass: ReadingPass {
        userId != nil ? (accountPass ?? guestPass) : guestPass
    }

    var isSignedIn: Bool { userId != nil }

    func access(for bookId: String) -> ReadingAccess {
        if hasUnlimited { return .unlimited }
        if grandfathered.contains(bookId.lowercased()) || pass.isUnlocked(bookId) { return .unlocked }
        let remaining = pass.remaining
        return remaining > 0 ? .free(remaining: remaining) : .locked
    }

    /// Call before showing a book in full. Uses a free book if needed; false when none are left.
    /// Offline, a signed-in reader still gets the book while their copy of the pass has books left.
    @discardableResult
    func open(_ bookId: String) async -> Bool {
        switch access(for: bookId) {
        case .unlimited, .unlocked: return true
        case .locked: return false
        case .free: break
        }

        guard isSignedIn else {
            var updated = guestPass
            guard updated.unlock(bookId) else { return false }
            guestPass = updated
            save()
            return true
        }

        if let repository = repository() {
            do {
                let updated = try await repository.unlockBooks([bookId.lowercased()])
                setAccountPass(updated)
                return updated.isUnlocked(bookId)
            } catch {
                log("unlock failed, keeping it on device: \(error)")
            }
        }
        var updated = pass
        guard updated.unlock(bookId) else { return false }
        accountPass = updated
        pendingSync.insert(bookId.lowercased())
        save()
        return true
    }

    // MARK: - Account

    /// Call when the signed-in user changes (nil when signed out)
    func setUser(_ id: String?) async {
        guard id != userId else { return }
        userId = id
        if let id, defaults.string(forKey: Keys.accountUser) == id {
            accountPass = defaults.data(forKey: Keys.account).flatMap { try? NetworkService.makeDecoder().decode(ReadingPass.self, from: $0) }
        } else {
            accountPass = nil
            pendingSync = []
        }
        newFriends = 0
        save()
        await refresh()
    }

    /// Loads the account's pass, moves books opened as a guest or offline onto it, and uses a code
    /// from an invite link
    func refresh() async {
        guard isSignedIn, let repository = repository() else { return }
        do {
            var updated = try await repository.fetchReadingPass()
            let toSync = Set(guestPass.unlockedBookIds).union(pendingSync)
                .filter { !updated.isUnlocked($0) }
            if !toSync.isEmpty {
                updated = try await repository.unlockBooks(Array(toSync).sorted())
                pendingSync = []
            }
            setAccountPass(updated)

            if let code = pendingInviteCode {
                if updated.invite?.canJoinWithCode == true, updated.invite?.code != code {
                    _ = try? await redeem(code)
                } else {
                    clearPendingCode()
                }
            }
        } catch {
            log("refresh failed: \(error)")
        }
    }

    /// Joins with a friend's code: 5 more books here and for the friend
    func redeem(_ input: String) async throws -> ReadingPass {
        guard let code = ReadingPass.normalizeCode(input) else { throw ReadingPassError.invalidCode }
        guard isSignedIn, let repository = repository() else {
            receiveInvite(code)
            throw ReadingPassError.signInRequired
        }
        do {
            let updated = try await repository.redeemInviteCode(code)
            clearPendingCode()
            setAccountPass(updated)
            return updated
        } catch let error as ReadingPassError {
            // Turned down: keeping the code would only retry it at every launch
            clearPendingCode()
            throw error
        }
    }

    /// A code from an invite link: kept until the reader signs in, then used
    func receiveInvite(_ code: String) {
        pendingInviteCode = code
        defaults.set(code, forKey: Keys.pendingCode)
        isPresentingPass = true
        if isSignedIn {
            Task { await refresh() }
        }
    }

    /// The reader has seen their friends' books; the "new" note goes
    func markFriendsSeen() {
        guard let userId, let joined = accountPass?.invite?.friendsJoined else { return }
        defaults.set(joined, forKey: Keys.seenFriends + "." + userId)
        newFriends = 0
    }

    // MARK: - Private

    private func setAccountPass(_ updated: ReadingPass) {
        accountPass = updated
        if let userId, let joined = updated.invite?.friendsJoined {
            let key = Keys.seenFriends + "." + userId
            // The first time, count everyone as seen: the note is for friends who join from now on
            if defaults.object(forKey: key) == nil { defaults.set(joined, forKey: key) }
            newFriends = max(0, joined - defaults.integer(forKey: key))
        }
        save()
    }

    private func clearPendingCode() {
        pendingInviteCode = nil
        defaults.removeObject(forKey: Keys.pendingCode)
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try? encoder.encode(guestPass), forKey: Keys.guest)
        defaults.set(Array(pendingSync), forKey: Keys.pendingSync)
        if let userId, let accountPass {
            defaults.set(userId, forKey: Keys.accountUser)
            defaults.set(try? encoder.encode(accountPass), forKey: Keys.account)
        }
    }

    private func log(_ message: String) {
        if AppConfiguration.shared.isLoggingEnabled {
            print("📚 ReadingPassStore: \(message)")
        }
    }
}
