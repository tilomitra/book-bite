import SwiftUI

/// Settings → Topics & Goals: the onboarding answers, editable later with the same chips.
/// Saved when the screen closes; Discover then rebuilds its shelves (`OnboardingPreferences.didChange`).
struct InterestsView: View {
    @State private var genres = Set(OnboardingPreferences.preferredGenres)
    @State private var goals = Set(OnboardingPreferences.readingGoals)

    /// "3 topics · 2 goals", for the row in Settings
    static func summary() -> String {
        let topics = OnboardingPreferences.preferredGenres.count
        let goals = OnboardingPreferences.readingGoals.count
        guard topics + goals > 0 else { return "None" }
        let parts = [
            topics > 0 ? "\(topics) \(topics == 1 ? "topic" : "topics")" : nil,
            goals > 0 ? "\(goals) \(goals == 1 ? "goal" : "goals")" : nil
        ]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                group(title: "Topics", caption: "Picked topics come first on Discover.") {
                    ForEach(Array(OnboardingPreferences.topics.enumerated()), id: \.element.genre) { index, topic in
                        TopicChip(title: topic.label, systemImage: topic.icon,
                                  isSelected: genres.contains(topic.genre),
                                  appearDelay: Double(index) * 0.02) {
                            genres.formSymmetricDifference([topic.genre])
                        }
                    }
                }

                group(title: "Goals", caption: "Each goal can add a shelf of books for it.") {
                    ForEach(Array(OnboardingPreferences.goals.enumerated()), id: \.element.id) { index, goal in
                        TopicChip(title: goal.label, systemImage: goal.icon,
                                  isSelected: goals.contains(goal.id),
                                  appearDelay: Double(index) * 0.02) {
                            goals.formSymmetricDifference([goal.id])
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Topics & Goals")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: genres)
        .sensoryFeedback(.selection, trigger: goals)
        .onDisappear(perform: save)
    }

    private func group<Chips: View>(title: String, caption: String,
                                    @ViewBuilder chips: () -> Chips) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 24, weight: .medium, design: .serif))
                .accessibilityAddTraits(.isHeader)
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            FlowLayout(spacing: 10) {
                chips()
            }
            .padding(.top, 16)
        }
    }

    /// Keeps the lists in the order they're offered, like onboarding does
    private func save() {
        let newGenres = OnboardingPreferences.topics.map(\.genre).filter { genres.contains($0) }
        let newGoals = OnboardingPreferences.goals.map(\.id).filter { goals.contains($0) }
        guard newGenres != OnboardingPreferences.preferredGenres || newGoals != OnboardingPreferences.readingGoals
        else { return }

        OnboardingPreferences.preferredGenres = newGenres
        OnboardingPreferences.readingGoals = newGoals
        NotificationCenter.default.post(name: OnboardingPreferences.didChange, object: nil)
    }
}

#Preview {
    NavigationStack {
        InterestsView()
    }
}
