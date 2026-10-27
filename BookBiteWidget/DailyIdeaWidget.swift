import CoreImage
import CoreImage.CIFilterBuiltins
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
    let tint: WidgetTint
    let deepLink: URL?

    static let placeholder = DailyIdeaEntry(
        date: .now,
        ideaText: "Small changes, repeated daily, compound into remarkable results.",
        bookTitle: "Atomic Habits",
        author: "James Clear",
        cover: nil,
        tint: .neutral,
        deepLink: nil
    )
}

/// Colors taken from the cover: a dark shade of its average hue as the background,
/// with a lighter shade of the same hue for captions so the cover stands out.
struct WidgetTint {
    let background: Color
    let accent: Color
    let text: Color

    static let neutral = WidgetTint(
        background: Color(red: 0.11, green: 0.105, blue: 0.095),
        accent: Color(red: 0.72, green: 0.69, blue: 0.63),
        text: Color(red: 0.97, green: 0.95, blue: 0.91)
    )

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func from(_ image: UIImage?) -> WidgetTint {
        guard let cgImage = image?.cgImage else { return .neutral }
        let input = CIImage(cgImage: cgImage)
        let filter = CIFilter.areaAverage()
        filter.inputImage = input
        filter.extent = input.extent
        guard let output = filter.outputImage else { return .neutral }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)

        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                blue: CGFloat(pixel[2]) / 255, alpha: 1)
            .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Black, white and grey covers have no hue worth keeping
        guard saturation > 0.12 else { return .neutral }
        let s = min(max(saturation, 0.4), 0.65)
        return WidgetTint(
            background: Color(hue: hue, saturation: s, brightness: 0.19),
            accent: Color(hue: hue, saturation: s * 0.55, brightness: 0.82),
            text: Color(hue: hue, saturation: 0.06, brightness: 0.98)
        )
    }
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

        let cover = await loadCover(idea.book.coverURL)
        return DailyIdeaEntry(
            date: .now,
            ideaText: idea.idea.idea,
            bookTitle: idea.book.title,
            author: idea.book.authors?.joined(separator: ", ") ?? "",
            cover: cover,
            tint: WidgetTint.from(cover),
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
        // Google Books: drop the baked-in page curl and ask for a sharper image
        // (same as the app's URL.bookCover; keep zoom=1 or Google may return the title page)
        if string.contains("books.google.com/books/content") {
            string = string.replacingOccurrences(of: "&edge=curl", with: "") + "&fife=w400"
        }
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

struct DailyIdeaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyIdeaEntry

    private var tint: WidgetTint { entry.tint }

    /// The first author, or the title when there is none.
    private var byline: String {
        let first = entry.author.components(separatedBy: ", ").first ?? ""
        return first.isEmpty ? entry.bookTitle : first
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                medium
            default:
                small
            }
        }
        .foregroundStyle(tint.text)
        .widgetURL(entry.deepLink)
        .containerBackground(for: .widget) { tint.background }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.9)
            .textCase(.uppercase)
            .foregroundStyle(tint.accent)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 5) {
            caption("Today")

            Text(entry.ideaText)
                .font(.system(size: 15, design: .serif))
                .lineSpacing(1)
                .lineLimit(5)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 4)

            HStack(spacing: 7) {
                cover
                    .frame(width: 20, height: 30)
                    .clipShape(bookShape)

                Text(entry.bookTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(tint.accent)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            cover
                .frame(width: 84, height: 126)
                .clipShape(bookShape)
                .shadow(color: .black.opacity(0.45), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 6) {
                caption("Idea of the day")

                Text(entry.ideaText)
                    .font(.system(size: 17, design: .serif))
                    .lineSpacing(1)
                    .lineLimit(5)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 4)

                Text(byline)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(tint.accent)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var bookShape: some Shape {
        UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2,
                               bottomTrailingRadius: 4, topTrailingRadius: 4)
    }

    @ViewBuilder
    private var cover: some View {
        if let image = entry.cover {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // Like the app's TypographicCover: the title on plain cloth
            Rectangle()
                .fill(tint.accent.opacity(0.25))
                .overlay(alignment: .topLeading) {
                    Text(entry.bookTitle)
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundStyle(tint.text)
                        .lineLimit(5)
                        .minimumScaleFactor(0.6)
                        .padding(7)
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
