import SwiftUI
import UIKit

@MainActor
class ColorExtractor: ObservableObject {
    @Published var dominantColor: Color = .accentColor
    @Published var secondaryColor: Color = .gray
    @Published var backgroundGradient: [Color] = [.clear, .clear]
    
    func extractColors(from imageURL: String?) async {
        guard let imageURL = imageURL,
              let url = URL(string: httpsURL(from: imageURL)) else {
            setDefaultColors()
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else {
                setDefaultColors()
                return
            }
            
            let colors = await extractDominantColors(from: uiImage)
            updateColors(with: colors)
        } catch {
            setDefaultColors()
        }
    }
    
    private func httpsURL(from url: String) -> String {
        if url.hasPrefix("http://books.google.com") {
            return url.replacingOccurrences(of: "http://", with: "https://")
        }
        return url
    }
    
    private func extractDominantColors(from image: UIImage) async -> ExtractedColors {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let colors = Self.getDominantColors(from: image)
                continuation.resume(returning: colors)
            }
        }
    }
    
    private static func getDominantColors(from image: UIImage) -> ExtractedColors {
        // Resize image for faster processing
        let size = CGSize(width: 100, height: 100)
        let resizedImage = image.resized(to: size) ?? image
        
        guard let cgImage = resizedImage.cgImage else {
            return ExtractedColors(
                dominant: UIColor.systemBlue,
                secondary: UIColor.systemGray,
                light: UIColor.systemGray6
            )
        }
        
        // Get color histogram
        let colorCounts = getColorHistogram(from: cgImage)
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        
        // Filter out grays and very light/dark colors
        let vibrantColors = sortedColors.compactMap { (color, count) -> (UIColor, Int)? in
            let (_, saturation, brightness) = color.hsb
            
            // Filter out colors that are too gray, too dark, or too light
            if saturation > 0.3 && brightness > 0.2 && brightness < 0.9 {
                return (color, count)
            }
            return nil
        }
        
        let dominantColor = vibrantColors.first?.0 ?? UIColor.systemBlue
        let secondaryColor = vibrantColors.dropFirst().first?.0 ?? Self.adjustBrightness(of: dominantColor, by: -0.2)
        let lightColor = Self.adjustBrightness(of: dominantColor, by: 0.4)
        
        return ExtractedColors(
            dominant: dominantColor,
            secondary: secondaryColor,
            light: lightColor
        )
    }
    
    private static func getColorHistogram(from cgImage: CGImage) -> [UIColor: Int] {
        let width = cgImage.width
        let height = cgImage.height
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return [:]
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return [:] }
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        var colorCounts: [UIColor: Int] = [:]
        
        // Sample every 5th pixel for performance
        for y in stride(from: 0, to: height, by: 5) {
            for x in stride(from: 0, to: width, by: 5) {
                let offset = (y * width + x) * 4
                let red = buffer[offset]
                let green = buffer[offset + 1]
                let blue = buffer[offset + 2]
                let alpha = buffer[offset + 3]
                
                // Skip transparent pixels
                if alpha > 128 {
                    // Quantize colors to reduce histogram size
                    let quantizedRed = (red / 32) * 32
                    let quantizedGreen = (green / 32) * 32
                    let quantizedBlue = (blue / 32) * 32
                    
                    let color = UIColor(
                        red: CGFloat(quantizedRed) / 255.0,
                        green: CGFloat(quantizedGreen) / 255.0,
                        blue: CGFloat(quantizedBlue) / 255.0,
                        alpha: 1.0
                    )
                    
                    colorCounts[color, default: 0] += 1
                }
            }
        }
        
        return colorCounts
    }
    
    private func updateColors(with extractedColors: ExtractedColors) {
        dominantColor = Color(extractedColors.dominant)
        secondaryColor = Color(extractedColors.secondary)
        backgroundGradient = [
            Color(extractedColors.light).opacity(0.3),
            Color(extractedColors.light).opacity(0.1),
            Color.clear
        ]
    }
    
    private func setDefaultColors() {
        dominantColor = .accentColor
        secondaryColor = .gray
        backgroundGradient = [.clear, .clear]
    }
    
    private static func adjustBrightness(of color: UIColor, by amount: CGFloat) -> UIColor {
        let (hue, saturation, brightness) = color.hsb
        let newBrightness = max(0, min(1, brightness + amount))
        return UIColor(hue: hue, saturation: saturation, brightness: newBrightness, alpha: 1.0)
    }
}

struct ExtractedColors {
    let dominant: UIColor
    let secondary: UIColor
    let light: UIColor
}

extension UIColor {
    var hsb: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (hue, saturation, brightness)
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}