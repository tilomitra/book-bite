import Foundation

struct AppConfiguration {
    static let shared = AppConfiguration()
    
    private init() {}
    
    // MARK: - Data Source Configuration
    
    enum DataSource {
        case remote
        case hybrid // Now just wraps remote (simplified)
    }
    
    var currentDataSource: DataSource {
        // Always use remote (hybrid is just a wrapper now)
        return .remote
    }
    
    // MARK: - Server Configuration
    
    var baseServerURL: String {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BOOKBITE_SERVER_URL"] ?? "http://172.16.224.151:3000/api"
        #else
        return "https://your-production-server.com/api"
        #endif
    }
    
    // MARK: - Feature Flags
    
    var isOfflineModeEnabled: Bool {
        return false // Disabled - API only now
    }
    
    var isRemoteSearchEnabled: Bool {
        return true // Always enabled
    }
    
    var isSummaryGenerationEnabled: Bool {
        return true // Always enabled
    }
    
    var isCacheEnabled: Bool {
        return true
    }
    
    // MARK: - Cache Configuration
    
    var cacheExpirationDays: Int {
        return 7
    }
    
    var maxCacheSizeMB: Int {
        return 100
    }
    
    // MARK: - Network Configuration
    
    var networkTimeoutInterval: TimeInterval {
        return 30.0
    }
    
    var maxRetryAttempts: Int {
        return 3
    }
    
    // MARK: - Debug Configuration
    
    var isLoggingEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    var shouldShowNetworkIndicator: Bool {
        return true
    }
}

// MARK: - Environment Variables Extension

extension ProcessInfo {
    var isRunningInPreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    var isRunningTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}