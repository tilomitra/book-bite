import SwiftUI
import UIKit

/// The invite code on a library card, as a physical object: cream card stock with a punched hole,
/// the code typed into boxes, a barcode, and on the back a stamp for each friend who joined.
/// It floats slightly, tilts under the finger with a light moving across it, and turns over on tap.
/// The card is the same in light and dark mode, like a real one; its ink is the only colour.
struct LibraryCard: View {
    let invite: ReadingPass.Invite

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Tilt from the finger, -1...1 on each axis
    @State private var drag: CGSize = .zero
    @State private var isDragging = false
    /// 0 = front; each turn adds 180
    @State private var flipAngle: Double = 0
    @State private var hasAppeared = false
    @State private var copied = false

    private var showsBack: Bool { cardShowsBack(at: flipAngle) }

    var body: some View {
        VStack(spacing: 18) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                card(idle: reduceMotion ? .zero : Self.idleTilt(at: context.date))
            }
            .frame(maxWidth: 380)
            .frame(maxWidth: .infinity)

            controls
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.62).delay(0.1)) {
                hasAppeared = true
            }
        }
        .onChange(of: invite.friendsJoined) { old, new in
            // A friend joined: turn to the stamps so the new one lands in view
            if new > old && !showsBack { turnOver() }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: invite.friendsJoined)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: flipAngle)
        .sensoryFeedback(.success, trigger: copied) { _, new in new }
    }

    /// A slow drift, so the card reads as an object before anyone touches it
    private static func idleTilt(at date: Date) -> CGSize {
        let t = date.timeIntervalSinceReferenceDate
        return CGSize(width: sin(t * 0.7) * 0.22, height: cos(t * 0.9) * 0.16)
    }

    private func card(idle: CGSize) -> some View {
        let tilt = CGSize(width: drag.width + idle.width, height: drag.height + idle.height)
        return FlipCard(
            angle: flipAngle,
            front: LibraryCardFront(invite: invite, tilt: tilt),
            back: LibraryCardBack(invite: invite, tilt: tilt)
        )
        .aspectRatio(1.586, contentMode: .fit)
        .rotation3DEffect(.degrees(-tilt.height * 12), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        .rotation3DEffect(.degrees(tilt.width * 16), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .scaleEffect(isDragging ? 1.03 : 1)
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
                                      height: Self.clamp(value.translation.height / 90))
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.45)) {
                        isDragging = false
                        drag = .zero
                    }
                }
        )
        .onTapGesture(perform: turnOver)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Turns the card over")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Copy code", copy)
    }

    private var controls: some View {
        HStack(spacing: 24) {
            Button(action: copy) {
                Label(copied ? "Copied" : "Copy code", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
            }
            Button(action: turnOver) {
                Label(showsBack ? "Front" : "Stamps", systemImage: "rectangle.2.swap")
            }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .frame(minHeight: 32)
    }

    private func turnOver() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.7, dampingFraction: 0.72)) {
            flipAngle += 180
        }
    }

    private func copy() {
        UIPasteboard.general.string = invite.code
        copied = true
    }

    private var accessibilityLabel: String {
        let spelled = invite.code.map(String.init).joined(separator: " ")
        let friends = invite.friendsJoined == 1 ? "1 friend joined" : "\(invite.friendsJoined) friends joined"
        return "Library card. Invite code \(spelled). \(friends)."
    }

    private static func clamp(_ value: CGFloat) -> CGFloat { min(1, max(-1, value)) }
}

// MARK: - Flip

/// True while the card's back faces the reader (between a quarter and three quarters of a turn)
private func cardShowsBack(at angle: Double) -> Bool {
    let turned = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    return turned > 90 && turned < 270
}

/// Two faces back to back. Animatable, so the face swaps exactly when the card is edge-on.
private struct FlipCard<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let front: Front
    let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    init(angle: Double, front: Front, back: Back) {
        self.angle = angle
        self.front = front
        self.back = back
    }

    var body: some View {
        let isBack = cardShowsBack(at: angle)
        ZStack {
            front.opacity(isBack ? 0 : 1)
            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isBack ? 1 : 0)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }
}

// MARK: - Card stock

private enum CardInk {
    static let stock = Color(red: 0.953, green: 0.918, blue: 0.835)
    static let edge = Color(red: 0.85, green: 0.80, blue: 0.68)
    static let ink = Color(red: 0.165, green: 0.129, blue: 0.114)
    static let soft = ink.opacity(0.55)
    static let rule = ink.opacity(0.22)

    static func typewriter(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "AmericanTypewriter-Bold" : "AmericanTypewriter", fixedSize: size)
    }

    static func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 8.5, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(soft)
    }
}

