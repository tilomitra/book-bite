import UIKit
import ImageIO

/// Loads book covers for lists: small versions from the cover hosts, a large disk cache, and images
/// decoded at the size they're shown, off the main thread. Each decoded cover stays in memory so a
/// view can show it in its first frame.
final class CoverImageLoader: @unchecked Sendable {
    static let shared = CoverImageLoader()

    /// Widths covers are decoded at, so similar sizes share one image
    private static let pixelWidths = [120, 240, 360, 480, 720, 1080]
    /// Every supported iPad is 2x; 2x iPhones just get a slightly sharper cover
    private static let screenScale: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 2 : 3

    private let images = NSCache<NSString, UIImage>()
    /// The latest image per cover at any size, shown while a sharper one loads
    private let latestImages = NSCache<NSString, UIImage>()
    private let session: URLSession
    private let inFlight = InFlightLoads()

    init() {
        images.totalCostLimit = 150 * 1024 * 1024
        latestImages.countLimit = 300

        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 300 * 1024 * 1024, diskPath: "covers")
        // A cover URL always shows the same cover, so a cached one never needs checking
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
    }

    static func pixelWidth(forPoints width: CGFloat) -> Int {
        let needed = Int((width * screenScale).rounded(.up))
        return pixelWidths.first { $0 >= needed } ?? pixelWidths[pixelWidths.count - 1]
    }

    /// The width to ask the cover host for: only a few sizes, so the disk cache gets more hits
    private static func downloadWidth(for pixelWidth: Int) -> Int {
        pixelWidth <= 420 ? 400 : pixelWidth <= 800 ? 800 : 1200
    }

    private func key(_ coverURL: String, _ pixelWidth: Int) -> NSString {
        "\(pixelWidth)|\(coverURL)" as NSString
    }

    /// In memory at this size or larger. Safe from a view's init.
    func cachedImage(for coverURL: String, pixelWidth: Int) -> UIImage? {
        for width in Self.pixelWidths where width >= pixelWidth {
            if let image = images.object(forKey: key(coverURL, width)) { return image }
        }
        return nil
    }

    /// The best image to show right now: the right size, or else any size already in memory
    func placeholderImage(for coverURL: String, pixelWidth: Int) -> UIImage? {
        cachedImage(for: coverURL, pixelWidth: pixelWidth) ?? latestImages.object(forKey: coverURL as NSString)
    }

    /// Nil when the cover can't be loaded. The work goes on if the caller is cancelled, so a cover
    /// that scrolled away is ready when it comes back.
    func image(for coverURL: String, pixelWidth: Int) async -> UIImage? {
        if let image = cachedImage(for: coverURL, pixelWidth: pixelWidth) { return image }
        let task = await inFlight.task(for: key(coverURL, pixelWidth) as String) { [self] in
            await load(coverURL, pixelWidth: pixelWidth)
        }
        return await task.value
    }

    /// Fetches covers that are about to appear, at the lowest priority
    func prefetch(_ coverURLs: [String], pixelWidth: Int) {
        for coverURL in coverURLs where cachedImage(for: coverURL, pixelWidth: pixelWidth) == nil {
            Task.detached(priority: .utility) { [self] in
                _ = await image(for: coverURL, pixelWidth: pixelWidth)
            }
        }
    }

    private func load(_ coverURL: String, pixelWidth: Int) async -> UIImage? {
        guard let url = URL.bookCover(from: coverURL, maxWidth: Self.downloadWidth(for: pixelWidth)) else { return nil }
        for attempt in 0..<2 {
            if attempt > 0 { try? await Task.sleep(for: .milliseconds(300)) }
            guard let (data, response) = try? await session.data(from: url) else { continue }
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let image = Self.decode(data, pixelWidth: pixelWidth) else { return nil }
            images.setObject(image, forKey: key(coverURL, pixelWidth), cost: Self.memoryCost(of: image))
            latestImages.setObject(image, forKey: coverURL as NSString)
            return image
        }
        return nil
    }

    /// Thumbnails decode only what they need, and at once, so the first draw on the main thread does no work
    private static func decode(_ data: Data, pixelWidth: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        // The limit applies to the longest side, the height of a cover
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelWidth * 8 / 5
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    private static func memoryCost(of image: UIImage) -> Int {
        image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
    }
}

/// One load per cover and size, however many views ask at once
private actor InFlightLoads {
    private var tasks: [String: Task<UIImage?, Never>] = [:]

    func task(for key: String, load: @escaping @Sendable () async -> UIImage?) -> Task<UIImage?, Never> {
        if let task = tasks[key] { return task }
        let task = Task.detached(priority: .userInitiated) { [weak self] in
            let image = await load()
            await self?.finish(key)
            return image
        }
        tasks[key] = task
        return task
    }

    private func finish(_ key: String) {
        tasks[key] = nil
    }
}
