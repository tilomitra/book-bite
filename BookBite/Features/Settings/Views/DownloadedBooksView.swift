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
                        Text("Books you save or start reading are downloaded so you can read them offline.")
                    }
                }
            } else {
                Section {
                    ForEach(viewModel.offlineBooks) { offlineBook in
                        if let book = OfflineStorageService.shared.getOfflineBook(id: offlineBook.bookId) {
                            NavigationLink(destination: BookDetailView(book: book)) {
                                DownloadedBookRow(
                                    offlineBook: offlineBook,
                                    formattedDate: viewModel.formattedDate(offlineBook.downloadedAt)
                                )
                            }
                        } else {
                            DownloadedBookRow(
                                offlineBook: offlineBook,
                                formattedDate: viewModel.formattedDate(offlineBook.downloadedAt)
                            )
                        }
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
            Text("This removes all downloaded books from this device. A book downloads again when you save it or open it to read.")
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

                Text("Downloaded \(formattedDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        DownloadedBooksView()
    }
}
