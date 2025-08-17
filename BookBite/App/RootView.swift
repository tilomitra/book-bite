import SwiftUI

struct RootView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    
    var body: some View {
        TabView {
            NavigationStack {
                FeaturedBooksView()
            }
            .tabItem {
                Label("NYT Best", systemImage: "star.fill")
            }
            
            SwipeView()
            .tabItem {
                Label("Swipe", systemImage: "rectangle.stack.fill")
            }
            
            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            
            NavigationStack {
                RequestView()
            }
            .tabItem {
                Label("Request", systemImage: "plus.magnifyingglass")
            }
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}