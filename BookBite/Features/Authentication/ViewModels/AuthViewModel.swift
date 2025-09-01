import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var displayName = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingForgotPassword = false
    @Published var resetEmailSent = false
    
    private let authService: SupabaseAuthService
    
    init(authService: SupabaseAuthService) {
        self.authService = authService
    }
    
    // MARK: - Validation
    
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
    
    var isValidPassword: Bool {
        password.count >= 6
    }
    
    var passwordsMatch: Bool {
        password == confirmPassword && !password.isEmpty
    }
    
    var canSignIn: Bool {
        isValidEmail && isValidPassword && !isLoading
    }
    
    var canSignUp: Bool {
        isValidEmail && isValidPassword && passwordsMatch && !displayName.isEmpty && !isLoading
    }
    
    // MARK: - Actions
    
    func signIn() async {
        guard canSignIn else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signIn(email: email, password: password)
            clearForm()
        } catch {
            errorMessage = mapErrorMessage(error)
        }
        
        isLoading = false
    }
    
    func signUp() async {
        guard canSignUp else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signUp(
                email: email,
                password: password,
                displayName: displayName
            )
            clearForm()
        } catch {
            errorMessage = mapErrorMessage(error)
        }
        
        isLoading = false
    }
    
    func continueAsAnonymous() {
        authService.continueAsAnonymous()
    }
    
    func resetPassword() async {
        guard isValidEmail else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.resetPassword(email: email)
            resetEmailSent = true
        } catch {
            errorMessage = mapErrorMessage(error)
        }
        
        isLoading = false
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
        errorMessage = nil
    }
    
    private func mapErrorMessage(_ error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()
        
        if errorString.contains("invalid login") || errorString.contains("invalid email or password") {
            return "Invalid email or password"
        } else if errorString.contains("email already registered") || errorString.contains("user already registered") {
            return "An account with this email already exists"
        } else if errorString.contains("weak password") {
            return "Password must be at least 6 characters"
        } else if errorString.contains("invalid email") {
            return "Please enter a valid email address"
        } else if errorString.contains("network") || errorString.contains("connection") {
            return "Network error. Please check your connection and try again"
        } else {
            return "An error occurred. Please try again"
        }
    }
}