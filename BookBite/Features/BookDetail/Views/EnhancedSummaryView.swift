import SwiftUI

struct EnhancedSummaryView: View {
    let summary: Summary
    let book: Book
    let dominantColor: Color
    let secondaryColor: Color
    @State private var selectedSection: SummarySection = .extended
    
    enum SummarySection: String, CaseIterable {
        case extended = "Summary"
        case ask = "Chat with book"
        case keyIdeas = "Key Ideas"
        case application = "Apply"
        case analysis = "Analysis"
        case references = "References"
        
        var icon: String {
            switch self {
            case .extended: return "doc.text"
            case .keyIdeas: return "lightbulb"
            case .application: return "briefcase"
            case .ask: return "message.circle"
            case .analysis: return "chart.line.uptrend.xyaxis"
            case .references: return "quote.opening"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Horizontal scrollable pill buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SummarySection.allCases, id: \.self) { section in
                        PillButton(
                            title: section.rawValue,
                            icon: section.icon,
                            isSelected: selectedSection == section,
                            selectedColor: dominantColor,
                            unselectedColor: Color(UIColor.systemGray5)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSection = section
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(UIColor.systemBackground))
            
            Divider()
            
            // Content area
            contentView
                .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }
    
    @ViewBuilder
    var contentView: some View {
        switch selectedSection {
        case .extended:
            ExtendedSummaryContent(summary: summary)
        case .keyIdeas:
            KeyIdeasContent(summary: summary, accentColor: dominantColor)
        case .application:
            ApplicationContent(summary: summary)
        case .ask:
            AskContent(book: book)
        case .analysis:
            AnalysisContent(summary: summary, accentColor: dominantColor)
        case .references:
            ReferencesContent(summary: summary)
        }
    }
}

struct PillButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let selectedColor: Color
    let unselectedColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? selectedColor : unselectedColor)
            .foregroundColor(isSelected ? contrastingTextColor(for: selectedColor) : .primary)
            .cornerRadius(20)
            .shadow(color: isSelected ? selectedColor.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
        }
    }
    
    private func contrastingTextColor(for color: Color) -> Color {
        // Convert SwiftUI Color to UIColor to get RGB components
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Calculate luminance
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        
        // Return white for dark colors, black for light colors
        return luminance > 0.5 ? .black : .white
    }
}

// Extended Summary Content
struct ExtendedSummaryContent: View {
    let summary: Summary
    @State private var textSize: CGFloat = 16
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Text size controls
                HStack {
                    Text("Extended Summary")
                        .font(.headline)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: { textSize = max(14, textSize - 2) }) {
                            Image(systemName: "textformat.size.smaller")
                                .foregroundColor(.primary.opacity(0.6))
                        }
                        .disabled(textSize <= 14)
                        
                        Button(action: { textSize = min(22, textSize + 2) }) {
                            Image(systemName: "textformat.size.larger")
                                .foregroundColor(.primary.opacity(0.6))
                        }
                        .disabled(textSize >= 22)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                if let extendedSummary = summary.extendedSummary, !extendedSummary.isEmpty {
                    Text(extendedSummary)
                        .font(.system(size: textSize))
                        .lineSpacing(textSize * 0.35)
                        .padding(.horizontal)
                        .textSelection(.enabled)
                } else {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "Extended Summary Not Available",
                        message: "This book doesn't have an extended summary yet."
                    )
                    .padding(.top, 40)
                }
                
                Spacer(minLength: 40)
            }
        }
    }
}

// Key Ideas Content
struct KeyIdeasContent: View {
    let summary: Summary
    let accentColor: Color
    @State private var expandedIdeas: Set<String> = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(summary.keyIdeas.enumerated()), id: \.element.id) { index, idea in
                    KeyIdeaCard(
                        idea: idea,
                        index: index + 1,
                        isExpanded: expandedIdeas.contains(idea.id),
                        accentColor: accentColor
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if expandedIdeas.contains(idea.id) {
                                expandedIdeas.remove(idea.id)
                            } else {
                                expandedIdeas.insert(idea.id)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct KeyIdeaCard: View {
    let idea: KeyIdea
    let index: Int
    let isExpanded: Bool
    let accentColor: Color
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("\(index)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(accentColor)
                    )
                
                Text(idea.idea)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if !idea.tags.isEmpty {
                        HStack {
                            ForEach(idea.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(accentColor.opacity(0.1))
                                    .foregroundColor(accentColor)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.leading, 40)
                    }
                    
                    if !idea.sources.isEmpty {
                        Text("Sources: " + idea.sources.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 40)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .onTapGesture(perform: onTap)
    }
}

// Application Content
struct ApplicationContent: View {
    let summary: Summary
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(summary.howToApply.enumerated()), id: \.element.id) { index, point in
                    ApplicationCard(point: point, index: index + 1)
                }
                
                if !summary.whoShouldRead.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.2")
                                .foregroundColor(.green)
                            Text("Who Should Read This")
                                .font(.headline)
                        }
                        
                        Text(summary.whoShouldRead)
                            .font(.body)
                            .foregroundColor(.primary.opacity(0.8))
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

struct ApplicationCard: View {
    let point: ApplicationPoint
    let index: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 8) {
                Text(point.action)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// Analysis Content
struct AnalysisContent: View {
    let summary: Summary
    let accentColor: Color
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !summary.commonPitfalls.isEmpty {
                    AnalysisSection(
                        title: "Common Pitfalls",
                        icon: "exclamationmark.triangle",
                        color: .orange,
                        items: summary.commonPitfalls
                    )
                }
                
                if !summary.critiques.isEmpty {
                    AnalysisSection(
                        title: "Critical Perspectives",
                        icon: "quote.bubble",
                        color: .purple,
                        items: summary.critiques
                    )
                }
                
                if !summary.limitations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.red)
                            Text("Limitations")
                                .font(.headline)
                        }
                        
                        Text(summary.limitations)
                            .font(.body)
                            .foregroundColor(.primary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

struct AnalysisSection: View {
    let title: String
    let icon: String
    let color: Color
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }
            
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(color.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    
                    Text(item)
                        .font(.body)
                        .foregroundColor(.primary.opacity(0.8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// References Content
struct ReferencesContent: View {
    let summary: Summary
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(summary.citations.enumerated()), id: \.element.source) { index, citation in
                    ReferenceCard(citation: citation, index: index + 1)
                }
                
                if summary.citations.isEmpty {
                    EmptyStateView(
                        icon: "quote.opening",
                        title: "No References",
                        message: "No citations available for this summary."
                    )
                    .padding(.top, 40)
                }
            }
            .padding()
        }
    }
}

struct ReferenceCard: View {
    let citation: Citation
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(index).")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text(citation.source)
                    .font(.system(size: 15, weight: .medium))
                
                Spacer()
                
                if let url = citation.url {
                    Link(destination: URL(string: url)!) {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            
            // Citations don't have context in this model
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
}

// Ask Content
struct AskContent: View {
    let book: Book
    
    var body: some View {
        GeometryReader { geometry in
            BookChatView(book: book)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(minHeight: 500) // Ensure minimum height for proper chat experience
    }
}