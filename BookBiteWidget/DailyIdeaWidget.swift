import SwiftUI
import UIKit
import WidgetKit

// MARK: - Data

/// The parts of the server's `/summaries/daily-idea` response the widget shows.
/// Same JSON the app caches in the app group (see `WidgetBridge` in the app).
struct WidgetDailyIdea: Codable {
    struct Book: Codable {
        let id: String
        let title: String
        let authors: [String]?
        let coverURL: String?

        enum CodingKeys: String, CodingKey {
            case id, title, authors
            case coverURL = "cover_url"
        }
    }

    struct Idea: Codable {
        let idea: String
    }

    let book: Book
    let idea: Idea
}

struct DailyIdeaEntry: TimelineEntry {
    let date: Date
    let ideaText: String
    let bookTitle: String
    let author: String
    let cover: UIImage?
    let deepLink: URL?

    static let placeholder = DailyIdeaEntry(
        date: .now,
        ideaText: "Small changes, repeated daily, compound into remarkable results.",
        bookTitle: "Atomic Habits",
        author: "James Clear",
        cover: nil,
        deepLink: nil
    )
}

// MARK: - Timeline

struct DailyIdeaProvider: TimelineProvider {
    private static let appGroup = "group.tilo.BookBite"
    private static let productionURL = "https://book-bite.onrender.com/api"

    func placeholder(in context: Context) -> DailyIdeaEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (DailyIdeaEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { completion(await loadEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyIdeaEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            // A new idea every local midnight
            let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
            completion(Timeline(entries: [entry], policy: .after(midnight)))
        }
    }

    private func loadEntry() async -> DailyIdeaEntry {
        let defaults = UserDefaults(suiteName: Self.appGroup)
        let idea = await fetchToday(defaults: defaults) ?? cachedIdea(defaults: defaults)
        guard let idea else { return .placeholder }

        return DailyIdeaEntry(
            date: .now,
            ideaText: idea.idea.idea,
            bookTitle: idea.book.title,
            author: idea.book.authors?.joined(separator: ", ") ?? "",
            cover: await loadCover(idea.book.coverURL),
            deepLink: deepLink(for: idea.book)
        )
    }

    private func fetchToday(defaults: UserDefaults?) async -> WidgetDailyIdea? {
        let base = defaults?.string(forKey: "serverBaseURL") ?? Self.productionURL
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let url = URL(string: "\(base)/summaries/daily-idea?date=\(formatter.string(from: .now))"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(WidgetDailyIdea.self, from: data)
    }

    private func cachedIdea(defaults: UserDefaults?) -> WidgetDailyIdea? {
        guard let data = defaults?.data(forKey: "dailyIdea") else { return nil }
        return try? JSONDecoder().decode(WidgetDailyIdea.self, from: data)
    }

    private func loadCover(_ string: String?) async -> UIImage? {
        guard var string, !string.isEmpty else { return nil }
        if string.hasPrefix("http://") { string = "https://" + string.dropFirst("http://".count) }
        guard let url = URL(string: string),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }
        // Widgets have a tight memory budget; keep the cover small
        return image.preparingThumbnail(of: CGSize(width: 160, height: 240)) ?? image
    }

    /// Opens the book page in the app (handled by `SharingService.handleIncomingURL`).
    private func deepLink(for book: WidgetDailyIdea.Book) -> URL? {
        var components = URLComponents()
        components.scheme = "bookbite"
        components.host = "book"
        components.path = "/\(book.id)"
        components.queryItems = [
            URLQueryItem(name: "title", value: book.title),
            URLQueryItem(name: "author", value: book.authors?.first ?? ""),
            URLQueryItem(name: "cover", value: book.coverURL)
        ]
        return components.url
    }
}

// MARK: - Views

private extension Color {
    /// Matches the app's `Color.paper`.
    static let paper = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 18 / 255, green: 17 / 255, blue: 16 / 255, alpha: 1)
            : UIColor(red: 250 / 255, green: 248 / 255, blue: 244 / 255, alpha: 1)
    })
}

struct DailyIdeaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyIdeaEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                medium
            default:
                small
            }
        }
        .widgetURL(entry.deepLink)
        .containerBackground(for: .widget) { Color.paper }
    }

    private var caption: some View {
        Text("Idea of the day")
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            caption

            Text(entry.ideaText)
                .font(.system(size: 15, design: .serif))
                .lineLimit(5)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            Text(entry.bookTitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                caption

                Text(entry.ideaText)
                    .font(.system(size: 17, design: .serif))
                    .lineLimit(4)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                Text(entry.author.isEmpty ? entry.bookTitle : "\(entry.bookTitle) · \(entry.author)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            cover
                .frame(width: 70, height: 105)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2,
                                                  bottomTrailingRadius: 4, topTrailingRadius: 4))
                .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let image = entry.cover {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .overlay {
                    Image(systemName: "book.closed")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

// MARK: - Widget

struct DailyIdeaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyIdeaWidget", provider: DailyIdeaProvider()) { entry in
            DailyIdeaWidgetView(entry: entry)
        }
        .configurationDisplayName("Idea of the Day")
        .description("One idea from a great book, every morning.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct BookBiteWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyIdeaWidget()
    }
}

#Preview(as: .systemMedium) {
    DailyIdeaWidget()
} timeline: {
    DailyIdeaEntry.placeholder
}
