import SwiftUI
import AuthenticationServices

/// Bottom sheet raised from the welcome screen: Apple, email (sign up or sign in), or browse as a guest.
/// Calls `onFinished` once the user is signed in or chose to continue as a guest.
/// With a `prompt` (see `SignInPrompt`) it asks for sign-in before an action: art and copy for that action,
/// and "Not now" just closes it.
struct OnboardingAuthSheet: View {
    @ObservedObject var authService: SupabaseAuthService
    @StateObject private var viewModel: AuthViewModel
    @State private var mode: Mode
    @State private var detent: PresentationDetent
    @State private var appleSignIn = AppleSignInController()
    @State private var confirmationEmail: String?
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss

    let prompt: SignInPrompt.Reason?
    let onFinished: () -> Void

    private let optionsDetent: PresentationDetent

    enum Mode {
        case options, signUp, signIn
    }

    private enum Field {
        case name, email, password
    }

    init(authService: SupabaseAuthService, startWithSignIn: Bool = false, prompt: SignInPrompt.Reason? = nil,
         onFinished: @escaping () -> Void) {
        self.authService = authService
        self.prompt = prompt
        self.onFinished = onFinished
        // Prompts are taller: their art replaces the mark and the message is longer
        let optionsDetent = switch prompt {
        case .ask: PresentationDetent.height(530)
        case .save: PresentationDetent.height(500)
        case nil: PresentationDetent.height(430)
        }
        self.optionsDetent = optionsDetent
        _viewModel = StateObject(wrappedValue: AuthViewModel(authService: authService))
        _mode = State(initialValue: startWithSignIn ? .signIn : .options)
        _detent = State(initialValue: startWithSignIn ? .large : optionsDetent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
                .padding(.bottom, 20)

            Group {
                switch mode {
                case .options:
                    options
                case .signUp, .signIn:
                    emailForm
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: mode)
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
        .presentationDetents([optionsDetent, .large], selection: $detent)
        .tint(.primary)
        .presentationCornerRadius(36)
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color(.systemBackground))
        .sheet(isPresented: $viewModel.showingForgotPassword) {
            ForgotPasswordView(viewModel: viewModel)
        }
        .onChange(of: authService.authState) { _, state in
            if state.isAuthenticated { onFinished() }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .top) {
            if mode == .options {
                if let prompt {
                    SignInPromptArt(reason: prompt)
                } else {
                    BookBiteMark(size: 56)
                }
            } else {
                Button {
                    focusedField = nil
                    viewModel.errorMessage = nil
                    confirmationEmail = nil
                    mode = .options
                    detent = optionsDetent
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .accessibilityLabel("Back")
            }

            Spacer()

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

    // MARK: - Options

    private var options: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(prompt?.title ?? "Get started")
                .font(.system(size: 30, weight: .medium, design: .serif))
                .tracking(-0.4)
                .fixedSize(horizontal: false, vertical: true)
            Text(prompt?.message ?? "Save books to your library, pick up where you left off, and sync across devices.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            VStack(spacing: 12) {
                OnboardingPrimaryButton(title: "Continue with Apple", systemImage: "apple.logo",
                                        isLoading: viewModel.isLoading) {
                    Task { await signInWithApple() }
                }
                OnboardingSecondaryButton(title: "Continue with Email", systemImage: "envelope") {
                    viewModel.errorMessage = nil
                    mode = .signUp
                    detent = .large
                }
            }
            .padding(.top, 28)

            errorText

            Button {
                if prompt != nil {
                    dismiss()
                } else {
                    authService.continueAsAnonymous()
                    onFinished()
                }
            } label: {
                Text(prompt != nil ? "Not now" : "Browse without an account")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Email

    private var emailForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(mode == .signUp ? "Create your account" : "Welcome back")
                .font(.system(size: 30, weight: .medium, design: .serif))
                .tracking(-0.4)
            Text(mode == .signUp ? "It takes a few seconds. No spam, ever." : signInMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            if let confirmationEmail {
                confirmation(for: confirmationEmail)
                    .padding(.top, 28)
            } else {
                fields
                    .padding(.top, 28)

                errorText

                OnboardingPrimaryButton(title: mode == .signUp ? "Create account" : "Sign in",
                                        isLoading: viewModel.isLoading) {
                    Task { await submit() }
                }
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.35)
                .padding(.top, 20)

                Button {
                    viewModel.errorMessage = nil
                    mode = mode == .signUp ? .signIn : .signUp
                } label: {
                    Group {
                        if mode == .signUp {
                            Text("Already have an account? ").foregroundStyle(.secondary) + Text("Sign in").fontWeight(.semibold)
                        } else {
                            Text("New to BookBite? ").foregroundStyle(.secondary) + Text("Create an account").fontWeight(.semibold)
                        }
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .tint(.primary)
                .padding(.top, 8)
            }
        }
        .onAppear { focusedField = mode == .signUp ? .name : .email }
        .onSubmit(advanceFocus)
    }

    private var fields: some View {
        VStack(spacing: 12) {
            if mode == .signUp {
                OnboardingTextField(title: "Name", text: $viewModel.displayName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .name)
            }

            OnboardingTextField(title: "Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .email)

            OnboardingTextField(title: mode == .signUp ? "Password (6+ characters)" : "Password",
                                text: passwordBinding, isSecure: true)
                .textContentType(mode == .signUp ? .newPassword : .password)
                .submitLabel(.go)
                .focused($focusedField, equals: .password)

            if mode == .signIn {
                Button("Forgot password?") { viewModel.showingForgotPassword = true }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .disabled(viewModel.isLoading)
    }

    private func confirmation(for email: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingIconTile(systemImage: "envelope.open", size: 56)
            Text("Check your inbox")
                .font(.headline)
            Text("We sent a confirmation link to \(email). Open it, then come back and sign in.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            OnboardingPrimaryButton(title: "Sign in") {
                confirmationEmail = nil
                mode = .signIn
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var errorText: some View {
        if let message = viewModel.errorMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .transition(.opacity)
        }
    }

    private var signInMessage: String {
        switch prompt {
        case .ask: return "Sign in to read your answer."
        case .save: return "Sign in to save the book."
        case nil: return "Sign in to see your saved books."
        }
    }

    // MARK: - Actions

    /// Sign-up has no confirm field, so the password is mirrored into the view model's confirmation
    private var passwordBinding: Binding<String> {
        Binding(
            get: { viewModel.password },
            set: {
                viewModel.password = $0
                viewModel.confirmPassword = $0
            }
        )
    }

    private var canSubmit: Bool {
        mode == .signUp ? viewModel.canSignUp : viewModel.canSignIn
    }

    private func advanceFocus() {
        switch focusedField {
        case .name: focusedField = .email
        case .email: focusedField = .password
        case .password, .none:
            if canSubmit { Task { await submit() } }
        }
    }

    private func submit() async {
        focusedField = nil
        if mode == .signUp {
            let email = viewModel.email
            await viewModel.signUp()
            // Projects with email confirmation return a user but no session
            if viewModel.errorMessage == nil, !authService.isAuthenticated {
                confirmationEmail = email
            }
        } else {
            await viewModel.signIn()
        }
    }

    private func signInWithApple() async {
        viewModel.errorMessage = nil
        do {
            let credential = try await appleSignIn.signIn()
            await viewModel.signInWithApple(credential)
        } catch let error as ASAuthorizationError where error.code == .canceled {
            // Closing the Apple sheet isn't an error
        } catch {
            viewModel.errorMessage = viewModel.mapErrorMessage(error)
        }
    }
}

/// Filled rounded field with the label as placeholder.
struct OnboardingTextField: View {
    let title: String
    @Binding var text: String
    var isSecure = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(title, text: $text)
            } else {
                TextField(title, text: $text)
            }
        }
        .font(.body)
        .padding(.horizontal, 20)
        .frame(height: 56)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Runs a Sign in with Apple request and returns the credential.
final class AppleSignInController: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    @MainActor
    func signIn() async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation?.resume(returning: credential)
        } else {
            continuation?.resume(throwing: ASAuthorizationError(.invalidResponse))
        }
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
