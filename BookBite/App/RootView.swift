import SwiftUI

struct RootView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    @ObservedObject private var audioService = AudioPlaybackService.shared
    @State private var showDeepLinkBook = false
    @State private var showFullAudioPlayer = false

    let deepLinkBook: Book?

    init(deepLinkBook: Book? = nil) {
        self.deepLinkBook = deepLinkBook
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                NavigationStack {
                    FeaturedBooksView()
                }
                .tabItem {
                    Label("Discover", systemImage: "book")
                }

                NavigationStack {
                    BookSearchView()
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

                NavigationStack {
                    MyLibraryView()
                }
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
            }
            // Add padding at bottom when mini player is visible
            .safeAreaInset(edge: .bottom) {
                if audioService.isActive {
                    Color.clear.frame(height: 64)
                }
            }

            // Mini audio player overlay
            if audioService.isActive {
                VStack(spacing: 0) {
                    MiniAudioPlayer(
                        audioService: audioService,
                        showFullPlayer: $showFullAudioPlayer
                    )
                }
                .transition(.move(edge: .bottom))
            }
        }
        .tint(.primary)
        .animation(.easeInOut(duration: 0.25), value: audioService.isActive)
        .onChange(of: deepLinkBook) { _, book in
            if book != nil {
                showDeepLinkBook = true
            }
        }
        .sheet(isPresented: $showDeepLinkBook) {
            if let book = deepLinkBook {
                NavigationStack {
                    BookDetailView(book: book)
                }
            }
        }
        .sheet(isPresented: $showFullAudioPlayer) {
            AudioPlayerView(audioService: audioService)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
