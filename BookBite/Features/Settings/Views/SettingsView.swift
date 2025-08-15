import SwiftUI

struct SettingsView: View {
    @ObservedObject private var dependencies = DependencyContainer.shared
    @State private var cacheInfo: CacheInfo?
    @State private var showingClearCacheAlert = false
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
                        
                        if let hybridRepo = dependencies.bookRepository as? HybridBookRepository {
                            HStack {
                                Image(systemName: hybridRepo.isOnline ? "wifi" : "wifi.slash")
                                    .foregroundColor(hybridRepo.isOnline ? .green : .orange)
                                Text(hybridRepo.isOnline ? "Online" : "Offline")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    
                    // Manual data source switching (Debug only)
                    #if DEBUG
                    debugDataSourceControls
                    #endif
                } header: {
                    Text("Data Source")
                } footer: {
                    Text("The app automatically uses remote data when available and falls back to local cache when offline.")
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
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isRefreshing)
                    
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Cached data allows the app to work offline. Clearing cache will remove all downloaded book data.")
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
                Text("This will remove all cached books and summaries. You'll need an internet connection to reload content.")
            }
        }
    }
    
    // MARK: - Debug Controls
    
    #if DEBUG
    @ViewBuilder
    private var debugDataSourceControls: some View {
        VStack(spacing: 8) {
            Button("Switch to Local") {
                dependencies.switchToLocalRepository()
            }
            .buttonStyle(.bordered)
            
            Button("Switch to Remote") {
                dependencies.switchToRemoteRepository()
            }
            .buttonStyle(.bordered)
            
            Button("Switch to Hybrid") {
                dependencies.switchToHybridRepository()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    #endif
    
    // MARK: - Computed Properties
    
    private var currentDataSourceText: String {
        switch appConfig.currentDataSource {
        case .local:
            return "Local Only"
        case .remote:
            return "Remote Only"
        case .hybrid:
            return "Hybrid (Recommended)"
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
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
}

#Preview {
    SettingsView()
}