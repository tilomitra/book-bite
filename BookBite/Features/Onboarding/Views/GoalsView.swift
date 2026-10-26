import SwiftUI

/// "What do you want from reading?": goals cut across genres, so they seed the "For you" shelves
/// and get a shelf of their own in Discover.
struct GoalsView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnboardingIconTile(systemImage: "scope")
                        .padding(.top, 32)

                    Text("What do you want from reading?")
                        .font(.system(size: 34, weight: .medium, design: .serif))
                        .tracking(-0.6)
                        .padding(.top, 20)
                        .accessibilityAddTraits(.isHeader)

                    Text("Pick as many as you like.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)

                    FlowLayout(spacing: 10) {
                        ForEach(Array(OnboardingPreferences.goals.enumerated()), id: \.element.id) { index, goal in
                            TopicChip(title: goal.label,
                                      systemImage: goal.icon,
                                      isSelected: viewModel.selectedGoals.contains(goal.id),
                                      appearDelay: Double(index) * 0.03) {
                                viewModel.toggleGoal(goal.id)
                            }
                        }
                    }
                    .padding(.top, 32)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 4) {
                OnboardingPrimaryButton(title: "Continue") {
                    viewModel.saveGoals()
                    next()
                }
                .disabled(viewModel.selectedGoals.isEmpty)
                .opacity(viewModel.selectedGoals.isEmpty ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedGoals.isEmpty)

                Button("Skip", action: next)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .padding(.horizontal, 24)
            .background(Color.paper)
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedGoals)
    }

    private func next() {
        // Offline there are no books to pick from
        viewModel.step = viewModel.popularBooks.isEmpty ? .notifications : .books
    }
}
