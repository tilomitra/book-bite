import SwiftUI

struct SettingsView: View {
    @ObservedObject private var dependencies = DependencyContainer.shared
    @StateObject private var onboardingService = DependencyContainer.shared.onboardingService
    @EnvironmentObject var authService: SupabaseAuthService
    @State private var cacheInfo: CacheInfo?
    @State private var showingClearCacheAlert = false
    @State private var showingOnboarding = false
    @State private var showingSignOutAlert = false
    @State private var showingAuthentication = false
    @State private var isRefreshing = false
    
    private let appConfig = AppConfiguration.shared
    private let cacheService = CacheService.shared
    
    var body: some View {
        NavigationView {
            Form {
                // Data Source Section
                Section {
                    Label("Data Source", systemImage: "server.rack")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Current Source:")
                            Spacer()
                            Text(currentDataSourceText)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundColor(.green)
                            Text("Online (API Only)")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    // Manual data source switching (Debug only)
                    #if DEBUG
                    debugDataSourceControls
                    #endif
                } header: {
                    Text("Data Source")
                } footer: {
                    Text("The app now uses API-only mode for always fresh data. A stable internet connection is required.")
                }
                
                // Cache Management Section
                Section {
                    Label("Cache Management", systemImage: "internaldrive")
                        .font(.headline)
                    
                    if let cacheInfo = cacheInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Cache Size:")
                                Spacer()
                                Text(cacheInfo.formattedSize)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Cached Items:")
                                Spacer()
                                Text("\(cacheInfo.fileCount)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button("Clear Cache") {
                        showingClearCacheAlert = true
                    }
                    .foregroundColor(.red)
                    
                    Button(action: refreshCacheInfo) {
                        HStack {
                            Text("Refresh Cache Info")
                            Spacer()
                            if isRefreshing {
                                ConsistentLoadingView(style: .inline)
                            }
                        }
                    }
                    .disabled(isRefreshing)
                    
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Cache improves performance by storing recently accessed data. Clearing cache will remove all cached book data.")
                }
                
                // Account Section
                Section {
                    HStack {
                        Text("Account Status")
                        Spacer()
                        Text(accountStatusText)
                            .foregroundColor(.secondary)
                    }
                    
                    if authService.isAuthenticated {
                        if let user = authService.currentUser {
                            HStack {
                                Text("Email")
                                Spacer()
                                Text(user.email ?? "Unknown")
                                    .foregroundColor(.secondary)
                            }
                            
                            if let displayName = user.displayName {
                                HStack {
                                    Text("Name")
                                    Spacer()
                                    Text(displayName)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    if authService.isAuthenticated {
                        Button("Sign Out") {
                            showingSignOutAlert = true
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("Sign In") {
                            showingAuthentication = true
                        }
                        .foregroundColor(.blue)
                    }
                    
                } header: {
                    Text("Account")
                } footer: {
                    if authService.isAuthenticated {
                        Text("Sign out to return to the authentication screen.")
                    } else if authService.isAnonymous {
                        Text("You're browsing as a guest. Sign in to save your progress.")
                    } else {
                        Text("Sign in to access your account and save your progress.")
                    }
                }
                
                // Help & Support Section
                Section {
                    Button(action: {
                        showingOnboarding = true
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                            Text("Show Onboarding")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Help & Support")
                } footer: {
                    Text("Re-watch the app introduction to learn about BookBite's features.")
                }
                
                // App Information
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundColor(.secondary)
                    }
                    
                    if appConfig.isLoggingEnabled {
                        HStack {
                            Text("Debug Mode")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                } header: {
                    Text("App Information")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                refreshCacheInfo()
            }
            .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("This will remove all cached books and summaries. Content will be re-downloaded from the API as needed.")
            }
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView()
                    .environmentObject(onboardingService)
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingAuthentication) {
                AuthenticationView(authService: authService)
                    .interactiveDismissDisabled(false)
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out? You'll need to sign in again to access your account.")
            }
        }
    }
    
    // MARK: - Debug Controls
    
    #if DEBUG
    @ViewBuilder
    private var debugDataSourceControls: some View {
        VStack(spacing: 8) {
            Button("Switch to Remote") {
                dependencies.switchToRemoteRepository()
            }
            .buttonStyle(.bordered)
            
            Button("Switch to Hybrid") {
                dependencies.switchToHybridRepository()
            }
            .buttonStyle(.borderedProminent)
            
            Text("Note: Both options now use API only")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    #endif
    
    // MARK: - Computed Properties
    
    private var currentDataSourceText: String {
        switch appConfig.currentDataSource {
        case .remote:
            return "API Only"
        case .hybrid:
            return "API Only (Simplified)"
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    private var accountStatusText: String {
        if authService.isAuthenticated {
            return "Signed In"
        } else if authService.isAnonymous {
            return "Guest"
        } else {
            return "Not Signed In"
        }
    }
    
    // MARK: - Actions
    
    private func refreshCacheInfo() {
        isRefreshing = true
        
        Task {
            let info = cacheService.getCacheInfo()
            
            await MainActor.run {
                cacheInfo = info
                isRefreshing = false
            }
        }
    }
    
    private func clearCache() {
        cacheService.clearAllCache()
        dependencies.bookRepository.clearCache()
        refreshCacheInfo()
    }
    
    private func signOut() {
        Task {
            do {
                try await authService.signOut()
            } catch {
                print("Sign out error: \(error)")
                // Even if the server call fails, we still want to clear local auth state
                // The auth service should handle this internally
            }
        }
    }
}

#Preview {
    SettingsView()
}