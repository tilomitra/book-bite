import SwiftUI

struct RootView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    
    var body: some View {
        TabView {
            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            
            NavigationStack {
                Text("Library")
                    .navigationTitle("My Library")
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
    }
}