/// One face of the card: stock with fibres, a thick edge underneath, the punched hole, and a light
/// that moves with the tilt
private struct CardFace<Content: View>: View {
    let tilt: CGSize
    @ViewBuilder let content: Content

    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        content
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                            .frame(width: 14, height: 14)
                            .padding(.top, 14)
                            .padding(.trailing, 16)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            // Card thickness: a darker edge just below, which also shows as the wall of the hole
            .background(shape.fill(CardInk.edge).offset(y: 3))
            .overlay(alignment: .topTrailing) {
                // The hole's worn rim
                Circle()
                    .strokeBorder(CardInk.ink.opacity(0.12), lineWidth: 2.5)
                    .frame(width: 19, height: 19)
                    .padding(.top, 11.5)
                    .padding(.trailing, 13.5)
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

/// A thick rule over a thin one
private struct DoubleRule: View {
    var body: some View {
        VStack(spacing: 2) {
            Rectangle().frame(height: 1.5)
            Rectangle().frame(height: 0.75)
        }
        .foregroundStyle(CardInk.ink)
    }
}

// MARK: - Front

private struct LibraryCardFront: View {
    let invite: ReadingPass.Invite
    let tilt: CGSize

    private var friends: String {
        let joined = invite.friendsJoined
        if joined == 0 { return "none yet" }
        return "\(joined) joined · \(joined * ReadingPass.booksPerInvite) books"
    }

    var body: some View {
        CardFace(tilt: tilt) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("BookBite")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                        Text("PUBLIC LIBRARY · BORROWER'S CARD")
                            .font(.system(size: 8, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(CardInk.soft)
                    }
                    Spacer(minLength: 0)
                    LibrarySeal()
                        .padding(.trailing, 24)
                }

                DoubleRule().padding(.top, 8)

                CardInk.label("Invite No.").padding(.top, 10)
                HStack(spacing: 5) {
                    ForEach(Array(invite.code.enumerated()), id: \.offset) { _, character in
                        Text(String(character))
                            .font(CardInk.typewriter(24, bold: true))
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 3))
                            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(CardInk.rule, lineWidth: 1))
                    }
                }
                .padding(.top, 5)

                VStack(spacing: 0) {
                    field("Good for", "5 free books")
                    field("Friends", friends)
                }
                .padding(.top, 6)

                Spacer(minLength: 6)

                CardBarcode(code: invite.code)
                    .frame(height: 15)
            }
            .foregroundStyle(CardInk.ink)
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            CardInk.label(label)
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(CardInk.typewriter(13.5))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.top, 5)
        .padding(.bottom, 3)
        .overlay(alignment: .bottom) { Rectangle().fill(CardInk.rule).frame(height: 0.75) }
    }
}

/// The library's seal: a serif "B" in a double ring, stamped at an angle
private struct LibrarySeal: View {
    var body: some View {
        Text("B")
            .font(.system(size: 17, weight: .semibold, design: .serif).italic())
            .frame(width: 32, height: 32)
            .overlay(Circle().strokeBorder(CardInk.ink, lineWidth: 1.5))
            .padding(3)
            .overlay(Circle().strokeBorder(CardInk.ink, lineWidth: 0.75))
            .rotationEffect(.degrees(-12))
            .opacity(0.8)
    }
}

/// A pretend barcode, fixed per code: thin and thick bars from the code's characters
private struct CardBarcode: View {
    let code: String

    private var bars: [CGFloat] {
        (code + String(code.reversed())).unicodeScalars.flatMap { scalar in
            (0..<4).map { bit in (scalar.value >> UInt32(bit)) & 1 == 1 ? 3 : 1 }
        }
    }

    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            for width in bars where x < size.width {
                context.fill(Path(CGRect(x: x, y: 0, width: width, height: size.height)), with: .color(CardInk.ink.opacity(0.85)))
                x += width + 1.5
            }
        }
        .frame(width: 180)
        .accessibilityHidden(true)
    }
}

// MARK: - Back

/// "Friends who joined": a ruled slip with a "+5" stamp per friend, six to a side
private struct LibraryCardBack: View {
    let invite: ReadingPass.Invite
    let tilt: CGSize

    private static let perSide = 6
    private static let angles: [Double] = [-9, 6, -4, 10, -7, 5]

    /// Friends on the side showing now: the side being filled
    private var stampsHere: Int {
        let joined = min(invite.friendsJoined, invite.maxFriends)
        guard joined > 0 else { return 0 }
        return joined - (joined - 1) / Self.perSide * Self.perSide
    }

    private var note: String {
        let joined = invite.friendsJoined
        switch joined {
        case 0: return "Each friend who joins with your code earns a stamp: 5 books for them, 5 for you."
        case 1: return "1 friend joined · 5 books earned"
        default: return "\(joined) friends joined · \(joined * ReadingPass.booksPerInvite) books earned"
        }
    }

    var body: some View {
        CardFace(tilt: tilt) {
            VStack(spacing: 0) {
                Text("FRIENDS WHO JOINED")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.8)
                    .padding(.bottom, 6)
                    .padding(.trailing, 20)
                DoubleRule()

                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(0..<2, id: \.self) { row in
                        GridRow {
                            ForEach(0..<3, id: \.self) { column in
                                cell(row * 3 + column)
                            }
                        }
                    }
                }
                .overlay(Rectangle().strokeBorder(CardInk.rule, lineWidth: 0.75))
                .padding(.top, 8)

                Text(note)
                    .font(.system(size: 11.5, design: .serif))
                    .foregroundStyle(CardInk.soft)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 7)
            }
            .foregroundStyle(CardInk.ink)
        }
    }

    private func cell(_ index: Int) -> some View {
        ZStack {
            if index < stampsHere {
                JoinedStamp(angle: Self.angles[index % Self.angles.count])
                    .transition(.scale(scale: 2.2).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(Rectangle().strokeBorder(CardInk.rule, lineWidth: 0.375))
    }
}

/// A rubber stamp: "JOINED +5" in a rounded box, slightly crooked
private struct JoinedStamp: View {
    let angle: Double

    var body: some View {
        VStack(spacing: 0) {
            Text("JOINED")
            Text("+5")
        }
        .font(CardInk.typewriter(10.5, bold: true))
        .tracking(0.8)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(CardInk.ink, lineWidth: 1.8))
        .rotationEffect(.degrees(angle))
        .opacity(0.75)
    }
}
