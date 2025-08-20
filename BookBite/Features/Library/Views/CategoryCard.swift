import SwiftUI

struct CategoryCard: View {
    let category: BookCategory
    
    var categoryColor: Color {
        DesignSystem.Colors.categoryColor(for: category.name)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.system(size: 36))
                .foregroundColor(categoryColor)
            
            Text(category.name)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            if let count = category.bookCount {
                Text("\(count) books")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(categoryColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(categoryColor.opacity(0.25), lineWidth: 1.5)
        )
        .shadow(
            color: DesignSystem.Shadow.medium.color,
            radius: DesignSystem.Shadow.medium.radius,
            x: DesignSystem.Shadow.medium.x,
            y: DesignSystem.Shadow.medium.y
        )
    }
}

struct BookCategory: Identifiable {
    let id: String
    let name: String
    let iconName: String
    let bookCount: Int?
    
    init(name: String, iconName: String = "books.vertical.fill", bookCount: Int? = nil) {
        self.id = name
        self.name = name
        self.iconName = iconName
        self.bookCount = bookCount
    }
    
    static func getCategoryIcon(for name: String) -> String {
        switch name.lowercased() {
        case "nyt bestsellers": return "star.fill"
        case "self-help", "personal development": return "person.fill.checkmark"
        case "psychology", "mental health": return "brain.head.profile"
        case "business", "entrepreneurship": return "briefcase.fill"
        case "science": return "atom"
        case "technology": return "laptopcomputer"
        case "history", "american history": return "clock.arrow.circlepath"
        case "biography", "memoir": return "person.text.rectangle.fill"
        case "health", "wellness": return "heart.fill"
        case "nutrition": return "leaf.fill"
        case "fitness": return "figure.run"
        case "philosophy": return "lightbulb.fill"
        case "religion", "spirituality": return "sparkles"
        case "politics": return "building.columns.fill"
        case "economics": return "chart.line.uptrend.xyaxis"
        case "leadership": return "person.3.fill"
        case "innovation": return "lightbulb.max.fill"
        case "marketing": return "megaphone.fill"
        case "productivity": return "checkmark.circle.fill"
        case "mindfulness": return "circle.hexagongrid.fill"
        case "biology": return "leaf.arrow.circlepath"
        case "physics": return "waveform.path.ecg"
        case "medicine": return "cross.fill"
        case "environment": return "globe.americas.fill"
        case "world war": return "flag.fill"
        case "sociology": return "person.2.fill"
        case "anthropology": return "figure.2.arms.open"
        case "education": return "graduationcap.fill"
        case "art": return "paintbrush.fill"
        case "music": return "music.note"
        case "travel": return "airplane"
        case "cooking": return "fork.knife"
        default: return "books.vertical.fill"
        }
    }
}