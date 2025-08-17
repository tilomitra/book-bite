import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    let isLoading: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask about this book...", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }
                .disabled(isLoading)
            
            Button(action: onSend) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSend ? .blue : .gray)
                }
            }
            .disabled(!canSend || isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    VStack {
        Spacer()
        ChatInputView(
            text: .constant("What are the key takeaways?"),
            onSend: {},
            isLoading: false
        )
    }
    .background(Color(UIColor.systemGray6))
}