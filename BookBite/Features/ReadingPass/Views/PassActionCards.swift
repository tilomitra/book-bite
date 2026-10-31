import SwiftUI
import UIKit

/// A big pastel card with a bold serif title, one line of copy, a black pill button and a hand-drawn
/// illustration (after Drop's "Refer & earn"). The pastels and the ink are fixed, so the cards look
/// the same in dark mode, like printed cards on the page. The illustration bobs once when it appears.
struct PassActionCard: View {
    let title: String
    let message: String
    let buttonTitle: String
    /// Image set in the asset catalog (vector SVG)
    let art: String
    let color: Color
    var isLoading = false
    let action: () -> Void

    static let butter = Color(red: 0.984, green: 0.933, blue: 0.753)
    static let peach = Color(red: 0.953, green: 0.698, blue: 0.588)
    static let mint = Color(red: 0.831, green: 0.945, blue: 0.894)
    static let ink = Color(red: 0.122, green: 0.09, blue: 0.086)

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var artIn = false

    var body: some View {
        // At accessibility sizes the art goes above the text, so the copy keeps the full width
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 4))

        layout {
            if dynamicTypeSize.isAccessibilitySize { artwork(width: 120) }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(.title, design: .serif).weight(.bold))
                    .tracking(-0.3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: action) {
                    HStack(spacing: 8) {
                        if isLoading { ProgressView().tint(.white) }
                        Text(buttonTitle)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 30)
                    .frame(minHeight: 44)
                    .background(Self.ink, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(PillPressStyle())
                .disabled(isLoading)
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !dynamicTypeSize.isAccessibilitySize { artwork(width: 132) }
        }
        .foregroundStyle(Self.ink)
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .background(color, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, .light)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.5).delay(0.15)) {
                artIn = true
            }
        }
    }

    private func artwork(width: CGFloat) -> some View {
        Image(art)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .rotationEffect(.degrees(artIn ? 0 : -8))
            .scaleEffect(artIn ? 1 : 0.85)
            .accessibilityHidden(true)
    }
}

/// The pill shrinks a little under the finger
private struct PillPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Invite sheet

/// "Invite your friends": the code on its library card, ways to send it, and how far the invites
/// have got (next milestone, friends who joined, the milestone ladder).
struct InviteSheet: View {
    @ObservedObject private var store = ReadingPassStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var linkCopied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SheetHeader(title: "Invite your friends",
                            message: "Give 5 books, get 5 books for every friend who joins with your code.") { dismiss() }

                if let invite = store.pass.invite {
                    VStack(spacing: 14) {
                        PassEyebrow(text: "Your invite code")
                        LibraryCard(code: invite.code)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 10) {
                        ShareLink(
                            item: invite.url,
                            subject: Text("5 free books on Bookgist"),
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

                    MilestoneLadder(friendsJoined: invite.friendsJoined)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 160)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 40)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color.paper.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .task { await store.refresh() }
        .onAppear { store.markFriendsSeen() }
    }
}

// MARK: - Code entry

/// "Enter an invite code": a field (prefilled from an invite link), a paste button, and Use code.
/// Signed out, sign-in comes on send. Closes on success and calls `onRedeemed`.
struct CodeEntrySheet: View {
    let onRedeemed: () -> Void

    @EnvironmentObject private var authService: SupabaseAuthService
    @ObservedObject private var store = ReadingPassStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var codeInput = ""
    @State private var codeError: String?
    @State private var isRedeeming = false
    @State private var signInPrompt: SignInPrompt?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SheetHeader(title: "Enter an invite code",
                        message: "A friend's code gives you both 5 more books. Each account can use one.") { dismiss() }

            HStack(spacing: 10) {
                TextField("K7QM2P", text: $codeInput)
                    .font(.custom("AmericanTypewriter-Bold", size: 24, relativeTo: .title2))
                    .tracking(6)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(useCode)
                    .focused($fieldFocused)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 56)
                    .background(PassActionCard.peach.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            }

            Button(action: useCode) {
                HStack(spacing: 8) {
                    if isRedeeming { ProgressView().tint(Color.paper) }
                    Text(store.isSignedIn ? "Use code" : "Claim 5 books")
                }
            }
            .buttonStyle(PassPrimaryButtonStyle())
            .disabled(codeInput.trimmingCharacters(in: .whitespaces).isEmpty || isRedeeming)

            Spacer(minLength: 0)
        }
        .padding(24)
        .background(Color.paper.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .signInPrompt($signInPrompt)
        .onAppear {
            if let pending = store.pendingInviteCode { codeInput = pending } else { fieldFocused = true }
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
            onRedeemed()
            dismiss()
        } catch {
            // An invite link's code may already have been used for them in the background
            if store.pass.invite?.joinedWithCode == true {
                onRedeemed()
                dismiss()
            } else {
                codeError = error.localizedDescription
            }
        }
    }
}

/// Serif title, a line of copy and a close button, at the top of the pass's sheets
private struct SheetHeader: View {
    let title: String
    let message: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.system(.title, design: .serif).weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .accessibilityLabel("Close")
            }
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
