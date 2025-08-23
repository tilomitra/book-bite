import Foundation
import SwiftUI
import UIKit

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
        
        Task { @MainActor in
            let shareText = generateShareText(for: book)
            var activityItems: [Any] = [shareText]
            
            // Try to load and include the book cover image
            if let coverImage = await loadBookCoverImage(for: book) {
                activityItems.append(coverImage)
            }
            
            let activityViewController = UIActivityViewController(
                activityItems: activityItems,
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
    
    private func loadBookCoverImage(for book: Book) async -> UIImage? {
        guard let coverURL = book.coverAssetName,
              let url = URL.bookCover(from: coverURL) else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("Failed to load book cover image: \(error)")
            return nil
        }
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