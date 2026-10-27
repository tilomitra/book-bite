import SwiftUI

struct RootView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    @ObservedObject private var audioService = AudioPlaybackService.shared
    @ObservedObject private var router = DeepLinkRouter.shared
    @State private var showFullAudioPlayer = false
    @State private var selectedTab: Tab = .discover
    /// Discover's stack, so links, Spotlight and intents can push a book onto it
    @State private var discoverPath = NavigationPath()
    /// Ask's stack: the compose screen pushes a conversation onto it
    @State private var askPath = NavigationPath()

    enum Tab: Hashable {
        case discover, ask, search, library
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack(path: $discoverPath) {
                    FeaturedBooksView()
                        .navigationDestination(for: BookRoute.self) { route in
                            BookDetailView(book: route.book)
                        }
                }
                .tabItem {
                    Label("Discover", systemImage: "book")
                }
                .tag(Tab.discover)

                NavigationStack(path: $askPath) {
                    AskView(path: $askPath)
                }
                .tabItem {
                    Label("Ask", systemImage: "questionmark.bubble")
                }
                .tag(Tab.ask)

                NavigationStack {
                    BookSearchView()
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(Tab.search)

                NavigationStack {
                    MyLibraryView()
                }
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(Tab.library)
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
        // A link can arrive before RootView exists (cold launch, during onboarding), so check on appear too
        .onAppear { showPendingBook() }
        .onChange(of: router.pending) { _, _ in showPendingBook() }
        .sheet(isPresented: $showFullAudioPlayer) {
            AudioPlayerView(audioService: audioService)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    /// Switches to Discover and shows the routed book on top of its root, replacing whatever was pushed.
    private func showPendingBook() {
        guard let route = router.pending else { return }
        router.pending = nil
        showFullAudioPlayer = false
        selectedTab = .discover
        var path = NavigationPath()
        path.append(route)
        discoverPath = path
    }
}
