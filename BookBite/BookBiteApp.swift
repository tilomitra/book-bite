//
//  BookBiteApp.swift
//  BookBite
//
//  Created by Tilo Mitra on 2025-08-14.
//

import SwiftUI

@main
struct BookBiteApp: App {
    @StateObject private var dependencies = DependencyContainer.shared
    @State private var deepLinkBook: Book?
    @AppStorage(OnboardingPreferences.completedKey) private var hasCompletedOnboarding = false

    init() {
        OnboardingPreferences.migrateExistingInstall()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootView(deepLinkBook: deepLinkBook)
                        .transition(.opacity)
                } else {
                    OnboardingView(bookRepository: dependencies.bookRepository)
                        .transition(.opacity)
                }
            }
            .environmentObject(dependencies)
            .environmentObject(dependencies.authService)
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .task {
                WidgetBridge.publishServerURL(AppConfiguration.shared.baseServerURL)
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        if let book = dependencies.sharingService.handleIncomingURL(url) {
            deepLinkBook = book
        }
    }
}
