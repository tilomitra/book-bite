import SwiftUI
import UIKit

/// The reading pass: the shelf of books opened in full, the invite code on a library card ("Give 5,
/// get 5"), a field for a friend's code, and BookBite Unlimited. Opens as a sheet when a book is out of
/// reach (with `book`), from Library and invite links, and as a page from Settings.
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
    @State private var codeInput = ""
    @State private var codeError: String?
    @State private var isRedeeming = false
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    /// One line of good news after a code, a friend joining, or a subscription
    @State private var celebration: String?
    @State private var signInPrompt: SignInPrompt?
    @State private var linkCopied = false

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

                inviteSection

                if canEnterCode {
                    codeSection
                }

                unlimitedSection
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
            if codeInput.isEmpty, let pending = store.pendingInviteCode { codeInput = pending }
            announceNewFriends()
        }
        .task {
            await store.refresh()
            announceNewFriends()
            await subscription.loadProduct()
        }
        .onChange(of: store.pendingInviteCode) { _, code in
            if let code { codeInput = code }
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

    // MARK: - Invite

    private var inviteSection: some View {
        PassSection(title: "Give 5, get 5") {
            Text(inviteCaption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let invite = pass.invite {
                VStack(spacing: 14) {
                    Text("YOUR INVITE CODE")
                        .font(.caption.weight(.semibold))
                        .tracking(1.6)
                        .foregroundStyle(.secondary)
                    LibraryCard(code: invite.code)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                VStack(spacing: 10) {
                    ShareLink(
                        item: invite.url,
                        subject: Text("5 free books on BookBite"),
                        message: Text(InviteMessage.text(code: invite.code, url: invite.url, book: nil))
                    ) {
                        Label("Send to a friend", systemImage: "paperplane")
                    }
                    .buttonStyle(PassPrimaryButtonStyle())

                    Button {
                        UIPasteboard.general.url = invite.url
                        linkCopied = true
                    } label: {
                        Label(linkCopied ? "Link copied" : "Copy invite link", systemImage: linkCopied ? "checkmark" : "link")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(PassSecondaryButtonStyle())
                    .sensoryFeedback(.success, trigger: linkCopied) { _, new in new }
                }

                InviteProgressPanel(invite: invite)
                    .padding(.top, 8)

                MilestoneLadder(friendsJoined: invite.friendsJoined)
                    .padding(.top, 8)
            } else if store.isSignedIn {
                // Signed in, but the server hasn't answered yet
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Button {
                    signInPrompt = SignInPrompt(reason: .invite(friendCode: nil)) {}
                } label: {
                    Text("Sign in to get your code")
                }
                .buttonStyle(PassPrimaryButtonStyle())
            }
        }
    }

    private var inviteCaption: String {
        let joined = pass.invite?.friendsJoined ?? 0
        if let invite = pass.invite, joined >= invite.maxFriends {
            return "\(joined) friends joined with your code. Thank you for sharing BookBite."
        }
        switch joined {
        case 0: return "Send your code to a friend. When they join BookBite with it, you both get 5 more books."
        case 1: return "1 friend joined, so you both got 5 more books. Each new friend adds another 5."
        default: return "\(joined) friends joined: \(joined * ReadingPass.booksPerInvite) books earned. Each new friend adds another 5."
        }
    }

    // MARK: - Friend's code

    /// Signed out (sign-in comes on send), or a new account that hasn't used a code yet
    private var canEnterCode: Bool {
        guard store.isSignedIn else { return true }
        return pass.invite?.canJoinWithCode == true
    }

    private var codeSection: some View {
        PassSection(title: "Have a code?") {
            Text("A friend's code gives you both 5 more books. Each account can use one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                TextField("K7QM2P", text: $codeInput)
                    .font(.system(.title3, design: .serif))
                    .tracking(4)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(useCode)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                    }
                    .accessibilityLabel("Friend's code")

                // No paste permission prompt: the system button pastes only when tapped
                PasteButton(payloadType: String.self) { strings in
                    if let first = strings.first { codeInput = first }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.capsule)
                .tint(.primary)
            }

            if let codeError {
                Text(codeError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }

            Button(action: useCode) {
                HStack(spacing: 8) {
                    if isRedeeming { ProgressView().tint(Color.paper) }
                    Text(store.isSignedIn ? "Use code" : "Claim 5 books")
                }
            }
            .buttonStyle(PassPrimaryButtonStyle())
            .disabled(codeInput.trimmingCharacters(in: .whitespaces).isEmpty || isRedeeming)
        }
    }

    private func useCode() {
        codeError = nil
        guard let code = ReadingPass.normalizeCode(codeInput) else {
            codeError = ReadingPassError.invalidCode.localizedDescription
            return
        }
        let action: () -> Void = {
            Task { await self.redeem(code) }
        }
        if let prompt = SignInPrompt.gate(.invite(friendCode: code), auth: authService, action: action) {
            signInPrompt = prompt
        }
    }

    private func redeem(_ code: String) async {
        isRedeeming = true
        defer { isRedeeming = false }
        do {
            _ = try await store.redeem(code)
            codeInput = ""
            celebration = "Your friend's code worked: 5 more books for you, and 5 for them."
        } catch {
            codeError = error.localizedDescription
        }
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
    private var unlimitedSection: some View {
        if store.hasUnlimited {
            PassSection(title: "BookBite Unlimited") {
                Text("Your subscription renews monthly. Manage or cancel it in Settings → Apple Account → Subscriptions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            PassSection(title: "Read without limits") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BookBite Unlimited")
                        .font(.headline)
                    Text("Open every book in full, read or listen, as often as you like.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: purchase) {
                    HStack(spacing: 8) {
                        if isPurchasing { ProgressView() }
                        Text("Subscribe · \(subscription.priceText)")
                    }
                }
                .buttonStyle(PassSecondaryButtonStyle())
                .disabled(isPurchasing)

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

/// A headed block of the pass: a hairline, then a serif heading
private struct PassSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 0.5)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(.title2, design: .serif))
                    .fontWeight(.medium)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Ink on paper, full width: the book page's primary button
private struct PassPrimaryButtonStyle: ButtonStyle {
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
private struct PassSecondaryButtonStyle: ButtonStyle {
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
