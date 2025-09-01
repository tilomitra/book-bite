import SwiftUI

enum LoadingStyle {
    case primary      // Main loading screens
    case inline       // Inline loading (smaller)
    case pagination   // Loading more content
    case button       // Inside buttons
    case fullScreen   // Full screen loading
}

struct ConsistentLoadingView: View {
    let style: LoadingStyle
    let message: String?
    
    init(style: LoadingStyle = .primary, message: String? = nil) {
        self.style = style
        self.message = message
    }
    
    var body: some View {
        switch style {
        case .primary:
            primaryLoadingView
        case .inline:
            inlineLoadingView
        case .pagination:
            paginationLoadingView
        case .button:
            buttonLoadingView
        case .fullScreen:
            fullScreenLoadingView
        }
    }
    
    // Primary loading view for main content areas
    private var primaryLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)
            
            if let message = message {
                Text(message)
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                Text("Loading...")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Inline loading for smaller areas
    private var inlineLoadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.blue)
            
            if let message = message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // Pagination loading for loading more content
    private var paginationLoadingView: some View {
        HStack(spacing: 12) {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
                .tint(.blue)
            Text(message ?? "Loading more...")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 12)
    }
    
    // Button loading indicator
    private var buttonLoadingView: some View {
        ProgressView()
            .scaleEffect(0.7)
            .tint(.white)
            .frame(width: 20, height: 20)
    }
    
    // Full screen loading overlay
    private var fullScreenLoadingView: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.blue)
                
                if let message = message {
                    Text(message)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            .padding(40)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }
}

// Convenience extensions for common loading scenarios
extension ConsistentLoadingView {
    static var primary: ConsistentLoadingView {
        ConsistentLoadingView(style: .primary)
    }
    
    static var inline: ConsistentLoadingView {
        ConsistentLoadingView(style: .inline)
    }
    
    static func pagination(message: String = "Loading more...") -> ConsistentLoadingView {
        ConsistentLoadingView(style: .pagination, message: message)
    }
    
    static var button: ConsistentLoadingView {
        ConsistentLoadingView(style: .button)
    }
    
    static func fullScreen(message: String? = nil) -> ConsistentLoadingView {
        ConsistentLoadingView(style: .fullScreen, message: message)
    }
}

// View modifier for loading overlays
struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let message: String?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isLoading {
                ConsistentLoadingView(style: .fullScreen, message: message)
            }
        }
    }
}

extension View {
    func loadingOverlay(isLoading: Bool, message: String? = nil) -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }
}