import SwiftUI

/// Page colours for the summary reader. Paper follows the app's light/dark appearance; Sepia and
/// Night are fixed, so the reader can be warm at night while the rest of the app stays light.
enum ReaderTheme: String, CaseIterable, Identifiable {
    case paper, sepia, night

    var id: String { rawValue }

    var name: String {
        switch self {
        case .paper: return "Paper"
        case .sepia: return "Sepia"
        case .night: return "Night"
        }
    }

    var background: Color {
        switch self {
        case .paper: return .paper
        case .sepia: return Color(red: 0.957, green: 0.925, blue: 0.851)
        case .night: return Color(red: 0.071, green: 0.067, blue: 0.063)
        }
    }

    /// Body text. Night is a warm grey rather than white, which glares on a dark page.
    var ink: Color {
        switch self {
        case .paper: return .primary
        case .sepia: return Color(red: 0.255, green: 0.200, blue: 0.145)
        case .night: return Color(red: 0.820, green: 0.792, blue: 0.745)
        }
    }

    /// Captions, authors, the time left
    var secondaryInk: Color {
        switch self {
        case .paper: return .secondary
        case .sepia, .night: return ink.opacity(0.62)
        }
    }

    /// Hairlines and the progress track
    var rule: Color {
        switch self {
        case .paper: return .primary.opacity(0.14)
        case .sepia, .night: return ink.opacity(0.18)
        }
    }

    /// Forces the matching appearance for Sepia/Night so system colours, the status bar and the
    /// navigation bar fit the page. Paper keeps the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .paper: return nil
        case .sepia: return .light
        case .night: return .dark
        }
    }
}

enum ReaderTypeface: String, CaseIterable, Identifiable {
    case serif, sans

    var id: String { rawValue }

    var name: String {
        switch self {
        case .serif: return "Serif"
        case .sans: return "Sans"
        }
    }

    var design: Font.Design {
        switch self {
        case .serif: return .serif
        case .sans: return .default
        }
    }

    /// Sans reads a touch larger at the same point size; keep the colour of the page even
    var sizeAdjustment: CGFloat {
        switch self {
        case .serif: return 1
        case .sans: return 0.95
        }
    }
}

/// Text size steps for the reader, in points at the default Dynamic Type size. Stored in the existing
/// `readerTextSize` key; the reader scales it with the system text size.
enum ReaderTextSize {
    static let steps: [Double] = [14, 16, 18, 20, 22, 24, 26]
    static let standard: Double = 18

    static func index(of size: Double) -> Int {
        steps.enumerated().min { abs($0.element - size) < abs($1.element - size) }?.offset ?? 2
    }
}

// MARK: - Settings panel

/// The "Aa" popover: theme, text size and typeface. Small, quiet, and it applies instantly.
struct ReaderSettingsPanel: View {
    @AppStorage("readerTheme") private var theme: ReaderTheme = .paper
    @AppStorage("readerTypeface") private var typeface: ReaderTypeface = .serif
    @AppStorage("readerTextSize") private var textSize: Double = ReaderTextSize.standard
    @Environment(\.colorScheme) private var colorScheme
    /// The app's appearance outside the reader (the panel itself may be forced dark by Night),
    /// so the Paper swatch shows what Paper will look like.
    var systemColorScheme: ColorScheme?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            themePicker
            sizeControl
            typefacePicker
        }
        .padding(20)
        .frame(width: 300)
        .sensoryFeedback(.selection, trigger: theme)
        .sensoryFeedback(.selection, trigger: typeface)
        .sensoryFeedback(.selection, trigger: textSize)
    }

    // MARK: Theme

    private var themePicker: some View {
        HStack(spacing: 0) {
            ForEach(ReaderTheme.allCases) { option in
                Button {
                    theme = option
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(option.background)
                                .environment(\.colorScheme, option.colorScheme ?? systemColorScheme ?? colorScheme)
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                            Text("Aa")
                                .font(.system(size: 17, weight: .regular, design: .serif))
                                .foregroundStyle(option.ink)
                                .environment(\.colorScheme, option.colorScheme ?? systemColorScheme ?? colorScheme)
                        }
                        .frame(width: 52, height: 52)
                        .padding(3)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: 1.5)
                                .opacity(theme == option ? 1 : 0)
                        }

                        Text(option.name)
                            .font(.caption)
                            .foregroundStyle(theme == option ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option.name) theme")
                .accessibilityAddTraits(theme == option ? .isSelected : [])
            }
        }
    }

    // MARK: Size

    private var sizeIndex: Int { ReaderTextSize.index(of: textSize) }

    private var sizeControl: some View {
        HStack(spacing: 0) {
            sizeButton(smaller: true)

            HStack(spacing: 6) {
                ForEach(ReaderTextSize.steps.indices, id: \.self) { index in
                    Circle()
                        .fill(Color.primary.opacity(index <= sizeIndex ? 0.75 : 0.15))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)

            sizeButton(smaller: false)
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
        .background(Color.primary.opacity(0.05), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Text size")
        .accessibilityValue("\(sizeIndex + 1) of \(ReaderTextSize.steps.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            @unknown default: break
            }
        }
    }

    private func sizeButton(smaller: Bool) -> some View {
        Button {
            step(by: smaller ? -1 : 1)
        } label: {
            Text("A")
                .font(.system(size: smaller ? 14 : 20, weight: .regular, design: typeface.design))
                .frame(width: 52, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(smaller ? sizeIndex == 0 : sizeIndex == ReaderTextSize.steps.count - 1)
        .opacity((smaller ? sizeIndex == 0 : sizeIndex == ReaderTextSize.steps.count - 1) ? 0.3 : 1)
    }

    private func step(by delta: Int) {
        let next = min(max(sizeIndex + delta, 0), ReaderTextSize.steps.count - 1)
        textSize = ReaderTextSize.steps[next]
    }

    // MARK: Typeface

    private var typefacePicker: some View {
        HStack(spacing: 8) {
            ForEach(ReaderTypeface.allCases) { option in
                Button {
                    typeface = option
                } label: {
                    Text(option.name)
                        .font(.system(.body, design: option.design))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            Capsule()
                                .strokeBorder(Color.primary.opacity(typeface == option ? 0.9 : 0.15),
                                              lineWidth: typeface == option ? 1.2 : 0.5)
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option.name) typeface")
                .accessibilityAddTraits(typeface == option ? .isSelected : [])
            }
        }
    }
}
