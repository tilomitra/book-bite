import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// The average color of a book cover, used to tint the book page. Cached per URL.
enum CoverTint {
    private static let cache = NSCache<NSURL, UIColor>()
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func color(for coverURL: String?) async -> Color? {
        guard let url = URL.bookCover(from: coverURL) else { return nil }
        if let cached = cache.object(forKey: url as NSURL) {
            return Color(cached)
        }

        // Usually served from URLCache: the cover was just shown on the previous screen
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = CIImage(data: data) else { return nil }

        let filter = CIFilter.areaAverage()
        filter.inputImage = image
        filter.extent = image.extent
        guard let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)

        let color = vivid(UIColor(red: CGFloat(pixel[0]) / 255,
                                  green: CGFloat(pixel[1]) / 255,
                                  blue: CGFloat(pixel[2]) / 255,
                                  alpha: 1))
        cache.setObject(color, forKey: url as NSURL)
        return Color(color)
    }

    /// Averages come out muddy; push saturation up and keep brightness in a usable range.
    private static func vivid(_ color: UIColor) -> UIColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return color }
        return UIColor(hue: hue,
                       saturation: min(saturation * 1.4, 0.85),
                       brightness: min(max(brightness, 0.35), 0.9),
                       alpha: 1)
    }
}

extension View {
    /// Marks this view as the origin of a zoom navigation transition, when a namespace is given.
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}
