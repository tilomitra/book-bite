import SwiftUI

struct GeneratingSummaryView: View {
    let bookResult: GoogleBookSearchResult
    
    @State private var animationRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 32) {
            // Book preview
            VStack(spacing: 16) {
                // Book cover with loading animation
                ZStack {
                    AsyncImage(url: URL.bookCover(from: bookResult.coverUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        BookPlaceholderView.custom(
                            width: 120,
                            height: 160,
                            cornerRadius: 12,
                            showLoading: true
                        )
                    }
                    .frame(width: 120, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .scaleEffect(pulseScale)
                    .animation(
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: pulseScale
                    )
                    
                    // Loading overlay
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 160)
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.blue)
                        )
                }
                
                // Book info
                VStack(spacing: 8) {
                    Text(bookResult.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    if !bookResult.authors.isEmpty {
                        Text(bookResult.formattedAuthors)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            
            // Processing status
            VStack(spacing: 20) {
                // AI Processing animation
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(animationRotation))
                        .animation(
                            Animation.linear(duration: 2.0).repeatForever(autoreverses: false),
                            value: animationRotation
                        )
                    
                    Text("AI is analyzing this book...")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                // Status messages
                VStack(spacing: 12) {
                    StatusRow(
                        icon: "checkmark.circle.fill",
                        text: "Book added to library",
                        color: .green
                    )
                    
                    StatusRow(
                        icon: "sparkles",
                        text: "Generating intelligent summary",
                        color: .blue,
                        isAnimating: true
                    )
                    
                    StatusRow(
                        icon: "doc.text.magnifyingglass",
                        text: "Creating extended analysis",
                        color: .orange,
                        isAnimating: true
                    )
                }
                .padding(.horizontal)
            }
            
            // Tips
            VStack(spacing: 8) {
                Text("This usually takes 30-60 seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("We're creating a comprehensive summary with key insights, actionable takeaways, and an extended analysis for deep understanding")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            animationRotation = 360
            pulseScale = 1.1
        }
    }
}

struct StatusRow: View {
    let icon: String
    let text: String
    let color: Color
    var isAnimating: Bool = false
    var isPending: Bool = false
    
    @State private var animationOpacity: Double = 1.0
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isPending ? .gray : color)
                .opacity(isAnimating ? animationOpacity : 1.0)
                .animation(
                    isAnimating ? Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) : nil,
                    value: animationOpacity
                )
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(isPending ? .secondary : .primary)
            
            Spacer()
            
            if isAnimating {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(color)
            } else if !isPending {
                Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundColor(color)
            }
        }
        .onAppear {
            if isAnimating {
                animationOpacity = 0.5
            }
        }
    }
}

#Preview {
    GeneratingSummaryView(
        bookResult: GoogleBookSearchResult(
            googleBooksId: "1",
            title: "The Sample Book: A Guide to Everything",
            subtitle: nil,
            authors: ["John Doe", "Jane Smith"],
            description: "A comprehensive guide",
            categories: ["Business", "Self-Help"],
            publisher: "Sample Publisher",
            publishedYear: 2023,
            isbn10: nil,
            isbn13: nil,
            coverUrl: nil,
            inDatabase: false
        )
    )
}