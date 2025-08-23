import Foundation
import Combine

class NetworkService: ObservableObject {
    static let shared = NetworkService()
    
    private let session = URLSession.shared
    private let baseURL: URL
    
    // Configuration
    struct Configuration {
        static let timeoutInterval: TimeInterval = 30.0
        static let maxRetryAttempts = 3
    }
    
    init() {
        let baseURLString = AppConfiguration.shared.baseServerURL
        guard let url = URL(string: baseURLString) else {
            fatalError("Invalid base URL: \(baseURLString)")
        }
        self.baseURL = url
    }
    
    // MARK: - Generic Request Methods
    
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        // Handle query parameters in endpoint
        let url: URL
        if endpoint.contains("?") {
            // If endpoint contains query parameters, construct URL manually
            // Don't add extra slash if baseURL already ends with one or endpoint starts with one
            let separator = (baseURL.absoluteString.hasSuffix("/") || endpoint.hasPrefix("/")) ? "" : "/"
            guard let fullURL = URL(string: "\(baseURL.absoluteString)\(separator)\(endpoint)") else {
                throw NetworkError.invalidResponse
            }
            url = fullURL
        } else {
            url = baseURL.appendingPathComponent(endpoint)
        }
        var request = URLRequest(url: url)
        
        request.httpMethod = method.rawValue
        request.timeoutInterval = Configuration.timeoutInterval
        
        // Set default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add custom headers
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        // Add body for POST/PUT requests
        if let body = body {
            request.httpBody = body
        }
        
        // Perform request with retry logic
        return try await performRequestWithRetry(request)
    }
    
    private func performRequestWithRetry<T: Codable>(_ request: URLRequest, retryCount: Int = 0) async throws -> T {
        do {
            // Log outgoing request
            if AppConfiguration.shared.isLoggingEnabled {
                print("🌐 NetworkService: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "unknown")")
                if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
                    print("📦 Body: \(bodyString)")
                }
            }
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Log response
            if AppConfiguration.shared.isLoggingEnabled {
                print("✅ NetworkService: Response \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Response: \(responseString.prefix(500))...")
                }
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    // Try ISO8601 with microseconds first (server format)
                    let microsecondsFormatter = ISO8601DateFormatter()
                    microsecondsFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = microsecondsFormatter.date(from: dateString) {
                        return date
                    }
                    
                    // Fallback to standard ISO8601
                    let standardFormatter = ISO8601DateFormatter()
                    if let date = standardFormatter.date(from: dateString) {
                        return date
                    }
                    
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
                }
                return try decoder.decode(T.self, from: data)
            case 400...499:
                if AppConfiguration.shared.isLoggingEnabled {
                    print("❌ NetworkService: Client error \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("🚨 Error details: \(errorString)")
                    }
                }
                throw NetworkError.clientError(httpResponse.statusCode, data)
            case 500...599:
                if AppConfiguration.shared.isLoggingEnabled {
                    print("❌ NetworkService: Server error \(httpResponse.statusCode)")
                }
                throw NetworkError.serverError(httpResponse.statusCode)
            default:
                if AppConfiguration.shared.isLoggingEnabled {
                    print("❌ NetworkService: Unexpected status code \(httpResponse.statusCode)")
                }
                throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
            }
            
        } catch let error as NetworkError {
            throw error
        } catch {
            // Retry logic for network failures
            if retryCount < Configuration.maxRetryAttempts {
                let delay = Double(retryCount + 1)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await performRequestWithRetry(request, retryCount: retryCount + 1)
            }
            throw NetworkError.networkFailure(error)
        }
    }
    
    // MARK: - Convenience Methods
    
    func get<T: Codable>(endpoint: String, headers: [String: String]? = nil) async throws -> T {
        return try await request(endpoint: endpoint, method: .GET, headers: headers)
    }
    
    func post<T: Codable>(endpoint: String, body: Encodable, headers: [String: String]? = nil) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await request(endpoint: endpoint, method: .POST, body: data, headers: headers)
    }
    
    func put<T: Codable>(endpoint: String, body: Encodable, headers: [String: String]? = nil) async throws -> T {
        let data = try JSONEncoder().encode(body)
        return try await request(endpoint: endpoint, method: .PUT, body: data, headers: headers)
    }
    
    func delete(endpoint: String, headers: [String: String]? = nil) async throws {
        let _: EmptyResponse = try await request(endpoint: endpoint, method: .DELETE, headers: headers)
    }
}

// MARK: - Supporting Types

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

enum NetworkError: LocalizedError {
    case invalidResponse
    case clientError(Int, Data)
    case serverError(Int)
    case unexpectedStatusCode(Int)
    case networkFailure(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response received from server"
        case .clientError(let code, _):
            return "Client error with status code: \(code)"
        case .serverError(let code):
            return "Server error with status code: \(code)"
        case .unexpectedStatusCode(let code):
            return "Unexpected status code: \(code)"
        case .networkFailure(let error):
            return "Network failure: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

private struct EmptyResponse: Codable {}