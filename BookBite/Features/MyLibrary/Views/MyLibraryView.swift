import SwiftUI

/// Library tab, your reading loop: summaries in progress, kept ideas (Notebook), books opened recently,
/// saved (needs sign-in), finished and downloaded. Settings opens from the account button in the header.
struct MyLibraryView: View {
    @EnvironmentObject private var authService: SupabaseAuthService
    @ObservedObject private var recentBooks = RecentBooksStore.shared
    @ObservedObject private var readingProgress = ReadingProgressStore.shared
    @ObservedObject private var savedIdeas = SavedIdeasStore.shared
    @StateObject private var viewModel = MyLibraryViewModel(repository: DependencyContainer.shared.bookRepository)
    @State private var showingSettings = false
    @State private var showingAuth = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

                if isEmpty {
                    LibraryIntro()
                }

                ReadingPassRow()

                if horizontalSizeClass == .regular && !readingProgress.inProgress.isEmpty && !savedIdeas.ideas.isEmpty {
                    // iPad: what you're reading and what you kept, side by side
                    HStack(alignment: .top, spacing: 16) {
                        ContinueReadingSection(entries: readingProgress.inProgress, maxCompactRows: 4)
                            .frame(maxWidth: .infinity, alignment: .top)
                        NotebookPreview(ideas: savedIdeas.ideas, previewCount: 4)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                } else {
                    ContinueReadingSection(entries: readingProgress.inProgress, maxCompactRows: 6)

                    if !savedIdeas.ideas.isEmpty {
                        NotebookPreview(ideas: savedIdeas.ideas)
                    }
                }

                if !recentlyOpened.isEmpty {
                    BookShelf(title: "Recently opened", books: recentlyOpened)
                }

                if isSignedIn {
                    if !viewModel.savedBooks.isEmpty {
                        BookShelf(title: "Saved", books: viewModel.savedBooks)
                    }
                } else {
                    signInPrompt
                }

                if !finishedBooks.isEmpty {
                    BookShelf(
                        title: "Finished",
                        caption: FinishedStats.caption(readingProgress.finished),
                        books: finishedBooks
                    )
                }

                if !viewModel.downloadedBooks.isEmpty {
                    BookShelf(title: "Downloaded", books: viewModel.downloadedBooks)
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
            && readingProgress.inProgress.isEmpty && readingProgress.finished.isEmpty && savedIdeas.ideas.isEmpty
    }

    /// Books opened recently, minus the ones already listed under Continue reading
    private var recentlyOpened: [Book] {
        let inProgress = Set(readingProgress.inProgress.map(\.book.id))
        return recentBooks.books.filter { !inProgress.contains($0.id) }
    }

    private var finishedBooks: [Book] {
        readingProgress.finished.map(\.book)
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
