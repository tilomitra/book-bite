import SwiftUI
import UIKit

/// The invite code on a library card, and nothing else: cream card stock with a punched hole and the
/// code typed into six boxes. A physical object, the same in light and dark mode; ink is its only colour.
/// It drops in on appear, floats slowly, tilts under a drag with a moving light and shadow, and copies
/// the code on tap.
struct LibraryCard: View {
    let code: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Tilt from the finger, -1...1 on each axis
    @State private var drag: CGSize = .zero
    @State private var isDragging = false
    @State private var hasAppeared = false
    @State private var copies = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            card(idle: reduceMotion ? .zero : Self.idleTilt(at: context.date))
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.62).delay(0.1)) {
                hasAppeared = true
            }
        }
        .sensoryFeedback(.success, trigger: copies)
    }

    /// A slow drift, so the card reads as an object before anyone touches it
    private static func idleTilt(at date: Date) -> CGSize {
        let t = date.timeIntervalSinceReferenceDate
        return CGSize(width: sin(t * 0.7) * 0.22, height: cos(t * 0.9) * 0.16)
    }

    private func card(idle: CGSize) -> some View {
        let tilt = CGSize(width: drag.width + idle.width, height: drag.height + idle.height)
        return CardFace(code: code, tilt: tilt, copied: copies > 0)
            .aspectRatio(2.1, contentMode: .fit)
            .rotation3DEffect(.degrees(-tilt.height * 14), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(tilt.width * 18), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .scaleEffect(isDragging ? 1.04 : 1)
            // The shadow falls away from the light, further when lifted
            .shadow(color: .black.opacity(isDragging ? 0.3 : 0.22), radius: isDragging ? 24 : 16,
                    x: -tilt.width * 10, y: (isDragging ? 22 : 14) - tilt.height * 6)
            // Entrance: dropped onto the table, then settles
            .rotation3DEffect(.degrees(hasAppeared ? 0 : 40), axis: (x: 1, y: 0, z: 0.15), perspective: 0.5)
            .offset(y: hasAppeared ? 0 : 50)
            .opacity(hasAppeared ? 1 : 0)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !reduceMotion else { return }
                        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8)) {
                            isDragging = true
                            drag = CGSize(width: Self.clamp(value.translation.width / 110),
                                          height: Self.clamp(value.translation.height / 70))
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.45)) {
                            isDragging = false
                            drag = .zero
                        }
                    }
            )
            .onTapGesture(perform: copy)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Invite code \(code.map(String.init).joined(separator: " "))")
            .accessibilityHint("Copies the code")
            .accessibilityAddTraits(.isButton)
    }

    private func copy() {
        UIPasteboard.general.string = code
        copies += 1
    }

    private static func clamp(_ value: CGFloat) -> CGFloat { min(1, max(-1, value)) }
}

// MARK: - Card stock

private enum CardInk {
    static let stock = Color(red: 0.953, green: 0.918, blue: 0.835)
    static let edge = Color(red: 0.85, green: 0.80, blue: 0.68)
    static let ink = Color(red: 0.165, green: 0.129, blue: 0.114)
    static let rule = ink.opacity(0.22)
}

/// The card: stock with fibres, a thick edge underneath, a punched hole, a light that moves with
/// the tilt, and the code in typed boxes. Tapped, a small "Copied" shows under the code.
private struct CardFace: View {
    let code: String
    let tilt: CGSize
    let copied: Bool

    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Array(code.enumerated()), id: \.offset) { _, character in
                    Text(String(character))
                        .font(.custom("AmericanTypewriter-Bold", fixedSize: 30))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(CardInk.rule, lineWidth: 1))
                }
            }
            Text(copied ? "Copied" : "Tap to copy")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(CardInk.ink.opacity(0.4))
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: copied)
        }
        .foregroundStyle(CardInk.ink)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                CardInk.stock
                CardFibres()
                RadialGradient(
                    colors: [.white.opacity(0.55), .white.opacity(0)],
                    center: UnitPoint(x: 0.5 + tilt.width * 0.45, y: 0.35 + tilt.height * 0.45),
                    startRadius: 0, endRadius: 240
                )
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.6), lineWidth: 0.5))
        .mask {
            // The punched hole for a key ring
            Rectangle()
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .frame(width: 12, height: 12)
                        .padding(.top, 12)
                        .padding(.trailing, 14)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
        }
        // Card thickness: a darker edge just below, which also shows as the wall of the hole
        .background(shape.fill(CardInk.edge).offset(y: 3))
        .overlay(alignment: .topTrailing) {
            Circle()
                .strokeBorder(CardInk.ink.opacity(0.12), lineWidth: 2.5)
                .frame(width: 17, height: 17)
                .padding(.top, 9.5)
                .padding(.trailing, 11.5)
        }
        .environment(\.colorScheme, .light)
    }
}

/// Faint diagonal fibres in the stock
private struct CardFibres: View {
    var body: some View {
        Canvas { context, size in
            var x: CGFloat = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height * 0.47, y: 0))
                context.stroke(path, with: .color(Color(red: 0.47, green: 0.35, blue: 0.2).opacity(0.035)), lineWidth: 1.5)
                x += 4.5
            }
        }
        .accessibilityHidden(true)
    }
}
