import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showingAuthentication = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var onboardingService: OnboardingService
    @EnvironmentObject var authService: SupabaseAuthService
    
    private let onboardingData = [
        OnboardingPageData(
            title: "Discover Your Next\nGreat Read",
            subtitle: "Explore thousands of books with AI-powered summaries to find your perfect match.",
            imageName: "books.vertical.fill",
            primaryColor: .orange
        ),
        OnboardingPageData(
            title: "Smart Summaries\nMade Simple",
            subtitle: "Get comprehensive book insights and key takeaways to make informed reading decisions.",
            imageName: "brain.head.profile",
            primaryColor: .blue
        ),
        OnboardingPageData(
            title: "Start Your Reading\nJourney Today",
            subtitle: "Join readers discovering their next favorite book with BookBite.",
            imageName: "star.fill",
            primaryColor: .green
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(onboardingData.enumerated()), id: \.offset) { index, data in
                    OnboardingPageView(
                        data: data,
                        isLastPage: index == onboardingData.count - 1,
                        onGetStarted: {
                            if index == onboardingData.count - 1 {
                                completeOnboarding()
                            } else {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    currentPage = index + 1
                                }
                            }
                        }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.5), value: currentPage)
            
            HStack(spacing: 8) {
                ForEach(0..<onboardingData.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            .padding(.bottom, 50)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingAuthentication) {
            AuthenticationView(authService: authService)
        }
        .onChange(of: authService.authState) { _, newState in
            if newState.isAuthenticated || newState.isAnonymous {
                dismiss()
            }
        }
    }
    
    private func completeOnboarding() {
        onboardingService.markOnboardingAsCompleted()
        showingAuthentication = true
    }
}

struct OnboardingPageData {
    let title: String
    let subtitle: String
    let imageName: String
    let primaryColor: Color
}

struct OnboardingPageView: View {
    let data: OnboardingPageData
    let isLastPage: Bool
    let onGetStarted: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 30) {
                ZStack {
                    Circle()
                        .fill(data.primaryColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: data.imageName)
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(data.primaryColor)
                }
                
                VStack(spacing: 16) {
                    Text(data.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                    
                    Text(data.subtitle)
                        .font(.system(size: 17, weight: .regular))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                }
            }
            
            Spacer()
            
            Button(action: onGetStarted) {
                Text(isLastPage ? "Get Started" : "Get Started")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(data.primaryColor)
                    .cornerRadius(25)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
        .padding(.top, 60)
    }
}

#Preview {
    OnboardingView()
}