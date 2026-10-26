import SwiftUI

/// A designed cover for books without a good cover image: a cloth-bound colour picked from the
/// title, the title in serif and the author in small caps. Lays out relative to its width,
/// so it works from a 34pt thumbnail up to the book page.
struct TypographicCover: View {
    let title: String
    let author: String

    /// Deep, bookcloth-like colours. Light text on all of them.
    private static let cloths: [UIColor] = [
        UIColor(red: 0.45, green: 0.13, blue: 0.14, alpha: 1), // oxblood
        UIColor(red: 0.12, green: 0.20, blue: 0.33, alpha: 1), // navy
        UIColor(red: 0.15, green: 0.29, blue: 0.22, alpha: 1), // forest
        UIColor(red: 0.58, green: 0.40, blue: 0.14, alpha: 1), // ochre
        UIColor(red: 0.27, green: 0.31, blue: 0.35, alpha: 1), // slate
        UIColor(red: 0.33, green: 0.18, blue: 0.33, alpha: 1), // plum
        UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1), // charcoal
        UIColor(red: 0.55, green: 0.27, blue: 0.18, alpha: 1), // rust
    ]

    /// Stable per title (String.hashValue is randomised per launch).
    static func cloth(for title: String) -> UIColor {
        let sum = title.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return cloths[sum % cloths.count]
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let ink = Color(red: 0.96, green: 0.93, blue: 0.86)

            ZStack {
                Color(Self.cloth(for: title))

                if width < 60 {
                    // Too small for words: a single initial
                    Text(String(title.prefix(1)))
                        .font(.system(size: width * 0.5, design: .serif))
                        .foregroundStyle(ink)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle()
                            .fill(ink.opacity(0.6))
                            .frame(height: max(0.5, width * 0.006))

                        Text(title)
                            .font(.system(size: width * 0.13, weight: .medium, design: .serif))
                            .foregroundStyle(ink)
                            .minimumScaleFactor(0.6)
                            .padding(.top, width * 0.07)

                        Spacer(minLength: 0)

                        Text(author)
                            .font(.system(size: width * 0.065, weight: .semibold))
                            .textCase(.uppercase)
                            .tracking(width * 0.008)
                            .foregroundStyle(ink.opacity(0.8))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(width * 0.1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(title) by \(author)")
    }
}

#Preview {
    HStack(alignment: .top, spacing: 16) {
        TypographicCover(title: "The Psychology of Money", author: "Morgan Housel")
            .frame(width: 160, height: 240)
        TypographicCover(title: "Deep Work", author: "Cal Newport")
            .frame(width: 104, height: 156)
        TypographicCover(title: "Range", author: "David Epstein")
            .frame(width: 34, height: 51)
    }
    .padding()
}
