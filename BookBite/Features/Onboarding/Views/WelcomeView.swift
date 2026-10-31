import SwiftUI

/// Welcome screen: covers orbiting the Bookgist mark, the pitch, and Get Started, which raises the
/// sign-up sheet while the orbit slides up behind it.
struct WelcomeView: View {
    @EnvironmentObject var authService: SupabaseAuthService
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showAuthSheet = false
    @State private var startWithSignIn = false
    @State private var appeared = false
    @State private var wash: [Color] = []

    var body: some View {
        ZStack {
            CoverWash(colors: wash)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                OrbitHero(books: viewModel.books)
                    .mask {
                        LinearGradient(stops: [.init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                            // Let the outer ring spill past the top and sides; only the bottom fades
                            .padding(.top, -200)
                            .padding(.horizontal, -120)
                    }
                    .scaleEffect(showAuthSheet ? 0.9 : (appeared ? 1 : 0.85))
                    .offset(y: showAuthSheet ? -90 : 0)
                    .opacity(appeared ? 1 : 0)
                    .frame(maxHeight: .infinity)

                pitch
                    .opacity(showAuthSheet ? 0 : 1)
                    .offset(y: appeared ? 0 : 24)
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: showAuthSheet)
        .sheet(isPresented: $showAuthSheet) {
            OnboardingAuthSheet(authService: authService, startWithSignIn: startWithSignIn) {
                showAuthSheet = false
                viewModel.step = .topics
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1)) { appeared = true }
        }
        .task(id: viewModel.books.count) {
            var colors: [Color] = []
            for book in viewModel.books.prefix(3) {
                if let color = await CoverTint.color(for: book.coverAssetName) { colors.append(color) }
            }
            withAnimation(.easeInOut(duration: 1.2)) { wash = colors }
        }
    }

    private var pitch: some View {
        VStack(spacing: 0) {
            Text("Bookgist")
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.bottom, 14)

            Text("Great books,")
                .font(.system(size: 40, weight: .medium, design: .serif))
                .tracking(-0.8)
            Text("in fifteen minutes.")
                .font(.system(size: 40, weight: .regular, design: .serif))
                .italic()
                .tracking(-0.8)
                .foregroundStyle(.secondary)

            Text("Key ideas, audio and answers from the best non-fiction.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .padding(.horizontal, 32)

            OnboardingPrimaryButton(title: "Get Started") {
                startWithSignIn = false
                showAuthSheet = true
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)

            Button {
                startWithSignIn = true
                showAuthSheet = true
            } label: {
                (Text("Already have an account? ").foregroundStyle(.secondary) + Text("Sign in").fontWeight(.semibold))
                    .font(.subheadline)
            }
            .tint(.primary)
            .padding(.top, 18)
            .padding(.bottom, 8)
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Orbit hero

/// Book covers and feature icons on three slowly turning rings around the Bookgist mark.
struct OrbitHero: View {
    let books: [Book]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Kind {
        case cover(String?)
        case symbol(String)
    }

    private struct Item: Identifiable {
        let id: Int
        let ring: Int
        let angle: Double
        let kind: Kind
        let size: CGFloat
        let tilt: Double
    }

    /// Ring radii as a fraction of the width, and how fast each ring turns (radians per second).
    /// The outer rings turn the same way at similar speeds so their covers rarely cross.
    private let radii: [CGFloat] = [0.17, 0.31, 0.47]
    private let speeds: [Double] = [-0.06, 0.03, 0.024]

    private var items: [Item] {
        func cover(_ index: Int) -> Kind { .cover(books.indices.contains(index) ? books[index].coverAssetName : nil) }
        return [
            Item(id: 0, ring: 0, angle: -2.4, kind: .symbol("headphones"), size: 46, tilt: 0),
            Item(id: 1, ring: 0, angle: 0.75, kind: .symbol("lightbulb"), size: 46, tilt: 0),
            Item(id: 2, ring: 1, angle: -2.0, kind: cover(0), size: 60, tilt: -8),
            Item(id: 3, ring: 1, angle: -0.9, kind: cover(1), size: 56, tilt: 7),
            Item(id: 4, ring: 1, angle: 0.95, kind: .symbol("quote.opening"), size: 50, tilt: 0),
            Item(id: 5, ring: 1, angle: 2.05, kind: cover(2), size: 56, tilt: -5),
            Item(id: 6, ring: 2, angle: -2.7, kind: cover(3), size: 62, tilt: 6),
            Item(id: 7, ring: 2, angle: -1.45, kind: .symbol("bubble.left.and.text.bubble.right"), size: 54, tilt: 0),
            Item(id: 8, ring: 2, angle: -0.3, kind: cover(4), size: 64, tilt: -6),
            Item(id: 9, ring: 2, angle: 0.45, kind: cover(5), size: 58, tilt: 9),
            Item(id: 10, ring: 2, angle: 1.5, kind: cover(6), size: 60, tilt: -7),
            Item(id: 11, ring: 2, angle: 2.6, kind: .symbol("bookmark"), size: 48, tilt: 0)
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let center = CGPoint(x: width / 2, y: proxy.size.height / 2)

            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    ForEach(radii.indices, id: \.self) { ring in
                        Circle()
                            .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                            .frame(width: width * radii[ring] * 2, height: width * radii[ring] * 2)
                            .position(center)
                    }

                    BookBiteMark(size: 68)
                        .shadow(color: .black.opacity(0.2), radius: 18, y: 10)
                        .position(center)

                    ForEach(items) { item in
                        let angle = item.angle + time.truncatingRemainder(dividingBy: 10_000) * speeds[item.ring]
                        let radius = width * radii[item.ring]
                        itemView(item)
                            .position(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func itemView(_ item: Item) -> some View {
        switch item.kind {
        case .cover(let url):
            EditorialCover(coverURL: url, width: item.size)
                .rotationEffect(.degrees(item.tilt))
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: item.size * 0.38, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: item.size, height: item.size)
                .background(Color(.systemBackground), in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
    }
}

/// Soft blobs of cover colours over the paper background; plain paper until covers load.
struct CoverWash: View {
    let colors: [Color]

    var body: some View {
        ZStack {
            Color.paper
            let anchors: [UnitPoint] = [.topLeading, .topTrailing, .center]
            ForEach(colors.indices, id: \.self) { index in
                RadialGradient(
                    colors: [colors[index].opacity(0.22), .clear],
                    center: anchors[index % anchors.count],
                    startRadius: 0,
                    endRadius: 420
                )
            }
            LinearGradient(colors: [.clear, Color.paper], startPoint: .center, endPoint: .bottom)
        }
    }
}
