import SwiftUI

/// First-run flow: welcome + sign up (optional), topics, reading goals, books you've loved,
/// then the daily idea notification prompt. The taste answers drive Discover's personal shelves.
/// Shown by `BookBiteApp` until `OnboardingPreferences.completedKey` is set.
struct OnboardingView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    @StateObject private var viewModel: OnboardingViewModel
    @AppStorage(OnboardingPreferences.completedKey) private var hasCompletedOnboarding = false

    init(bookRepository: BookRepository) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(bookRepository: bookRepository))
    }

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()

            switch viewModel.step {
            case .welcome:
                WelcomeView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            case .topics:
                TopicsView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            case .goals:
                GoalsView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            case .books:
                LovedBooksView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            case .notifications:
                NotificationsPromptView(viewModel: viewModel) {
                    Analytics.capture(.onboardingCompleted(
                        topics: OnboardingPreferences.preferredGenres.count,
                        goals: OnboardingPreferences.readingGoals.count,
                        likedBooks: OnboardingPreferences.likedBookIds.count
                    ))
                    withAnimation(.easeInOut(duration: 0.4)) { hasCompletedOnboarding = true }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: viewModel.step)
        .task { await viewModel.load() }
    }
}

// MARK: - Shared pieces

/// Large black capsule used for the main action on each onboarding screen.
struct OnboardingPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(Color(.systemBackground))
                } else {
                    Label {
                        Text(title)
                    } icon: {
                        if let systemImage { Image(systemName: systemImage) }
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.primary, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Light grey capsule for secondary choices.
struct OnboardingSecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                if let systemImage { Image(systemName: systemImage) }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Icon in a soft circle above a screen's title.
struct OnboardingIconTile: View {
    let systemImage: String
    var size: CGFloat = 64

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.4, weight: .regular))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .background(Color.primary.opacity(0.06), in: Circle())
            .accessibilityHidden(true)
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The Bookgist mark: a serif "B" in a black disc.
struct BookBiteMark: View {
    var size: CGFloat = 64

    var body: some View {
        Text("B")
            .font(.system(size: size * 0.52, weight: .semibold, design: .serif))
            .foregroundStyle(Color(.systemBackground))
            .frame(width: size, height: size)
            .background(Color.primary, in: Circle())
            .accessibilityHidden(true)
    }
}
