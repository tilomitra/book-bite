import SwiftUI

/// Settings → Reader: a sample page that shows the current theme, typeface and size, with the same
/// controls as the reader's "Aa" popover underneath. Changes apply to the reader at once.
struct ReadingSettingsView: View {
    @AppStorage("readerTheme") private var theme: ReaderTheme = .paper
    @AppStorage("readerTypeface") private var typeface: ReaderTypeface = .serif
    @AppStorage("readerTextSize") private var textSize: Double = ReaderTextSize.standard
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1
    @Environment(\.colorScheme) private var systemColorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                samplePage
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                ReaderSettingsPanel(systemColorScheme: systemColorScheme, width: nil)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Reader")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var samplePage: some View {
        let size = CGFloat(textSize) * typeScale * typeface.sizeAdjustment

        return VStack(alignment: .leading, spacing: 10) {
            Text("Chapter 1")
                .font(.system(size: 12, weight: .medium).smallCaps())
                .tracking(1)
                .foregroundStyle(theme.secondaryInk)

            Text("Small habits, big results")
                .font(.system(size: size * 1.3, weight: .medium, design: typeface.design))
                .foregroundStyle(theme.ink)

            Text("Changes that seem small at first add up. Get one percent better each day and, by the end of a year, you're far ahead of where you started.")
                .font(.system(size: size, design: typeface.design))
                .lineSpacing(size * 0.35)
                .foregroundStyle(theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(theme.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .environment(\.colorScheme, theme.colorScheme ?? systemColorScheme)
        .animation(.easeInOut(duration: 0.2), value: theme)
        .animation(.easeInOut(duration: 0.2), value: textSize)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview of the reader")
    }
}

#Preview {
    NavigationStack {
        ReadingSettingsView()
    }
}
