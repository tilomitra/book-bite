import SwiftUI
import AuthenticationServices

struct SignInWithAppleButton: UIViewRepresentable {
    let action: (ASAuthorizationAppleIDCredential) -> Void
    let onError: ((Error) -> Void)?
    
    init(action: @escaping (ASAuthorizationAppleIDCredential) -> Void, onError: ((Error) -> Void)? = nil) {
        self.action = action
        self.onError = onError
    }
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonPressed), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let parent: SignInWithAppleButton
        
        init(_ parent: SignInWithAppleButton) {
            self.parent = parent
        }
        
        @objc func buttonPressed() {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                parent.action(appleIDCredential)
            }
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            print("Sign in with Apple failed: \(error)")
            
            // Handle simulator-specific error with user-friendly message
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .unknown:
                    print("⚠️ Sign in with Apple is not available in the iOS Simulator. Please test on a physical device.")
                case .canceled:
                    print("User canceled Sign in with Apple")
                case .invalidResponse:
                    print("Invalid response from Apple ID provider")
                case .notHandled:
                    print("Authorization request not handled")
                case .failed:
                    print("Authorization request failed")
                @unknown default:
                    print("Unknown Sign in with Apple error: \(authError.localizedDescription)")
                }
            }
            
            // Notify parent about the error
            parent.onError?(error)
        }
        
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                fatalError("No window found")
            }
            return window
        }
    }
}