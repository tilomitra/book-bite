import SwiftUI

/// Settings → Account: who is signed in, Sign Out and Delete Account. The destructive actions live
/// here, one level down, so they're never a mistaken tap away in the main list.
struct AccountView: View {
    @EnvironmentObject private var authService: SupabaseAuthService
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingSignOut = false
    @State private var confirmingDelete = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if let user = authService.currentUser {
                Section {
                    VStack(spacing: 12) {
                        AccountInitial(user: user, size: 72)
                        VStack(spacing: 4) {
                            if let name = user.displayName {
                                Text(name)
                                    .font(.system(.title2, design: .serif, weight: .medium))
                            }
                            if let email = user.email {
                                Text(email)
                                    .font(user.displayName == nil
                                          ? .system(.title3, design: .serif, weight: .medium)
                                          : .subheadline)
                                    .foregroundStyle(user.displayName == nil ? .primary : .secondary)
                                    .textSelection(.enabled)
                            }
                            Text("Member since \(user.createdAt.formatted(.dateTime.month(.wide).year()))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                Button("Sign Out") {
                    confirmingSignOut = true
                }
            } footer: {
                Text("Your saved books stay in your account. Reading progress and your notebook stay on this \(UIDevice.current.model).")
            }

            Section {
                Button("Delete Account", role: .destructive) {
                    confirmingDelete = true
                }
            } footer: {
                Text("This deletes your account, saved books and reading history from BookBite's servers. You can't undo this.")
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isWorking)
        .overlay {
            if isWorking {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .confirmationDialog("Sign out of BookBite?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task { await signOut() }
            }
        }
        .alert("Delete your account?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("Your account, saved books and reading history will be deleted permanently.")
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // Both close this screen before the account goes away, so Settings never shows it signed out

    private func signOut() async {
        dismiss()
        try? await authService.signOut()
    }

    private func deleteAccount() async {
        isWorking = true
        do {
            try await authService.deleteAccount()
            dismiss()
            authService.clearSession()
        } catch {
            isWorking = false
            errorMessage = error.localizedDescription
        }
    }
}
