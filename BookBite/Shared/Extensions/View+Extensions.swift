import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    func sectionBackground() -> some View {
        self
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension Color {
    static let confidenceHigh = Color.green
    static let confidenceMedium = Color.orange
    static let confidenceLow = Color.yellow
}