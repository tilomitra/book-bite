import SwiftUI

/// Small uppercase caption above a large serif title, used in place of the navigation bar title
/// on the editorial tab roots (Discover, Library). Optional trailing content sits on the title line.
struct EditorialHeader<Caption: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var caption: Caption
    @ViewBuilder var trailing: Trailing

    init(title: String,
         @ViewBuilder caption: () -> Caption = { EmptyView() },
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.caption = caption()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            caption
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(1)
                .textCase(.uppercase)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 42, weight: .medium, design: .serif))
                    .tracking(-0.8)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                trailing
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

extension View {
    /// Hides the navigation bar on an editorial tab root (the `EditorialHeader` replaces it) and keeps
    /// the status bar area opaque while content scrolls under it. Pushed screens show their own bar.
    func editorialNavigationBar() -> some View {
        self
            .overlay(alignment: .top) {
                Color.paper.ignoresSafeArea(edges: .top).frame(height: 0)
            }
            .toolbar(.hidden, for: .navigationBar)
    }
}
