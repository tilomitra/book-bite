import Foundation

final class OnboardingService: ObservableObject {
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: hasCompletedOnboardingKey)
        }
    }
    
    init() {
        // For testing authentication flow, reset onboarding state
        UserDefaults.standard.set(false, forKey: hasCompletedOnboardingKey)
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
    }
    
    func markOnboardingAsCompleted() {
        hasCompletedOnboarding = true
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}