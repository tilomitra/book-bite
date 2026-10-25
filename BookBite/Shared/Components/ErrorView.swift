import SwiftUI

struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?

    init(error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.primary.opacity(0.6))

            Text("Something went wrong")
                .font(.title3)
                .fontWeight(.semibold)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Text("Try Again")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.primary)
                        .clipShape(Capsule())
                }
            }

            Spacer()
        }
        .padding(.top, 100)
    }
}