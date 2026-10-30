import SwiftUI

/// Sheet raised from the email sign-in form, in the same style: asks for the email, then says to check the inbox.
struct ForgotPasswordView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var emailFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private var canSend: Bool {
        viewModel.isValidEmail && !viewModel.isLoading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
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
            .padding(.bottom, 20)

            if viewModel.resetEmailSent {
                sent
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .opacity))
            } else {
                form
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: viewModel.resetEmailSent)
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
        .tint(.primary)
        .presentationDetents([.large])
        .presentationCornerRadius(36)
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color(.systemBackground))
        // The view model outlives this sheet: start clean next time, and leave no error on the sign-in form
        .onDisappear {
            viewModel.resetEmailSent = false
            viewModel.errorMessage = nil
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Reset your password")
                .font(.system(size: 30, weight: .medium, design: .serif))
                .tracking(-0.4)
                .fixedSize(horizontal: false, vertical: true)
            Text("Enter your email and we'll send you a link to set a new one.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            OnboardingTextField(title: "Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .focused($emailFocused)
                .disabled(viewModel.isLoading)
                .padding(.top, 28)

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                    .transition(.opacity)
            }

            OnboardingPrimaryButton(title: "Send reset link", isLoading: viewModel.isLoading, action: send)
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.35)
                .padding(.top, 20)
        }
        .onAppear { emailFocused = true }
        .onSubmit {
            if canSend { send() }
        }
    }

    private var sent: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingIconTile(systemImage: "envelope.open", size: 56)
            Text("Check your inbox")
                .font(.system(size: 30, weight: .medium, design: .serif))
                .tracking(-0.4)
            Text("We sent a reset link to \(viewModel.email). Open it to set a new password, then come back and sign in.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            OnboardingPrimaryButton(title: "Back to sign in") { dismiss() }
                .padding(.top, 8)
        }
    }

    private func send() {
        emailFocused = false
        Task { await viewModel.resetPassword() }
    }
}
