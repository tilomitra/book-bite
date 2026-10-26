import SwiftUI

/// Library tab: books you opened recently, saved (needs sign-in) and downloaded. Settings opens from the
/// account button in the header.
struct MyLibraryView: View {
    @EnvironmentObject private var authService: SupabaseAuthService
    @ObservedObject private var recentBooks = RecentBooksStore.shared
    @StateObject private var viewModel = MyLibraryViewModel(repository: DependencyContainer.shared.bookRepository)
    @State private var showingSettings = false
    @State private var showingAuth = false

    private var isSignedIn: Bool {
        authService.isAuthenticated && !authService.isAnonymous
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                EditorialHeader(title: "Library", trailing: {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                            .font(.system(size: 26))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Account and settings")
                })

                if !recentBooks.books.isEmpty {
                    BookShelf(title: "Recently opened", books: recentBooks.books)
                }

                if isSignedIn {
                    if !viewModel.savedBooks.isEmpty {
                        BookShelf(title: "Saved", books: viewModel.savedBooks)
                    }
                } else {
                    signInPrompt
                }

                if !viewModel.downloadedBooks.isEmpty {
                    BookShelf(title: "Downloaded", books: viewModel.downloadedBooks)
                }

                if isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "books.vertical",
                        description: Text("Books you open, save or download show up here.")
                    )
                    .padding(.top, 40)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Library")
        .editorialNavigationBar()
        .task(id: isSignedIn) {
            await viewModel.load(isSignedIn: isSignedIn)
        }
        .refreshable {
            await viewModel.load(isSignedIn: isSignedIn)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingAuth) {
            AuthenticationView(authService: authService)
        }
    }

    private var isEmpty: Bool {
        recentBooks.books.isEmpty && viewModel.downloadedBooks.isEmpty && (viewModel.savedBooks.isEmpty || !isSignedIn)
    }

    /// Saving needs an account; shown in place of the Saved shelf when signed out.
    private var signInPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saved")
                .font(.system(size: 24, weight: .medium, design: .serif))
                .accessibilityAddTraits(.isHeader)

            Text("Sign in to save books and keep them on all your devices.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Sign in") { showingAuth = true }
                .buttonStyle(.bordered)
                .padding(.top, 4)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 1)
        }
        .padding(.horizontal, 20)
    }
}
