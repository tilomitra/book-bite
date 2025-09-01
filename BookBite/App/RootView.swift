import SwiftUI

struct RootView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    @StateObject private var onboardingService = DependencyContainer.shared.onboardingService
    @StateObject private var authService = DependencyContainer.shared.authService
    @State private var showOnboarding = false
    @State private var showAuthentication = false
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
                    .environmentObject(authService)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            
        }
        .onAppear {
            if !onboardingService.hasCompletedOnboarding {
                showOnboarding = true
            } else if authService.authState == .unauthenticated {
                showAuthentication = true
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
                .environmentObject(authService)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showAuthentication) {
            AuthenticationView(authService: authService)
                .interactiveDismissDisabled()
        }
        .onChange(of: authService.authState) { _, newState in
            if newState == .unauthenticated && onboardingService.hasCompletedOnboarding {
                showAuthentication = true
            }
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