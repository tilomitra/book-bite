import Foundation
import Combine

@MainActor
class SupabaseAuthService: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseURL = "https://yjejgiltdbuombrzdtbv.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlqZWpnaWx0ZGJ1b21icnpkdGJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyNzExMzAsImV4cCI6MjA3MDg0NzEzMH0.dcdtyuzUFmN6fPQqC80ah5IjNWuHs-I8tXyLg1TU8tI"
    
    private let userDefaults = UserDefaults.standard
    private let anonymousKey = "hasChosenAnonymous"
    private let sessionKey = "supabaseSession"
    
    init() {
        // Reset state for testing - completely clear all auth state
        userDefaults.removeObject(forKey: sessionKey)
        userDefaults.removeObject(forKey: anonymousKey)
        print("🔑 [AUTH] Cleared all authentication state")
        
        // Start with unauthenticated state
        authState = .unauthenticated
        
        // Check initial auth state
        Task {
            await checkAuthState()
        }
    }
    
    // MARK: - Auth State Management
    
    func checkAuthState() async {
        if let sessionData = userDefaults.data(forKey: sessionKey),
           let session = try? JSONDecoder().decode(SupabaseSession.self, from: sessionData) {
            // Check if session is still valid
            if session.expiresAt > Date() {
                authState = .authenticated(session.user)
                return
            }
        }
        
        if userDefaults.bool(forKey: anonymousKey) {
            authState = .anonymous
        } else {
            authState = .unauthenticated
        }
    }
    
    // MARK: - Authentication Methods
    
    func signUp(email: String, password: String, displayName: String? = nil) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/signup") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        var body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        if let displayName = displayName {
            body["data"] = ["display_name": displayName]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                let authResponse = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
                if let user = authResponse.user, let session = authResponse.session {
                    let supabaseSession = SupabaseSession(
                        user: user,
                        accessToken: session.accessToken,
                        refreshToken: session.refreshToken,
                        expiresAt: Date().addingTimeInterval(TimeInterval(session.expiresIn))
                    )
                    
                    // Save session
                    if let sessionData = try? JSONEncoder().encode(supabaseSession) {
                        userDefaults.set(sessionData, forKey: sessionKey)
                    }
                    
                    authState = .authenticated(user)
                    userDefaults.set(false, forKey: anonymousKey)
                }
            } else {
                let errorResponse = try? JSONDecoder().decode(SupabaseError.self, from: data)
                let message = errorResponse?.message ?? "Sign up failed"
                errorMessage = message
                throw AuthError.signUpFailed(message)
            }
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        print("🔑 [AUTH] Sign in attempt with email: '\(email)'")
        print("🔑 [AUTH] URL: \(supabaseURL)/auth/v1/token")
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token") else {
            print("🔑 [AUTH] ERROR: Invalid URL")
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = [
            "grant_type": "password",
            "email": email,
            "password": password
        ]
        
        print("🔑 [AUTH] Request body: \(body)")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("🔑 [AUTH] JSON serialization successful")
        } catch {
            print("🔑 [AUTH] ERROR: JSON serialization failed: \(error)")
            throw error
        }
        
        print("🔑 [AUTH] Making network request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("🔑 [AUTH] Network request completed")
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                let authResponse = try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
                if let user = authResponse.user, let session = authResponse.session {
                    let supabaseSession = SupabaseSession(
                        user: user,
                        accessToken: session.accessToken,
                        refreshToken: session.refreshToken,
                        expiresAt: Date().addingTimeInterval(TimeInterval(session.expiresIn))
                    )
                    
                    // Save session
                    if let sessionData = try? JSONEncoder().encode(supabaseSession) {
                        userDefaults.set(sessionData, forKey: sessionKey)
                    }
                    
                    authState = .authenticated(user)
                    userDefaults.set(false, forKey: anonymousKey)
                }
            } else {
                let errorResponse = try? JSONDecoder().decode(SupabaseError.self, from: data)
                let message = errorResponse?.message ?? "Sign in failed"
                errorMessage = message
                throw AuthError.signInFailed(message)
            }
        }
    }
    
    func signOut() async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // Clear local session
        userDefaults.removeObject(forKey: sessionKey)
        userDefaults.set(false, forKey: anonymousKey)
        authState = .unauthenticated
        
        // Optionally call Supabase signout endpoint
        if let sessionData = userDefaults.data(forKey: sessionKey),
           let session = try? JSONDecoder().decode(SupabaseSession.self, from: sessionData),
           let url = URL(string: "\(supabaseURL)/auth/v1/logout") {
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            
            try? await URLSession.shared.data(for: request)
        }
    }
    
    func continueAsAnonymous() {
        authState = .anonymous
        userDefaults.set(true, forKey: anonymousKey)
    }
    
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/recover") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                throw AuthError.resetPasswordFailed("Failed to send reset email")
            }
        }
    }
    
    func updatePassword(newPassword: String) async throws {
        // Implementation would require current session token
        throw AuthError.notImplemented
    }
    
    func updateProfile(displayName: String? = nil, bio: String? = nil) async throws {
        // Implementation would require current session token and user update endpoint
        throw AuthError.notImplemented
    }
    
    // MARK: - Helper Methods
    
    var isAuthenticated: Bool {
        authState.isAuthenticated
    }
    
    var isAnonymous: Bool {
        authState.isAnonymous
    }
    
    var currentUser: User? {
        authState.user
    }
    
    func getAccessToken() async throws -> String? {
        if let sessionData = userDefaults.data(forKey: sessionKey),
           let session = try? JSONDecoder().decode(SupabaseSession.self, from: sessionData) {
            return session.accessToken
        }
        return nil
    }
}

// MARK: - Supporting Types

struct SupabaseSession: Codable {
    let user: User
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct SupabaseAuthResponse: Codable {
    let user: User?
    let session: SessionResponse?
}

struct SessionResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

struct SupabaseError: Codable {
    let message: String
    let code: String?
}

enum AuthError: Error, LocalizedError {
    case invalidURL
    case signUpFailed(String)
    case signInFailed(String)
    case resetPasswordFailed(String)
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .signUpFailed(let message):
            return message
        case .signInFailed(let message):
            return message
        case .resetPasswordFailed(let message):
            return message
        case .notImplemented:
            return "Feature not implemented"
        }
    }
}