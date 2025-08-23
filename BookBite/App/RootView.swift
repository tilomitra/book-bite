import SwiftUI

struct RootView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    @StateObject private var onboardingService = DependencyContainer.shared.onboardingService
    @State private var showOnboarding = false
    @State private var showDeepLinkBook = false
    
    let deepLinkBook: Book?
    
    init(deepLinkBook: Book? = nil) {
        self.deepLinkBook = deepLinkBook
    }
    
    var body: some View {
        TabView {
            NavigationStack {
                FeaturedBooksView()
            }
            .tabItem {
                Label("Featured", systemImage: "star.fill")
            }
            
            SwipeView()
            .tabItem {
                Label("Swipe", systemImage: "rectangle.stack.fill")
            }
            
            NavigationStack {
                RequestView()
            }
            .tabItem {
                Label("Request", systemImage: "plus.magnifyingglass")
            }
            
            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .onAppear {
            if !onboardingService.hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: deepLinkBook) { _, book in
            if book != nil {
                showDeepLinkBook = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(onboardingService)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showDeepLinkBook) {
            if let book = deepLinkBook {
                NavigationStack {
                    BookDetailView(book: book)
                }
            }
        }
    }
}