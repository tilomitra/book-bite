import SwiftUI

struct KeyIdeaRow: View {
    let idea: KeyIdea
    let index: Int
    let isExpanded: Bool
    let toggleAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: toggleAction) {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index).")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(width: 30, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(idea.idea)
                            .font(.body)
                            .lineLimit(isExpanded ? nil : 2)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        HStack(spacing: 12) {
                            ConfidenceBadge(confidence: idea.confidence)
                            
                            if !idea.tags.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(idea.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                        
                        if isExpanded && !idea.sources.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Sources: \(idea.sources.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}