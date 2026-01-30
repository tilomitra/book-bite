import SwiftUI

/// Full-screen audio player view with all controls
struct AudioPlayerView: View {
    @ObservedObject var audioService: AudioPlaybackService
    @Environment(\.dismiss) private var dismiss
    @State private var showSpeedPicker = false
    @State private var isDownloading = false
    @State private var downloadComplete = false

    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with close button
                headerView
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer()

                // Album art / Book cover
                coverArtView
                    .padding(.horizontal, 40)

                Spacer()

                // Book info
                bookInfoView
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                // Progress slider
                progressView
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                // Playback controls
                controlsView
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                // Secondary controls (speed, download)
                secondaryControlsView
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showSpeedPicker) {
            SpeedPickerView(
                currentRate: audioService.playbackRate,
                onSelect: { rate in
                    audioService.setPlaybackRate(rate)
                    showSpeedPicker = false
                }
            )
            .presentationDetents([.height(300)])
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text("Audio Summary")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Spacer()

            // Placeholder for symmetry
            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    // MARK: - Cover Art

    private var coverArtView: some View {
        Group {
            if let book = audioService.currentBook {
                BookCoverView(coverURL: book.coverAssetName, size: .large)
                    .frame(maxWidth: 280, maxHeight: 280)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 280, height: 280)
            }
        }
    }

    // MARK: - Book Info

    private var bookInfoView: some View {
        VStack(spacing: 8) {
            if let book = audioService.currentBook {
                Text(book.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(book.formattedAuthors)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 8) {
            // Progress slider
            Slider(
                value: Binding(
                    get: { audioService.progress },
                    set: { newValue in
                        let newTime = newValue * audioService.duration
                        audioService.seek(to: newTime)
                    }
                ),
                in: 0...1
            )
            .tint(.primary)

            // Time labels
            HStack {
                Text(audioService.formattedCurrentTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                Spacer()

                Text(audioService.formattedRemainingTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Controls

    private var controlsView: some View {
        HStack(spacing: 40) {
            // Skip backward
            Button(action: { audioService.skipBackward() }) {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 32))
                    .foregroundColor(.primary)
            }

            // Play/Pause
            Button(action: { audioService.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 72, height: 72)

                    if audioService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor.systemBackground)))
                    } else {
                        Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30))
                            .foregroundColor(Color(UIColor.systemBackground))
                            .offset(x: audioService.isPlaying ? 0 : 2)
                    }
                }
            }
            .disabled(audioService.isLoading)

            // Skip forward
            Button(action: { audioService.skipForward() }) {
                Image(systemName: "goforward.15")
                    .font(.system(size: 32))
                    .foregroundColor(.primary)
            }
        }
    }

    // MARK: - Secondary Controls

    private var secondaryControlsView: some View {
        HStack(spacing: 40) {
            // Playback speed
            Button(action: { showSpeedPicker = true }) {
                VStack(spacing: 4) {
                    Text("\(audioService.playbackRate, specifier: "%.2g")x")
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                    Text("Speed")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
                .frame(width: 60)
            }

            // Download for offline
            offlineButton
        }
    }

    private var offlineButton: some View {
        Button(action: downloadForOffline) {
            VStack(spacing: 4) {
                if isDownloading {
                    ProgressView()
                        .frame(height: 18)
                } else if downloadComplete || hasOfflineAudio {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 18))
                }
                Text(downloadComplete || hasOfflineAudio ? "Downloaded" : "Download")
                    .font(.caption2)
            }
            .foregroundColor(.primary)
            .frame(width: 70)
        }
        .disabled(isDownloading || downloadComplete || hasOfflineAudio)
    }

    private var hasOfflineAudio: Bool {
        guard let bookId = audioService.currentBook?.id else { return false }
        return OfflineStorageService.shared.hasOfflineAudio(bookId: bookId)
    }

    private func downloadForOffline() {
        guard let book = audioService.currentBook,
              let summary = audioService.currentSummary,
              let audioUrl = summary.audioUrl else { return }

        isDownloading = true

        Task {
            do {
                try await OfflineStorageService.shared.downloadAudio(from: audioUrl, for: book.id)
                await MainActor.run {
                    downloadComplete = true
                    isDownloading = false
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                }
                if AppConfiguration.shared.isLoggingEnabled {
                    print("AudioPlayerView: Failed to download audio: \(error)")
                }
            }
        }
    }
}

// MARK: - Speed Picker

struct SpeedPickerView: View {
    let currentRate: Float
    let onSelect: (Float) -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(AudioPlaybackService.playbackRates, id: \.self) { rate in
                    Button(action: { onSelect(rate) }) {
                        HStack {
                            Text("\(rate, specifier: "%.2g")x")
                                .font(.body)

                            Spacer()

                            if rate == currentRate {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Playback Speed")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AudioPlayerView(audioService: AudioPlaybackService.shared)
}
