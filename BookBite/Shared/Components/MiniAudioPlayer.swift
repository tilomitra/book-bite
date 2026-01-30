import SwiftUI

/// Persistent mini player bar shown at the bottom of the screen when audio is playing
struct MiniAudioPlayer: View {
    @ObservedObject var audioService: AudioPlaybackService
    @Binding var showFullPlayer: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar at top
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * audioService.progress, height: 2)
            }
            .frame(height: 2)
            .background(Color.gray.opacity(0.2))

            // Main content
            HStack(spacing: 12) {
                // Book cover
                if let book = audioService.currentBook {
                    BookCoverView(coverURL: book.coverAssetName, size: .small)
                        .frame(width: 44, height: 44)
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 44, height: 44)
                }

                // Title and progress
                VStack(alignment: .leading, spacing: 2) {
                    if let book = audioService.currentBook {
                        Text(book.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Text(audioService.formattedCurrentTime + " / " + audioService.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }

                Spacer()

                // Play/Pause button
                Button(action: { audioService.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 36, height: 36)

                        if audioService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor.systemBackground)))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(UIColor.systemBackground))
                                .offset(x: audioService.isPlaying ? 0 : 1)
                        }
                    }
                }
                .disabled(audioService.isLoading)

                // Close button
                Button(action: { audioService.stop() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showFullPlayer = true
        }
    }
}

#Preview {
    VStack {
        Spacer()
        MiniAudioPlayer(
            audioService: AudioPlaybackService.shared,
            showFullPlayer: .constant(false)
        )
    }
}
