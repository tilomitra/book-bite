import SwiftUI

/// Last step: offer a morning reminder for the idea of the day, previewed as notifications
/// stacked over a faint phone outline.
struct NotificationsPromptView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onFinished: () -> Void
    @State private var isRequesting = false
    @State private var shownCards = 0

    private struct Preview: Identifiable {
        let id: Int
        let coverURL: String?
        let title: String
        let body: String
        let time: String
    }

    private var previews: [Preview] {
        let books = viewModel.books
        func cover(_ index: Int) -> String? { books.indices.contains(index) ? books[index].coverAssetName : nil }

        let idea = viewModel.dailyIdea
        let second = books.indices.contains(1) ? books[1] : nil
        let third = books.indices.contains(2) ? books[2] : nil
        return [
            Preview(id: 0,
                    coverURL: idea?.book.coverAssetName ?? cover(0),
                    title: "Idea of the day",
                    body: idea?.idea.idea ?? "Small habits compound into remarkable results.",
                    time: "now"),
            Preview(id: 1,
                    coverURL: cover(1),
                    title: "New summary",
                    body: second.map { "\($0.title) by \($0.formattedAuthors)" } ?? "Key ideas, audio and a 10-minute read.",
                    time: "1h"),
            Preview(id: 2,
                    coverURL: cover(2),
                    title: third?.title ?? "Pick up where you left off",
                    body: "You have 4 minutes left. Finish it with your coffee.",
                    time: "1d")
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingIconTile(systemImage: "bell")
                .symbolEffect(.wiggle, options: .nonRepeating, value: shownCards == previews.count)
                .padding(.top, 32)

            Text("One big idea, every morning")
                .font(.system(size: 34, weight: .medium, design: .serif))
                .tracking(-0.6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)
                .accessibilityAddTraits(.isHeader)

            Text("Get the idea of the day at 8 AM. It takes a minute to read.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            Spacer(minLength: 24)

            ZStack(alignment: .top) {
                PhoneOutline()
                    .frame(width: 260)
                    .frame(maxHeight: .infinity, alignment: .top)

                VStack(spacing: 12) {
                    ForEach(previews) { preview in
                        NotificationCard(coverURL: preview.coverURL, title: preview.title,
                                         message: preview.body, time: preview.time)
                            .opacity(shownCards > preview.id ? 1 : 0)
                            .offset(y: shownCards > preview.id ? 0 : -16)
                            .scaleEffect(shownCards > preview.id ? 1 : 0.96)
                    }
                }
                .padding(.top, 110)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 380)
            .mask(LinearGradient(stops: [.init(color: .black, location: 0.75), .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            .accessibilityHidden(true)

            Spacer(minLength: 16)

            VStack(spacing: 4) {
                OnboardingPrimaryButton(title: "Turn On Notifications", isLoading: isRequesting) {
                    isRequesting = true
                    Task {
                        await DailyIdeaReminder.enable()
                        isRequesting = false
                        onFinished()
                    }
                }

                Button("Not Right Now", action: onFinished)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .padding(.horizontal, 24)
        .task {
            for index in 1...previews.count {
                try? await Task.sleep(for: .milliseconds(index == 1 ? 350 : 220))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { shownCards = index }
            }
        }
    }
}

private struct NotificationCard: View {
    let coverURL: String?
    let title: String
    let message: String
    let time: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                EditorialCover(coverURL: coverURL, width: 34)
                    .frame(width: 44, height: 52)
                BookBiteMark(size: 18)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    .offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(time)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
    }
}

/// A faint phone silhouette (frame + Dynamic Island) behind the notification previews.
private struct PhoneOutline: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 52, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 10)
            .background(RoundedRectangle(cornerRadius: 52, style: .continuous).fill(Color.primary.opacity(0.015)))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 84, height: 26)
                    .padding(.top, 20)
            }
    }
}
