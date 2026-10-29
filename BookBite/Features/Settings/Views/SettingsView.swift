import SwiftUI

struct SettingsView: View {
    @ObservedObject private var dependencies = DependencyContainer.shared
    @State private var cacheInfo: CacheInfo?
    @State private var offlineStorageInfo: OfflineStorageInfo?
    @State private var showingClearCacheAlert = false

    private let cacheService = CacheService.shared
    private let offlineStorage = OfflineStorageService.shared

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: DownloadedBooksView()) {
                    HStack {
                        Text("Downloaded Books")
                        Spacer()
                        if let info = offlineStorageInfo, info.bookCount > 0 {
                            Text("\(info.bookCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } footer: {
                Text("Books you save are downloaded so you can read them offline.")
            }

            Section {
                Button("Clear Cache", role: .destructive) {
                    showingClearCacheAlert = true
                }
            } footer: {
                if let cacheInfo = cacheInfo {
                    Text("The cache uses \(cacheInfo.formattedSize).")
                }
            }

            Section {
                LabeledContent("Version", value: appVersion)
            } footer: {
                // Required by Amazon Associates for the "Get the full book" links
                Text("As an Amazon Associate, BookBite earns from qualifying purchases.")
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            refreshCacheInfo()
            offlineStorageInfo = offlineStorage.getOfflineStorageInfo()
        }
        .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This removes cached books and summaries. Downloaded books stay.")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func refreshCacheInfo() {
        cacheInfo = cacheService.getCacheInfo()
    }

    private func clearCache() {
        cacheService.clearAllCache()
        dependencies.bookRepository.clearCache()
        refreshCacheInfo()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
