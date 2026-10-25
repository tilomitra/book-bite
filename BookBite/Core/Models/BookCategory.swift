import Foundation

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