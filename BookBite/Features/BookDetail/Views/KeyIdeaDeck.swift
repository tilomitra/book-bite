import SwiftUI

/// A book's key ideas as a real stack of cards. Swipe the top card off to the left (or use the chevrons)
/// and the next one rises into its place; swipe right to bring the last card back. Each card can be kept in
/// the notebook or shared as a typeset quote image.
///
/// Every card's place comes from one number, `deckPosition`, so a card follows the finger and finishes
/// the same way whether it was dragged or turned with a chevron. All cards share the height of the tallest,
/// which grows with its text and Dynamic Type instead of clipping.
struct KeyIdeaDeck: View {
    let ideas: [KeyIdea]
    let book: Book
    /// The cover's colour, for the share image; nil until it has loaded
    let tint: Color?

    @ObservedObject private var savedIdeas = SavedIdeasStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var minCardHeight: CGFloat = 230
    @AccessibilityFocusState private var focusedCard: Int?

    /// Index of the top card
    @State private var current = 0
    /// How far the top card has been dragged, in cards: 1 = gone left, -1 = the previous card fully back
    @State private var dragProgress: CGFloat = 0
    @State private var deckWidth: CGFloat = 0
    @State private var cover: UIImage?
    @State private var coverLoaded = false
    @State private var shareImage: RenderedShare?

    private var resolvedTint: Color { tint ?? Color(TypographicCover.cloth(for: book.title)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                ForEach(ideas.indices, id: \.self) { index in
                    stacked(index)
                }
            }
            // Every card takes the tallest card's height
            .fixedSize(horizontal: false, vertical: true)
            // Room for the shadow above, and the edges of the cards underneath below
            .padding(.top, 8)
            .padding(.bottom, 26)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { deckWidth = $0 }
            .gesture(HorizontalPan(canStart: canTurn, onChanged: dragged, onEnded: released))
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: current)

