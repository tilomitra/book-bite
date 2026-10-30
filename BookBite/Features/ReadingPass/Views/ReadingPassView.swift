import SwiftUI
import UIKit

/// The reading pass: the shelf of books opened in full, then big pastel action cards (after Drop's
/// "Refer & earn"): invite friends (opens `InviteSheet`), enter a friend's code (`CodeEntrySheet`), and
/// BookBite Unlimited. Opens as a sheet when a book is out of reach (with `book`), from Library and
/// invite links, and as a page from Settings.
struct ReadingPassView: View {
    /// The book they tried to open when the pass ran out
    var book: Book? = nil
    var showsCloseButton = true

    @EnvironmentObject private var authService: SupabaseAuthService
    @ObservedObject private var store = ReadingPassStore.shared
    @ObservedObject private var subscription = SubscriptionStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var books: [String: Book] = [:]
    @State private var showingInvite = false
    @State private var showingCodeEntry = false
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    /// One line of good news after a code, a friend joining, or a subscription
    @State private var celebration: String?
    @State private var signInPrompt: SignInPrompt?

    private var pass: ReadingPass { store.pass }

    private var bookIsReadable: Bool {
        guard let book else { return false }
        return store.access(for: book.id) != .locked
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                header

                if !store.hasUnlimited {
                    PassShelf(rows: pass.shelfRows, books: books)
                }

                inviteCards

                unlimitedCards
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 48)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8), value: pass)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: celebration)
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Reading Pass")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(showsCloseButton ? .hidden : .automatic, for: .navigationBar)
        .sensoryFeedback(.success, trigger: pass.limit) { old, new in new > old }
        .signInPrompt($signInPrompt)
        .onAppear {
            books = PassBooks.lookup()
            // From an invite link: the code is waiting, so go straight to it
            // Signed in, the store uses it by itself
            if store.pendingInviteCode != nil && !store.isSignedIn { showingCodeEntry = true }
            announceNewFriends()
        }
        .task {
            await store.refresh()
            announceNewFriends()
            await subscription.loadProduct()
        }
        .onChange(of: store.pendingInviteCode) { _, code in
            if code != nil && !store.isSignedIn { showingCodeEntry = true }
        }
        .sheet(isPresented: $showingInvite) {
            InviteSheet()
        }
        .sheet(isPresented: $showingCodeEntry) {
            CodeEntrySheet {
                celebration = "Your friend's code worked: 5 more books for you, and 5 for them."
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text("READING PASS")
                    .font(.caption.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)
                Spacer()
                if showsCloseButton {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(Color.primary.opacity(0.06), in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
            }

            Text(title)
                .font(.system(size: 34, weight: .medium, design: .serif))
                .tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)

            Text(dek)
                .font(.system(.body, design: .serif))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let celebration {
                Label(celebration, systemImage: "sparkles")
                    .font(.subheadline.weight(.medium))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let book, bookIsReadable {
                Button { dismiss() } label: {
                    Text("Read “\(book.shelfTitle)” now")
                }
                .buttonStyle(PassPrimaryButtonStyle())
                .padding(.top, 8)
                .transition(.opacity)
            }
        }
    }

    private var title: String {
        if store.hasUnlimited { return "Unlimited reading" }
        if !store.isSignedIn && store.pendingInviteCode != nil { return "A friend gave you 5 books" }
        if book != nil && !bookIsReadable { return "Keep reading" }
        if pass.remaining == 0 { return "Your shelf is full" }
        return pass.remaining == 1 ? "1 free book left" : "\(pass.remaining) free books left"
    }

    private var dek: String {
        if store.hasUnlimited {
            return "Every book is open to you in full. Thank you for supporting BookBite."
        }
        if !store.isSignedIn && store.pendingInviteCode != nil {
            return "Create a free account to add them to your shelf. Your friend gets 5 more books too."
        }
        if let book, !bookIsReadable {
            return "You've opened all \(pass.limit) of your free books. Give a friend 5 books and you get 5 more to read “\(book.shelfTitle)”, or read without limits."
        }
        if pass.remaining == 0 {
            return "You've read \(pass.used) books in full. Give a friend 5 books and you get 5 more, or read without limits."
        }
        return "Each book you open in full takes a place on your shelf. Books on your shelf stay yours to reread. Key ideas are always free."
    }

    // MARK: - Invite & earn

    private var inviteCards: some View {
        VStack(alignment: .leading, spacing: 14) {
            PassEyebrow(text: "Invite & earn")

            PassActionCard(
                title: "Invite your friends",
                message: inviteMessage,
                buttonTitle: "Invite",
                art: "InviteFriends",
                color: PassActionCard.butter,
                action: openInvite
            )

            if canEnterCode {
                PassActionCard(
                    title: "Enter an invite code",
                    message: store.pendingInviteCode != nil
                        ? "Your friend's code is ready. Claim 5 books for you, and 5 for them."
                        : "Got a code from a friend? You both get 5 more books.",
                    buttonTitle: store.pendingInviteCode != nil ? "Claim" : "Start",
                    art: "InviteCode",
                    color: PassActionCard.peach,
                    action: { showingCodeEntry = true }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    private var inviteMessage: String {
        let joined = pass.invite?.friendsJoined ?? 0
        switch joined {
        case 0: return "Give 5 books, get 5 books for every friend who joins."
        case 1: return "1 friend joined: 5 books earned. Invite another for 5 more."
        default: return "\(joined) friends joined: \(joined * ReadingPass.booksPerInvite) books earned. Invite another for 5 more."
        }
    }

    /// The invite sheet needs the account's code, so signed-out readers sign in first
    private func openInvite() {
        if store.isSignedIn {
            showingInvite = true
        } else {
            signInPrompt = SignInPrompt(reason: .invite(friendCode: nil)) { showingInvite = true }
        }
    }

    /// Signed out (sign-in comes on send), or a new account that hasn't used a code yet
    private var canEnterCode: Bool {
        guard store.isSignedIn else { return true }
        return pass.invite?.canJoinWithCode == true
    }

    private func announceNewFriends() {
        let count = store.newFriends
        guard count > 0 else { return }
        celebration = count == 1
            ? "A friend joined with your code. You both got 5 more books."
            : "\(count) friends joined with your code. You got \(count * ReadingPass.booksPerInvite) more books."
        store.markFriendsSeen()
    }

    // MARK: - Unlimited

    @ViewBuilder
    private var unlimitedCards: some View {
        VStack(alignment: .leading, spacing: 14) {
            PassEyebrow(text: "Read without limits")

            if store.hasUnlimited {
                Text("You have BookBite Unlimited. It renews monthly; manage or cancel it in Settings → Apple Account → Subscriptions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                PassActionCard(
                    title: "BookBite Unlimited",
                    message: "Every book in full, read or listen. \(subscription.priceText).",
                    buttonTitle: "Subscribe",
                    art: "ReadUnlimited",
                    color: PassActionCard.mint,
                    isLoading: isPurchasing,
                    action: purchase
                )

                if let purchaseError {
                    Text(purchaseError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Renews every month at \(subscription.product?.displayPrice ?? "$9") until you cancel. Cancel at any time in Settings → Apple Account → Subscriptions.")
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 16) {
                        Link("Terms of Use", destination: AppLinks.termsOfUse)
                        Link("Privacy Policy", destination: AppLinks.privacyPolicy)
                        Button("Restore Purchases", action: restore)
                    }
                    .foregroundStyle(.primary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
        }
    }

    private func purchase() {
        purchaseError = nil
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                switch try await subscription.purchase(accountId: authService.currentUser?.id) {
                case .purchased:
                    celebration = "Welcome to BookBite Unlimited. Every book is open to you."
                case .pending:
                    purchaseError = "Your purchase is waiting for approval. Books unlock when it goes through."
                case .cancelled:
                    break
                }
            } catch {
                purchaseError = error.localizedDescription
            }
        }
    }

    private func restore() {
        purchaseError = nil
        Task {
            do {
                try await subscription.restore()
                if !subscription.isSubscribed {
                    purchaseError = "No active subscription was found for this Apple Account."
                }
            } catch {
                purchaseError = error.localizedDescription
            }
        }
    }
}

/// Small caps over a group of cards: "INVITE & EARN"
struct PassEyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.6)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Ink on paper, full width: the book page's primary button
struct PassPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 16)
            .foregroundStyle(Color.paper)
            .background(Color.primary.opacity(isEnabled ? 1 : 0.35),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// A hairline outline, full width: the book page's secondary button
struct PassSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.25), lineWidth: 0.5)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
