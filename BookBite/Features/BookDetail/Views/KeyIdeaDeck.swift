import SwiftUI

/// A book's key ideas as a deck of cards, one idea per page. Swipe (or use the chevrons) to turn;
/// each card can be kept in the notebook or shared as a typeset quote image.
///
/// Pages are full width so the scroll position is always exactly one card. The cards still under
/// the current one show as edges beneath it, so it reads as a deck. All pages share the height of the
/// tallest card, which grows with its text and Dynamic Type instead of clipping.
struct KeyIdeaDeck: View {
    let ideas: [KeyIdea]
    let book: Book
    /// The cover's colour, for the share image; nil until it has loaded
    let tint: Color?

    @ObservedObject private var savedIdeas = SavedIdeasStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var minCardHeight: CGFloat = 230
    @AccessibilityFocusState private var focusedCard: Int?

    @State private var position: Int? = 0
    @State private var cover: UIImage?
    @State private var coverLoaded = false
    @State private var shareImage: RenderedShare?

    private var current: Int { min(max(position ?? 0, 0), max(ideas.count - 1, 0)) }
    private var resolvedTint: Color { tint ?? Color(TypographicCover.cloth(for: book.title)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(ideas.indices, id: \.self) { index in
                        page(index)
                            .containerRelativeFrame(.horizontal)
                            .id(index)
                    }
                }
                // Every page takes the tallest card's height
                .fixedSize(horizontal: false, vertical: true)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $position)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: current)

            if ideas.count > 1 {
                pager
                    .padding(.horizontal, 20)
            }
        }
        // Bleed to the screen edges: each page pads its own card, so swiping uses the full width
        .padding(.horizontal, -20)
        .task {
            cover = await IdeaShareCard.loadCover(for: book)
            coverLoaded = true
        }
        .task(id: renderKey) {
            renderShareImage()
        }
    }

    // MARK: - Page

    private func page(_ index: Int) -> some View {
        // With Reduce Motion the turning card only fades
        let scales = !reduceMotion
        return card(index)
            .background(alignment: .bottom) { deckEdges(below: index) }
            .padding(.horizontal, 20)
            // Room for the shadow above, and the edges of the cards underneath below
            .padding(.top, 8)
            .padding(.bottom, 26)
            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.35)
                    .scaleEffect(phase.isIdentity || !scales ? 1 : 0.95)
            }
            // VoiceOver sees only the current card; the adjustable action turns the page
            .accessibilityHidden(index != current)
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

    /// The edges of up to two cards under this one, so the stack reads as a deck.
    private func deckEdges(below index: Int) -> some View {
        let remaining = min(2, ideas.count - 1 - index)
        return ZStack(alignment: .bottom) {
            ForEach(Array((0..<remaining).reversed()), id: \.self) { depth in
                let level = CGFloat(depth + 1)
                Self.cardShape
                    .fill(Self.cardSurface)
                    .overlay { Self.cardShape.stroke(Color.primary.opacity(0.06), lineWidth: 0.5) }
                    .opacity(1 - Double(depth) * 0.35)
                    .padding(.horizontal, 12 * level)
                    .offset(y: 6 * level)
            }
        }
        .accessibilityHidden(true)
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
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
            position = target
        }
        if announce {
            // Follow the page with VoiceOver: the old card is now hidden
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
