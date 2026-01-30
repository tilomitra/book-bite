import SwiftUI

struct DownloadedBooksView: View {
    @StateObject private var viewModel = DownloadedBooksViewModel()

    var body: some View {
        List {
            // Storage Info Section
            if let storageInfo = viewModel.storageInfo {
                Section {
                    HStack {
                        Label("Total Storage", systemImage: "externaldrive.fill")
                        Spacer()
                        Text(storageInfo.formattedSize)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Downloaded Books", systemImage: "book.closed.fill")
                        Spacer()
                        Text("\(storageInfo.bookCount)")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Storage Usage")
                }
            }

            // Downloaded Books List
            if viewModel.offlineBooks.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Downloaded Books", systemImage: "arrow.down.circle")
                    } description: {
                        Text("Books you favorite will be automatically downloaded for offline reading.")
                    }
                }
            } else {
                Section {
                    ForEach(viewModel.offlineBooks) { offlineBook in
                        DownloadedBookRow(
                            offlineBook: offlineBook,
                            formattedDate: viewModel.formattedDate(offlineBook.downloadedAt)
                        )
                    }
                    .onDelete(perform: viewModel.removeBook)
                } header: {
                    Text("Downloaded Books")
                } footer: {
                    Text("Swipe left on a book to remove it from offline storage.")
                }

                // Remove All Button
                Section {
                    Button(role: .destructive) {
                        viewModel.showingRemoveAllAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Remove All Downloads", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Downloaded Books")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            viewModel.loadOfflineBooks()
        }
        .alert("Remove All Downloads", isPresented: $viewModel.showingRemoveAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove All", role: .destructive) {
                viewModel.removeAllBooks()
            }
        } message: {
            Text("This will remove all downloaded books from offline storage. You can re-download them by favoriting the books again.")
        }
    }
}

// MARK: - Downloaded Book Row

struct DownloadedBookRow: View {
    let offlineBook: OfflineBook
    let formattedDate: String

    var body: some View {
        HStack(spacing: 12) {
            // Cover Image
            OfflineAwareBookCoverView(
                bookId: offlineBook.bookId,
                coverURL: nil,
                size: .small
            )

            // Book Info
            VStack(alignment: .leading, spacing: 4) {
                Text(offlineBook.bookTitle)
                    .font(.headline)
                    .lineLimit(2)

                if !offlineBook.bookAuthors.isEmpty {
                    Text(offlineBook.bookAuthors.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    // Download date
                    Label(formattedDate, systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Status indicators
                    if offlineBook.hasSummary {
                        Label("Summary", systemImage: "doc.text.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            // Offline indicator
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title3)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        DownloadedBooksView()
    }
}
