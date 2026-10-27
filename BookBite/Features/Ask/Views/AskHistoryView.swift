import SwiftUI

/// Earlier conversations, newest first. Swipe to delete.
struct AskHistoryView: View {
    @ObservedObject private var store = AskHistoryStore.shared

    var body: some View {
        Group {
            if store.conversations.isEmpty {
                Text("Questions you ask show up here.")
                    .font(.system(size: 18, design: .serif))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.conversations) { conversation in
                        NavigationLink(value: AskRoute(conversation: conversation)) {
                            HStack(spacing: 14) {
                                CoverStack(books: Array(conversation.books.prefix(3)), width: 26)
                                    .frame(width: 52, alignment: .leading)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(conversation.title)
                                        .font(.system(size: 17, design: .serif))
                                        .lineLimit(2)
                                    Text(AskDates.short(conversation.updatedAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(Color.paper)
                    }
                    .onDelete { offsets in
                        offsets.map { store.conversations[$0] }.forEach(store.remove)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.paper)
        .navigationTitle("Your questions")
        .navigationBarTitleDisplayMode(.inline)
    }
}
