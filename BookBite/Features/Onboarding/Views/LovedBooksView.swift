import SwiftUI

/// "Books you've loved": the strongest taste signal. Picked books seed the reader's taste and the
/// "More like …" shelves in Discover, and are left out of recommendations.
struct LovedBooksView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private let spacing: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnboardingIconTile(systemImage: "books.vertical")
                        .padding(.top, 32)

                    Text("Books you've loved")
                        .font(.system(size: 34, weight: .medium, design: .serif))
                        .tracking(-0.6)
                        .padding(.top, 20)
                        .accessibilityAddTraits(.isHeader)

                    Text("Tap any you've read and liked. We'll find more like them.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: 3),
                              spacing: 22) {
                        ForEach(viewModel.pickerBooks) { book in
                            LovedBookTile(book: book, isSelected: viewModel.likedBookIds.contains(book.id)) {
                                viewModel.toggleLiked(book.id)
                            }
                        }
                    }
                    .padding(.top, 28)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 4) {
                OnboardingPrimaryButton(title: viewModel.likedBookIds.isEmpty
                                        ? "Continue"
                                        : "Continue with \(viewModel.likedBookIds.count)") {
                    viewModel.saveLikedBooks()
                    viewModel.step = .notifications
                }
                .disabled(viewModel.likedBookIds.isEmpty)
                .opacity(viewModel.likedBookIds.isEmpty ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.2), value: viewModel.likedBookIds.isEmpty)

                Button("Skip") { viewModel.step = .notifications }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .padding(.horizontal, 24)
            .background(Color.paper)
        }
        .sensoryFeedback(.selection, trigger: viewModel.likedBookIds)
    }
}

private struct LovedBookTile: View {
    let book: Book
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Color.clear
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .overlay {
                        GeometryReader { proxy in
                            EditorialCover(book: book, width: proxy.size.width)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(.systemBackground))
                            .frame(width: 26, height: 26)
                            .background(Color.primary, in: Circle())
                            .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 2))
                            .padding(6)
                            .scaleEffect(isSelected ? 1 : 0.4)
                            .opacity(isSelected ? 1 : 0)
                    }
                    .scaleEffect(isSelected ? 0.94 : 1)

                Text(book.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityLabel("\(book.title) by \(book.formattedAuthors)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
