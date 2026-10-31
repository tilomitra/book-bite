import SwiftUI

/// Small uppercase caption above a large serif title, used in place of the navigation bar title
/// on the editorial tab roots (Discover, Library). Optional trailing content sits on the title line.
struct EditorialHeader<Caption: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var caption: Caption
    @ViewBuilder var trailing: Trailing
    @ObservedObject private var connectivity = ConnectivityMonitor.shared

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

            if !connectivity.isConnected {
                OfflineNotice()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: connectivity.isConnected)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

/// The serif heading of a section on an editorial screen. Shelves and cards share it, so the page has one rhythm.
struct EditorialSectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 24, weight: .medium, design: .serif))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
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

/// One quiet line under an editorial header while the device is offline. Grey, no banner: the screen
/// below still works from what is on the device.
struct OfflineNotice: View {
    private var device: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }

    var body: some View {
        Label("Offline · Showing what's on this \(device)", systemImage: "wifi.slash")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
    }
}