            if ideas.count > 1 {
                pager
            }
        }
        .task {
            cover = await IdeaShareCard.loadCover(for: book)
            coverLoaded = true
        }
        .task(id: renderKey) {
            renderShareImage()
        }
    }

    // MARK: - Stack

    /// Far enough for a card to clear the screen edge
    private var throwDistance: CGFloat { deckWidth + 60 }
    private var deckPosition: CGFloat { CGFloat(current) + dragProgress }

    private func stacked(_ index: Int) -> some View {
        // Above zero the card is that many places under the top; below zero it has left the stack
        let place = CGFloat(index) - deckPosition
        let under = max(place, 0)
        let gone = min(place, 0)
        // With Reduce Motion the turning card only fades
        let moves = !reduceMotion

        return card(index)
            .scaleEffect(moves ? 1 - min(under, 3) * 0.04 : 1, anchor: .bottom)
            .offset(y: moves ? min(under, 3) * 8 : 0)
            .rotationEffect(.degrees(moves ? Double(gone) * 10 : 0), anchor: .bottom)
            .offset(x: moves ? gone * throwDistance : 0)
            // Two cards show under the top one; the rest wait out of sight
            .opacity(Double(moves ? 1 : 1 + gone) * Double(min(1, max(0, 3 - place))))
            .zIndex(Double(-index))
            .allowsHitTesting(index == current)
            // VoiceOver sees only the top card; the adjustable action turns it
            .accessibilityHidden(index != current)
    }

    /// On the first card a swipe right has nothing to bring back, so it stays the system's back gesture
    private func canTurn(rightward: Bool) -> Bool {
        rightward ? current > 0 : current < ideas.count - 1
    }

    private func dragged(by translation: CGFloat) {
        guard throwDistance > 0 else { return }
        let progress = -translation / throwDistance
        dragProgress = canTurn(rightward: progress < 0) ? progress : progress * 0.12
    }

    private func released(translation: CGFloat, velocity: CGFloat) {
        let flung = translation + velocity * 0.2
        var target = current
        if abs(flung) > deckWidth * 0.3 {
            target = min(max(current + (flung < 0 ? 1 : -1), 0), ideas.count - 1)
        }
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.35)) {
            current = target
            dragProgress = 0
        }
    }

    private func card(_ index: Int) -> some View {
        let idea = ideas[index]
        return VStack(alignment: .leading, spacing: 0) {
            Text(KeyIdeaText.attributed(idea.idea))
                .font(.system(.title3, design: .serif))
                .lineSpacing(5)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Key idea. \(idea.idea)")
                .accessibilityValue("\(index + 1) of \(ideas.count)")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: move(by: 1, announce: true)
                    case .decrement: move(by: -1, announce: true)
                    @unknown default: break
                    }
                }
                .accessibilityFocused($focusedCard, equals: index)

            Spacer(minLength: 24)

            HStack(alignment: .center) {
                keepButton(for: idea)
                Spacer(minLength: 12)
                shareButton(for: index)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, minHeight: minCardHeight, maxHeight: .infinity, alignment: .topLeading)
        .background {
            Self.cardShape
                .fill(Self.cardSurface)
                .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
        }
        .overlay { Self.cardShape.stroke(Color.primary.opacity(0.07), lineWidth: 0.5) }
    }

    // MARK: - Actions on a card

    private func keepButton(for idea: KeyIdea) -> some View {
        let kept = savedIdeas.isSaved(bookId: book.id, text: idea.idea)
        return Button {
            savedIdeas.toggle(idea.idea, ideaId: idea.id, book: book)
        } label: {
            Label {
                Text(kept ? "Kept" : "Keep")
            } icon: {
                Image(systemName: kept ? "bookmark.fill" : "bookmark")
                    .contentTransition(.symbolEffect(.replace))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(kept ? Color.primary : Color.secondary)
            .padding(.vertical, 10)
            .padding(.trailing, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: kept)
        .sensoryFeedback(trigger: kept) { _, isKept in
            isKept ? .impact(flexibility: .soft, intensity: 0.7) : .selection
        }
        .accessibilityLabel(kept ? "Kept in your notebook" : "Keep idea")
        .accessibilityHint(kept ? "Removes it from your notebook" : "Saves it to your notebook")
    }

    @ViewBuilder
    private func shareButton(for index: Int) -> some View {
        let icon = Image(systemName: "square.and.arrow.up")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())

        if let shareImage, shareImage.key.index == index, shareImage.key == renderKey {
            ShareLink(
                item: shareImage.item,
                preview: SharePreview("A key idea from \(book.shelfTitle)", image: Image(uiImage: shareImage.item.image))
            ) {
                icon
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share idea as an image")
        } else {
            // The image renders as soon as the cover has loaded: a moment at most
            icon
                .opacity(0.4)
                .accessibilityLabel("Share idea as an image")
                .accessibilityAddTraits(.isButton)
                .accessibilityRemoveTraits(.isImage)
                .accessibilityValue("Preparing")
        }
    }

    // MARK: - Pager

    private var pager: some View {
        HStack(spacing: 4) {
            Text("\(current + 1) of \(ideas.count)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(current)))
                .animation(reduceMotion ? nil : .snappy, value: current)
                // The card's accessibility value already says where you are
                .accessibilityHidden(true)

            Spacer()

            pagerButton("chevron.left", label: "Previous idea", disabled: current == 0) { move(by: -1) }
            pagerButton("chevron.right", label: "Next idea", disabled: current >= ideas.count - 1) { move(by: 1) }
        }
    }

    private func pagerButton(_ symbol: String, label: String, disabled: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1)
        .accessibilityLabel(label)
    }

    private func move(by delta: Int, announce: Bool = false) {
        let target = min(max(current + delta, 0), ideas.count - 1)
        guard target != current else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.4)) {
            current = target
        }
        if announce {
            // Follow the top card with VoiceOver: the old card is now hidden
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                focusedCard = target
            }
        }
    }

    // MARK: - Share image

    private struct RenderKey: Hashable {
        let index: Int
        let coverLoaded: Bool
        let tint: Color
    }

    private struct RenderedShare {
        let key: RenderKey
        let item: IdeaQuoteImage
    }

    private var renderKey: RenderKey {
        RenderKey(index: current, coverLoaded: coverLoaded, tint: resolvedTint)
    }

    /// Renders the current card's quote image once the cover is in, so tapping Share opens the sheet at once.
    private func renderShareImage() {
        guard coverLoaded, ideas.indices.contains(current) else { return }
        let key = renderKey
        let idea = ideas[key.index].idea
        guard let image = IdeaShareCard.render(idea: idea, book: book, tint: key.tint, cover: cover) else { return }
        let fileName = "\(book.shelfTitle) – idea \(key.index + 1)"
        shareImage = RenderedShare(key: key, item: IdeaQuoteImage(image: image, fileName: fileName))
    }

    // MARK: - Style

    private static let cardShape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    /// A sheet a shade lighter than the page: warm white on paper, lifted charcoal in dark mode.
    private static let cardSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 30 / 255, green: 29 / 255, blue: 27 / 255, alpha: 1)
            : UIColor(red: 255 / 255, green: 254 / 255, blue: 251 / 255, alpha: 1)
    })
}

/// A pan that starts only on a mostly sideways drag the deck can use, so a vertical swipe on a card
/// still scrolls the page. It goes before the navigation stack's swipe back, which covers the whole screen.
private struct HorizontalPan: UIGestureRecognizerRepresentable {
    let canStart: (_ rightward: Bool) -> Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.canStart = canStart
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed:
            onChanged(translation)
        case .ended:
            onEnded(translation, recognizer.velocity(in: recognizer.view).x)
        case .cancelled, .failed:
            onEnded(0, 0)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var canStart: (_ rightward: Bool) -> Bool = { _ in true }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) && canStart(velocity.x > 0)
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            !(other.view is UIScrollView)
        }
    }
}
