import SwiftUI

/// Asking the library and saving a book need an account. When a signed-out user tries one, the
/// sign-in sheet opens with art and copy for that action; after they sign in it closes and the action runs.
struct SignInPrompt: Identifiable {
    enum Reason {
        /// The question they tried to ask and the books that look like they answer it (may be empty)
        case ask(question: String, books: [Book])
        case save(Book)
        /// Getting an invite code, or claiming a friend's (`friendCode` from an invite link)
        case invite(friendCode: String?)

        var analyticsName: String {
            switch self {
            case .ask: return "ask"
            case .save: return "save"
            case .invite: return "invite"
            }
        }
    }

    let id = UUID()
    let reason: Reason
    /// What the user tried to do; runs once the sheet has closed signed in
    let onSignedIn: () -> Void

    /// Runs `action` at once when signed in. Otherwise returns the prompt to show, which runs it after sign-in.
    @MainActor
    static func gate(_ reason: Reason, auth: SupabaseAuthService, action: @escaping () -> Void) -> SignInPrompt? {
        if auth.isAuthenticated || !AppConfiguration.shared.requiresSignIn {
            action()
            return nil
        }
        Analytics.capture(.signInPromptShown(reason: reason.analyticsName))
        return SignInPrompt(reason: reason, onSignedIn: action)
    }
}

extension View {
    /// Shows the sign-in sheet for `prompt`. A successful sign-in closes it and runs the prompt's action.
    func signInPrompt(_ prompt: Binding<SignInPrompt?>) -> some View {
        modifier(SignInPromptModifier(prompt: prompt))
    }
}

private struct SignInPromptModifier: ViewModifier {
    @Binding var prompt: SignInPrompt?
    @EnvironmentObject private var authService: SupabaseAuthService
    /// The prompt that ended in a sign-in. Its action waits for the sheet to go, so a push or another sheet isn't blocked by it.
    @State private var completed: SignInPrompt?

    func body(content: Content) -> some View {
        content.sheet(item: $prompt, onDismiss: {
            completed?.onSignedIn()
            completed = nil
        }) { prompt in
            OnboardingAuthSheet(authService: authService, prompt: prompt.reason) {
                completed = prompt
                self.prompt = nil
            }
        }
    }
}

/// The picture at the top of a sign-in prompt: the books behind the question, or the book being saved.
struct SignInPromptArt: View {
    let reason: SignInPrompt.Reason

    var body: some View {
        switch reason {
        case .ask(_, let books) where !books.isEmpty:
            CoverFan(books: Array(books.prefix(3)), width: 58)
        case .ask, .invite:
            BookBiteMark(size: 56)
        case .save(let book):
            EditorialCover(book: book, width: 64)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(width: 28, height: 28)
                        .background(Color.primary, in: Circle())
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        .offset(x: 10, y: 8)
                }
                .padding(.trailing, 10)
                .padding(.bottom, 8)
                .accessibilityHidden(true)
        }
    }
}

extension SignInPrompt.Reason {
    var title: String {
        switch self {
        case .ask: return "Get your answer"
        case .save: return "Save it to your Library"
        case .invite(let code): return code == nil ? "Get 5 more books" : "Claim your 5 books"
        }
    }

    /// Says what they get, with their own question or book in it
    var message: String {
        switch self {
        case .ask(let question, let books):
            let quoted = "“\(Self.shortened(question))”"
            let found: String
            switch books.count {
            case 0: found = "BookBite answers \(quoted) with ideas from across the library."
            case 1: found = "We found a book with ideas on \(quoted)."
            default: found = "We found \(books.count) books with ideas on \(quoted)."
            }
            return found + " Create a free account to read the answer."
        case .save(let book):
            return "Create a free account to keep “\(book.shelfTitle)” in your Library and read it offline."
        case .invite(let code):
            if code != nil {
                return "A friend gave you 5 books. Create a free account to add them to your reading pass."
            }
            return "Create a free account to get your invite code. Each friend who joins with it gives you both 5 more books."
        }
    }

    /// Keeps a long question to about two lines of the message
    static func shortened(_ text: String, limit: Int = 70) -> String {
        guard text.count > limit else { return text }
        let cut = text.prefix(limit)
        let words = cut.split(separator: " ").dropLast()
        return (words.isEmpty ? String(cut) : words.joined(separator: " ")) + "…"
    }
}
