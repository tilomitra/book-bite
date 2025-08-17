import Foundation

// MARK: - Search Response Models

struct PaginatedSearchResponse: Codable {
    let results: [Book]
    let pagination: PaginationInfo?
}

struct PaginationInfo: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
    let hasMore: Bool
}