import SwiftUI

struct CitationRow: View {
    let citation: Citation
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text("[\(index)]")
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(citation.source)
                        .font(.body)
                    
                    if let url = citation.url {
                        Link(destination: URL(string: url)!) {
                            HStack(spacing: 4) {
                                Image(systemName: "link.circle.fill")
                                Text("View Source")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}