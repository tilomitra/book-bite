import SwiftUI

/// "What are you curious about?": the picked topics come first in Discover and seed recommendations.
struct TopicsView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnboardingIconTile(systemImage: "sparkle.magnifyingglass")
                        .padding(.top, 32)

                    Text("What are you curious about?")
                        .font(.system(size: 34, weight: .medium, design: .serif))
                        .tracking(-0.6)
                        .padding(.top, 20)
                        .accessibilityAddTraits(.isHeader)

                    Text("Pick a few topics. We'll use them to find books for you.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)

                    FlowLayout(spacing: 10) {
                        ForEach(Array(OnboardingPreferences.topics.enumerated()), id: \.element.genre) { index, topic in
                            TopicChip(title: topic.label,
                                      systemImage: topic.icon,
                                      isSelected: viewModel.selectedGenres.contains(topic.genre),
                                      appearDelay: Double(index) * 0.03) {
                                viewModel.toggle(topic.genre)
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
                OnboardingPrimaryButton(title: viewModel.selectedGenres.isEmpty
                                        ? "Continue"
                                        : "Continue with \(viewModel.selectedGenres.count)") {
                    viewModel.saveTopics()
                    viewModel.step = .goals
                }
                .disabled(viewModel.selectedGenres.isEmpty)
                .opacity(viewModel.selectedGenres.isEmpty ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedGenres.isEmpty)

                Button("Skip") { viewModel.step = .goals }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .padding(.horizontal, 24)
            .background(Color.paper)
        }
        .sensoryFeedback(.selection, trigger: viewModel.selectedGenres)
    }
}

/// Selectable capsule with an icon, used for topics and goals.
struct TopicChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let appearDelay: Double
    let action: () -> Void
    @State private var appeared = false

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                // Fixed width so swapping in the checkmark doesn't resize the chip and reflow the rows
                Image(systemName: isSelected ? "checkmark" : systemImage)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 22)
            }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background {
                    Capsule().fill(isSelected ? Color.primary : Color(.systemBackground))
                }
                .overlay {
                    Capsule().strokeBorder(Color.primary.opacity(isSelected ? 0 : 0.1), lineWidth: 1)
                }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15 + appearDelay)) { appeared = true }
        }
    }
}

/// Lays children out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            if !row.indices.isEmpty, row.width + spacing + size.width > maxWidth {
                let y = row.y + row.height + spacing
                rows.append(Row(y: y))
                row = rows[rows.count - 1]
            }
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
