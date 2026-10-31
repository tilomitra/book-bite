import SwiftUI

struct RootView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    @ObservedObject private var audioService = AudioPlaybackService.shared
    @ObservedObject private var router = DeepLinkRouter.shared
    @ObservedObject private var readingPass = ReadingPassStore.shared
    @EnvironmentObject private var authService: SupabaseAuthService
    @Environment(\.scenePhase) private var scenePhase
    @State private var showFullAudioPlayer = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: AppTab = .discover
    /// Discover's stack, so links, Spotlight and intents can push a book onto it
    @State private var discoverPath = NavigationPath()
    /// Ask's stack: the compose screen pushes a conversation onto it
    @State private var askPath = NavigationPath()

    /// Not named `Tab`: that is SwiftUI's tab type
    enum AppTab: Hashable {
        case discover, ask, search, library, notebook
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // A tab bar on iPhone; on iPad a sidebar the user can collapse into a tab bar at the top
            TabView(selection: $selectedTab) {
                Tab("Discover", systemImage: "book", value: AppTab.discover) {
                    NavigationStack(path: $discoverPath) {
                        FeaturedBooksView()
                            .navigationDestination(for: BookRoute.self) { route in
                                BookDetailView(book: route.book)
                            }
                    }
                }

                Tab("Ask", systemImage: "questionmark.bubble", value: AppTab.ask) {
                    NavigationStack(path: $askPath) {
                        AskView(path: $askPath)
                    }
                }

                Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
                    NavigationStack {
                        BookSearchView()
                    }
                }

                Tab("Library", systemImage: "books.vertical", value: AppTab.library) {
                    NavigationStack {
                        MyLibraryView()
                    }
                }

                // Sidebar only. `defaultVisibility` hides it from the iPad's top tab bar but not
                // from the compact one, so leave it out there: the iPhone keeps its four tabs
                if horizontalSizeClass == .regular {
                    TabSection("Your reading") {
                        Tab("Notebook", systemImage: "text.quote", value: AppTab.notebook) {
                            NavigationStack {
                                NotebookView()
                            }
                        }
                    }
                    .defaultVisibility(.hidden, for: .tabBar)
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            // So the Ask tab has its page the first time it opens
            .task(priority: .utility) {
                await AskHomeViewModel.preload(from: dependencies.bookRepository)
            }
            .onChange(of: horizontalSizeClass) { _, sizeClass in
                if sizeClass != .regular && selectedTab == .notebook { selectedTab = .library }
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
                // On iPad a full-width bar would stretch across the sidebar and the page
                .frame(maxWidth: horizontalSizeClass == .regular ? 560 : CGFloat.infinity)
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
        // Invite links and Library open the reading pass from here
        .sheet(isPresented: $readingPass.isPresentingPass) {
            ReadingPassView()
        }
        // The pass follows the account: load it, move guest books onto it, use a code from an invite link
        // Waits for the stored session: while it loads there's no user, which isn't a sign-out
        .task(id: authService.authState) {
            guard authService.authState != .loading else { return }
            Analytics.identify(authService.currentUser?.id)
        }
        .task(id: authService.currentUser?.id) {
            await readingPass.setUser(authService.currentUser?.id)
        }
        .onChange(of: scenePhase) { _, phase in
            // Back in the app: a friend may have joined with the code
            if phase == .active { Task { await readingPass.refresh() } }
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
