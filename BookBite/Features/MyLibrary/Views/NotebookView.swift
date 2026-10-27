import SwiftUI

/// Every idea the user kept, by book or newest first. Swipe to remove or share; tap to open the book.
struct NotebookView: View {
    @ObservedObject var store: SavedIdeasStore
    @AppStorage("notebookArrangement") private var arrangement: Notebook.Arrangement = .byBook
    @State private var openBook: Book?
    @Namespace private var zoom

    @MainActor
    init(store: SavedIdeasStore? = nil) {
        self.store = store ?? .shared
    }

    var body: some View {
        Group {
            if store.ideas.isEmpty {
                ContentUnavailableView {
                    Label("No ideas kept yet", systemImage: "text.quote")
                } description: {
                    Text("Keep a key idea from any summary and it will wait for you here.")
                }
            } else {
                List {
                    switch arrangement {
                    case .byBook:
                        ForEach(Notebook.groupedByBook(store.ideas)) { group in
                            Section {
                                ForEach(group.ideas) { idea in
                                    ideaRow(idea, showsBook: false)
                                }
                            } header: {
                                bookHeader(group)
                            }
                        }
                    case .newest:
                        ForEach(Notebook.newestFirst(store.ideas)) { idea in
                            ideaRow(idea, showsBook: true)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .animation(.default, value: store.ideas)
                .animation(.default, value: arrangement)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Notebook")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !store.ideas.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Arrange", selection: $arrangement) {
                            ForEach(Notebook.Arrangement.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    } label: {
                        Label("Arrange", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
        }
        .navigationDestination(item: $openBook) { book in
            // Only the by-book arrangement shows covers to zoom from
            if arrangement == .byBook {
                BookDetailView(book: book)
                    .navigationTransition(.zoom(sourceID: book.id, in: zoom))
            } else {
                BookDetailView(book: book)
            }
        }
    }

    private func bookHeader(_ group: Notebook.Group) -> some View {
        Button {
            openBook = group.book
        } label: {
            HStack(spacing: 12) {
                EditorialCover(book: group.book, width: 30)
                    .zoomSource(id: group.book.id, in: zoom)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.book.shelfTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(group.book.shelfAuthor)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .textCase(nil)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the book")
    }

    private func ideaRow(_ idea: Notebook.Idea, showsBook: Bool) -> some View {
        Button {
            openBook = idea.book
        } label: {
            NotebookQuote(idea: idea, showsBook: showsBook, showsDate: true)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation { store.remove(idea) }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            ShareLink(item: Notebook.shareText(for: idea)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(.gray)
        }
        .contextMenu {
            ShareLink(item: Notebook.shareText(for: idea)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button {
                openBook = idea.book
            } label: {
                Label("Open book", systemImage: "book")
            }
            Button(role: .destructive) {
                withAnimation { store.remove(idea) }
            } label: {
                Label("Remove from notebook", systemImage: "trash")
            }
        }
        .accessibilityHint("Opens the book")
        .accessibilityActions {
            Button("Remove from notebook") { store.remove(idea) }
        }
    }
}

/// One kept idea set as a small pull quote: a hairline rule at the leading edge, the idea in serif,
/// then the book and when it was kept.
struct NotebookQuote: View {
    let idea: Notebook.Idea
    var showsBook = true
    var showsDate = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Rectangle()
                .fill(Color.primary.opacity(0.25))
                .frame(width: 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(idea.text)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(3)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if showsBook || showsDate {
                    HStack(spacing: 0) {
                        if showsBook {
                            Text(idea.book.shelfTitle)
                                .fontWeight(.semibold)
                        }
                        if showsBook && showsDate {
                            Text(" · ")
                        }
                        if showsDate {
                            Text(idea.savedAt, format: .relative(presentation: .named))
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let defaults = UserDefaults(suiteName: "preview.notebook")!
    let store = SavedIdeasStore(defaults: defaults)
    let habits = Book(id: "1", title: "Atomic Habits", authors: ["James Clear"])
    let deep = Book(id: "2", title: "Deep Work: Rules for Focused Success", authors: ["Cal Newport"])
    if store.ideas.isEmpty {
        store.toggle("You do not rise to the level of your goals. You fall to the level of your systems.", ideaId: "a", book: habits)
        store.toggle("Every action you take is a vote for the type of person you wish to become.", ideaId: "b", book: habits)
        store.toggle("Clarity about what matters provides clarity about what does not.", ideaId: "c", book: deep)
    }
    return NavigationStack { NotebookView(store: store) }
}
