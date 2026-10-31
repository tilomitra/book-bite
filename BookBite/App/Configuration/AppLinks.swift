import Foundation

/// Links shown in Settings → About.
enum AppLinks {
    /// Served from `server/public/privacy.html`
    static let privacyPolicy = URL(string: "https://book-bite.onrender.com/privacy")!

    /// Apple's standard licence agreement, which applies when an app has no terms of its own
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Public support address for "Send Feedback". The row is hidden while this is nil.
    static let supportEmail: String? = "tilomitra@gmail.com"

    static func feedbackMail(appVersion: String) -> URL? {
        guard let supportEmail else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "Bookgist \(appVersion) feedback")]
        return components.url
    }
}
