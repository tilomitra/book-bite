import SwiftUI

/// The Ask tab: a featured question (new each time the tab opens), Explore topics and the "What's on your mind?" field.
/// Asking opens `AskComposeView`; sending it pushes `AskConversationView`.
struct AskView: View {
    /// The Ask tab's navigation path (owned by `RootView`)
    @Binding var path: NavigationPath
    @StateObject private var viewModel = AskHomeViewModel(bookRepository: DependencyContainer.shared.bookRepository)
    @State private var compose: ComposeRequest?

    struct ComposeRequest: Identifiable {
        let id = UUID()
        var suggestions: [String]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                EditorialHeader(title: "Ask", trailing: {
                    Button {
                        path.append(AskHistoryRoute())
                    } label: {
                        Image(systemName: "clock")
                            .font(.system(size: 17, weight: .medium))
                            .frame(width: 44, height: 44)
                            .askGlass(in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Your questions")
                })

                if let daily = viewModel.question {
                    DailyQuestionCard(daily: daily) {
                        path.append(AskRoute(question: daily.question))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                } else if !viewModel.didFail {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .frame(height: 360)
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                }

                if let topics = viewModel.home?.topics, !topics.isEmpty {
                    Text("Explore")
                        .font(.system(size: 21, weight: .medium, design: .serif))
                        .padding(.horizontal, 22)
                        .padding(.top, 26)
                        .padding(.bottom, 12)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(topics) { topic in
                                TopicTile(topic: topic) {
                                    compose = ComposeRequest(suggestions: topic.questions)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.paper)
        .safeAreaInset(edge: .bottom) {
            Button {
                compose = ComposeRequest(suggestions: viewModel.suggestions)
            } label: {
                HStack {
                    Text("What’s on your mind?")
                        .font(.system(size: 18, design: .serif).italic())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.paper)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.primary))
                }
                .padding(.leading, 20)
                .padding(.trailing, 7)
                .frame(height: 54)
                .contentShape(Capsule())
                .askGlass(in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .editorialNavigationBar()
        .task { await viewModel.load() }
        // A new question every time the tab opens; the first one comes with `load()`
        .onAppear { viewModel.showNextQuestion() }
        .fullScreenCover(item: $compose) { request in
            AskComposeView(suggestions: request.suggestions) { question in
                compose = nil
                path.append(AskRoute(question: question))
            }
        }
        // Conversations from here and from history, and the books their answers cite
        .navigationDestination(for: AskRoute.self) { route in
            AskConversationView(route: route)
        }
        .navigationDestination(for: BookRoute.self) { route in
            BookDetailView(book: route.book)
        }
        .navigationDestination(for: AskHistoryRoute.self) { _ in
            AskHistoryView()
        }
    }
}

/// The featured question on a dark card, with the books that answer it fanned above
private struct DailyQuestionCard: View {
    let daily: AskHome.Daily
    let open: () -> Void
    @State private var tint: Color = .clear

    var body: some View {
        Button(action: open) {
            VStack(spacing: 0) {
                HStack {
                    Text("Try asking".uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.62))
                    Spacer()
                }
                CoverFan(books: Array(daily.books.prefix(3)), width: 96)
                    .padding(.top, 10)
                Text(daily.question)
                    .font(.system(size: 25, weight: .regular, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .padding(.top, 16)
                    .padding(.horizontal, 8)
                HStack(spacing: 6) {
                    Text("See the answer")
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.11, green: 0.10, blue: 0.09))
                .padding(.horizontal, 18)
                .frame(height: 40)
                .background(Capsule().fill(Color(red: 0.98, green: 0.97, blue: 0.96)))
                .padding(.top, 18)
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    Color(red: 0.11, green: 0.10, blue: 0.09)
                    tint.opacity(0.3)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Try asking: \(daily.question)")
        .accessibilityHint("Shows the answer")
        .task(id: daily.books.first?.id) {
            if let color = await CoverTint.color(for: daily.books.first?.coverAssetName) {
                withAnimation(.easeOut(duration: 0.4)) { tint = color }
            }
        }
    }
}

/// One Explore topic: its name over a light wash of its books' colour, covers peeking from the corner
private struct TopicTile: View {
    let topic: AskHome.Topic
    let open: () -> Void
    @State private var tint: Color = .primary

    var body: some View {
        Button(action: open) {
            ZStack(alignment: .topLeading) {
                tint.opacity(0.14)
                Text(topic.name)
                    .font(.system(size: 19, weight: .medium, design: .serif))
                    .padding(.horizontal, 15)
                    .padding(.top, 13)
                CoverFan(books: Array(topic.books.prefix(3).reversed()), width: 44)
                    .position(x: 104, y: 88)
            }
            .frame(width: 150, height: 118)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(topic.name)
        .task(id: topic.books.last?.id) {
            if let color = await CoverTint.color(for: topic.books.last?.coverAssetName) {
                tint = color
            }
        }
    }
}
