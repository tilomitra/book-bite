import SwiftUI

struct BookCoverView: View {
    let coverName: String
    let size: CoverSize
    
    enum CoverSize {
        case small
        case medium
        case large
        
        var dimensions: (width: CGFloat, height: CGFloat) {
            switch self {
            case .small:
                return (60, 90)
            case .medium:
                return (100, 150)
            case .large:
                return (150, 225)
            }
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.8),
                            Color.purple.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Image(systemName: "book.fill")
                .font(.system(size: size.dimensions.width * 0.4))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(width: size.dimensions.width, height: size.dimensions.height)
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}