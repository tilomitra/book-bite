import Foundation
import SwiftUI

class SharingService: ObservableObject {
    static let shared = SharingService()
    
    private init() {}
    
    func generateShareableLink(for book: Book) -> URL? {
        var components = URLComponents()
        components.scheme = "bookbite"
        components.host = "book"
        components.path = "/\(book.id)"
        
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "title", value: book.title))
        queryItems.append(URLQueryItem(name: "author", value: book.formattedAuthors))
        
        if let isbn = book.isbn13 ?? book.isbn10 {
            queryItems.append(URLQueryItem(name: "isbn", value: isbn))
        }
        
        components.queryItems = queryItems
        return components.url
    }
    
    func generateShareText(for book: Book) -> String {
        var shareText = "Check out \"\(book.title)\""
        
        if !book.authors.isEmpty {
            shareText += " by \(book.formattedAuthors)"
        }
        
        shareText += " on BookBite!"
        
        if let link = generateShareableLink(for: book) {
            shareText += "\n\n\(link.absoluteString)"
        }
        
        return shareText
    }
    
    func shareBook(_ book: Book) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let shareText = generateShareText(for: book)
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        // For iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        window.rootViewController?.present(activityViewController, animated: true)
    }
}

// Extension to handle incoming deep links
extension SharingService {
    func handleIncomingURL(_ url: URL) -> Book? {
        guard url.scheme == "bookbite",
              url.host == "book",
              url.pathComponents.count > 1 else {
            return nil
        }
        
        let bookId = url.pathComponents[1]
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems
        
        // Extract book information from URL
        let title = queryItems?.first(where: { $0.name == "title" })?.value ?? "Unknown Title"
        let author = queryItems?.first(where: { $0.name == "author" })?.value ?? ""
        let isbn = queryItems?.first(where: { $0.name == "isbn" })?.value
        
        // Create a basic Book object for navigation
        // Note: This would ideally fetch full book details from the repository
        return Book(
            id: bookId,
            title: title,
            authors: author.isEmpty ? [] : [author],
            isbn10: isbn?.count == 10 ? isbn : nil,
            isbn13: isbn?.count == 13 ? isbn : nil
        )
    }
}