import SwiftUI

/// The book page: who wrote it, what it says, and how to use it. The full summary opens in a reader.
struct BookDetailView: View {
    @StateObject private var viewModel: BookDetailViewModel
    @ObservedObject private var audioService = AudioPlaybackService.shared
    @State private var showingChatSheet = false
    @State private var showingAuthSheet = false
    @State private var showingAudioPlayer = false
    @State private var coverTint: Color?
    @EnvironmentObject var authService: SupabaseAuthService

    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookDetailViewModel(
            book: book,
            repository: DependencyContainer.shared.bookRepository
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                bookHeader

                summaryContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
            // Keep lines a readable length on wide screens
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .background(alignment: .top) { coverWash }
        }
        .background(Color.paper.ignoresSafeArea())
        .task {
            RecentBooksStore.shared.record(viewModel.book)
            let tint = await CoverTint.color(for: viewModel.book.coverAssetName)
            withAnimation(.easeOut(duration: 0.5)) { coverTint = tint }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: handleFavoriteButtonTapped) {
                    if viewModel.isLoadingFavorite {
                        ProgressView()
                    } else {
                        Image(systemName: viewModel.isFavorite ? "bookmark.fill" : "bookmark")
                    }
                }
                .accessibilityLabel(viewModel.isFavorite ? "Remove from saved" : "Save")

                Button(action: {
                    SharingService.shared.shareBook(viewModel.book)
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
        }
        .sheet(isPresented: $showingChatSheet) {
            NavigationStack {
                BookChatView(book: viewModel.book)
                    .navigationTitle(viewModel.book.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingChatSheet = false
                            }
                        }
                    }
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAuthSheet) {
            AuthenticationView(authService: authService)
        }
        .sheet(isPresented: $showingAudioPlayer) {
            AudioPlayerView(audioService: audioService)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    /// A wash of the cover's color behind the header, fading into the page. Scrolls with the content.
    private var coverWash: some View {
        LinearGradient(
            colors: [(coverTint ?? .clear).opacity(0.5), (coverTint ?? .clear).opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 760)
        // Extend above the content, under the navigation bar and into the overscroll area
        .offset(y: -300)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var bookHeader: some View {
        VStack(spacing: 18) {
            EditorialCover(coverURL: viewModel.book.coverAssetName, width: 160)

            VStack(spacing: 6) {
                Text(viewModel.book.title)
                    .font(.system(.title2, design: .serif))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                if let subtitle = viewModel.book.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text(viewModel.book.formattedAuthors)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !viewModel.metadataLine.isEmpty {
                    Text(viewModel.metadataLine)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Summary

    @ViewBuilder
    private var summaryContent: some View {
        if viewModel.isLoadingSummary {
            Group {
                if viewModel.isGeneratingSummary {
                    GeneratingView(message: viewModel.generationMessage)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 160)
        } else if let error = viewModel.summaryError {
            ContentUnavailableView {
                Label("Can't load the summary", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.loadSummary() }
                }
                .buttonStyle(.bordered)
            }
        } else if let summary = viewModel.summary {
            actions(for: summary)
            summaryBody(summary)
        } else {
            noSummaryView
        }
    }

    private func actions(for summary: Summary) -> some View {
        VStack(spacing: 12) {
            if summary.hasFullText {
                NavigationLink(destination: SummaryReaderView(book: viewModel.book, summary: summary)) {
                    Label("Read summary", systemImage: "book")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                if summary.hasAudio {
                    secondaryButton(
                        title: summary.formattedAudioDuration.map { "Listen · \($0)" } ?? "Listen",
                        icon: "headphones"
                    ) {
                        audioService.loadAudio(for: viewModel.book, summary: summary, autoPlay: true)
                        showingAudioPlayer = true
                    }
                }

                secondaryButton(title: "Ask the book", icon: "bubble.left") {
                    showingChatSheet = true
                }
            }
        }
    }

    private func secondaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.primary)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(UIColor.separator), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func summaryBody(_ summary: Summary) -> some View {
        if !summary.oneSentenceHook.isEmpty {
            Text(summary.oneSentenceHook)
                .font(.system(.title3, design: .serif))
                .foregroundColor(.primary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }

        if !summary.keyIdeas.isEmpty {
            DetailSection(title: "Key ideas") {
                ForEach(Array(summary.keyIdeas.enumerated()), id: \.element.id) { index, idea in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.monospacedDigit())
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(minWidth: 20, alignment: .trailing)

                        Text(idea.idea)
                            .font(.body)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }

        if !summary.howToApply.isEmpty {
            DetailSection(title: "How to apply it") {
                ForEach(summary.howToApply, id: \.id) { point in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("•")
                            .foregroundColor(.secondary)
                            .frame(minWidth: 20, alignment: .trailing)

                        Text(point.action)
                            .font(.body)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }

        if !summary.whoShouldRead.isEmpty {
            DetailSection(title: "Who it's for") {
                Text(summary.whoShouldRead)
                    .font(.body)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var noSummaryView: some View {
        ContentUnavailableView {
            Label("No summary yet", systemImage: "doc.text")
        } description: {
            Text("Create a summary of the key ideas in this book. It can take a few minutes.")
        } actions: {
            Button("Create summary") {
                Task { await viewModel.generateSummary() }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Actions

    private func handleFavoriteButtonTapped() {
        if authService.authState.isAuthenticated {
            Task {
                await viewModel.toggleFavorite()
            }
        } else {
            // Saving needs an account
            showingAuthSheet = true
        }
    }
}

/// A headed block of text on the book page.
private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
