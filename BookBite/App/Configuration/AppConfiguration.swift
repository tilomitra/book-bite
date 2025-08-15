import Foundation

struct AppConfiguration {
    static let shared = AppConfiguration()
    
    private init() {}
    
    // MARK: - Data Source Configuration
    
    enum DataSource {
        case local
        case remote
        case hybrid // Uses remote with local fallback
    }
    
    var currentDataSource: DataSource {
        #if DEBUG
        // In debug mode, you can easily switch between data sources
        return .hybrid
        #else
        // In production, use remote with local fallback
        return .hybrid
        #endif
    }
    
    // MARK: - Server Configuration
    
    var baseServerURL: String {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BOOKBITE_SERVER_URL"] ?? "http://localhost:3000/api"
        #else
        return "https://your-production-server.com/api"
        #endif
    }
    
    // MARK: - Feature Flags
    
    var isOfflineModeEnabled: Bool {
        return true
    }
    
    var isRemoteSearchEnabled: Bool {
        return currentDataSource == .remote || currentDataSource == .hybrid
    }
    
    var isSummaryGenerationEnabled: Bool {
        return currentDataSource == .remote || currentDataSource == .hybrid
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