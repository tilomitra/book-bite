import SwiftUI

/// The next milestone with a progress bar, then the friends who joined with the code and when.
/// A dashed panel, like a slip tucked into the card's pocket.
struct InviteProgressPanel: View {
    let invite: ReadingPass.Invite

    private var joined: Int { invite.friendsJoined }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            nextMilestone

            DashedRule()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Friends who joined")
                        .font(.headline)
                    Spacer()
                    Label("\(joined)", systemImage: "person.fill")
                        .font(.headline.monospacedDigit())
                        .contentTransition(.numericText())
                        .accessibilityLabel(joined == 1 ? "1 friend" : "\(joined) friends")
                }
                .accessibilityElement(children: .combine)

                if joined == 0 {
                    Text("No one yet. When a friend joins with your code, they show up here and you both get 5 books.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(friendRows, id: \.number) { row in
                        FriendRow(number: row.number, joinedAt: row.joinedAt)
                    }
                    if joined > friendRows.count {
                        Text("and \(joined - friendRows.count) more")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: joined)
    }

    @ViewBuilder
    private var nextMilestone: some View {
        if let next = InviteMilestone.next(after: joined) {
            HStack(spacing: 16) {
                BookStackTile(friends: next.friends, reached: false, size: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Next: \(next.title)")
                        .font(.system(.title3, design: .serif).weight(.medium))
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(next.books) books in all")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(joined)/\(next.friends)")
                            .font(.subheadline.monospacedDigit())
                            .contentTransition(.numericText())
                    }
                    ProgressCapsule(fraction: InviteMilestone.progress(friendsJoined: joined))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Next milestone: \(next.title). \(joined) of \(next.friends) friends.")
        } else {
            HStack(spacing: 16) {
                BookStackTile(friends: invite.maxFriends, reached: true, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Every milestone reached")
                        .font(.system(.title3, design: .serif).weight(.medium))
                    Text("Thank you for sharing Bookgist.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// Newest first, the latest five. Rows without a date (older servers) show the number only.
    private var friendRows: [(number: Int, joinedAt: Date?)] {
        let dates = invite.friends?.map(\.joinedAt) ?? []
        let count = max(dates.count, min(joined, invite.maxFriends))
        return (0..<count).reversed().prefix(5).map { index in
            (number: index + 1, joinedAt: index < dates.count ? dates[index] : nil)
        }
    }
}

/// One friend: a small "+5" stamp, "Friend 3", and the day they joined
private struct FriendRow: View {
    let number: Int
    let joinedAt: Date?

    var body: some View {
        HStack(spacing: 14) {
            Text("+5")
                .font(.system(.caption, design: .serif).weight(.semibold))
                .frame(width: 36, height: 36)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.7), lineWidth: 1.5))
                .rotationEffect(.degrees(number.isMultiple(of: 2) ? 8 : -8))
            Text("Friend \(number)")
                .font(.body)
            Spacer(minLength: 8)
            if let joinedAt {
                Text("Joined \(joinedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// The milestones as a ladder of cards, each with a growing stack of books, linked by arrows.
/// Reached ones are inked in with a check; the rest wait in grey with how far there is to go.
struct MilestoneLadder: View {
    let friendsJoined: Int

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(InviteMilestone.all.enumerated()), id: \.element.id) { index, milestone in
                if index > 0 {
                    Image(systemName: "arrow.down")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                MilestoneCard(milestone: milestone, friendsJoined: friendsJoined)
            }
        }
    }
}

private struct MilestoneCard: View {
    let milestone: InviteMilestone
    let friendsJoined: Int

    private var reached: Bool { friendsJoined >= milestone.friends }

    var body: some View {
        HStack(spacing: 16) {
            BookStackTile(friends: milestone.friends, reached: reached, size: 84)
            VStack(alignment: .leading, spacing: 5) {
                Text(milestone.friends == 1 ? "1 FRIEND" : "\(milestone.friends) FRIENDS")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(milestone.title)
                    .font(.system(.title3, design: .serif).weight(.medium))
                Text("\(milestone.books) books earned")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                status
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(reached ? 0.3 : 0.12), lineWidth: reached ? 1 : 0.5)
        }
        .opacity(reached ? 1 : 0.75)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var status: some View {
        if reached {
            Label("Reached", systemImage: "checkmark")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.08), in: Capsule())
        } else {
            Text("\(min(friendsJoined, milestone.friends))/\(milestone.friends) friends")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// A square tile with a stack of books, one spine per friend (up to 10), drawn in ink.
/// Reached stacks are solid; others are outlines.
struct BookStackTile: View {
    let friends: Int
    let reached: Bool
    let size: CGFloat

    /// Fixed heights and widths per position, so every stack looks hand-placed
    private static let heights: [CGFloat] = [0.62, 0.74, 0.56, 0.7, 0.66, 0.78, 0.6, 0.72, 0.58, 0.68]
    private static let widths: [CGFloat] = [0.1, 0.08, 0.12, 0.09, 0.1, 0.08, 0.11, 0.09, 0.1, 0.08]

    var body: some View {
        let count = max(1, min(friends, 10))
        // Wider spines for small stacks, so one book doesn't look lost
        let scale: CGFloat = count <= 3 ? 1.5 : (count <= 5 ? 1.15 : 0.75)
        HStack(alignment: .bottom, spacing: size * 0.012) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: size * 0.015)
                    .fill(Color.primary.opacity(reached ? 0.85 - Double(index % 3) * 0.15 : 0))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.015)
                            .strokeBorder(Color.primary.opacity(reached ? 0 : 0.35), lineWidth: 1)
                    }
                    .frame(width: size * Self.widths[index] * scale, height: size * Self.heights[index] * 0.85)
            }
        }
        .padding(.bottom, size * 0.14)
        .frame(width: size, height: size, alignment: .bottom)
        // The shelf board
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(reached ? 0.7 : 0.25))
                .frame(width: size * 0.78, height: 1.5)
                .padding(.bottom, size * 0.14)
        }
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// A rounded progress bar: a faint track, the done part in ink
private struct ProgressCapsule: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(Color.primary)
                    .frame(width: max(6, proxy.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

private struct DashedRule: View {
    var body: some View {
        Line()
            .stroke(Color.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}
