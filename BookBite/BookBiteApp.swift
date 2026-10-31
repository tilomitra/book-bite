//
//  BookBiteApp.swift
//  BookBite
//
//  Created by Tilo Mitra on 2025-08-14.
//

import CoreSpotlight
import SwiftUI

@main
struct BookBiteApp: App {
    @StateObject private var dependencies = DependencyContainer.shared
    @AppStorage(OnboardingPreferences.completedKey) private var hasCompletedOnboarding = false

    init() {
        OnboardingPreferences.migrateExistingInstall()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootView()
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
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                handleSpotlight(activity)
            }
            .task {
                WidgetBridge.publishServerURL(AppConfiguration.shared.baseServerURL)
                SpotlightIndexer.shared.start()
                SubscriptionStore.shared.start()
                await OfflineLibrary.shared.maintain(repository: dependencies.bookRepository)
            }
        }
    }

    /// `bookbite://book/<id>?title=&author=&cover=` from shared links and the widget,
    /// `bookbite://invite/<code>` from a friend's invite page
    private func handleDeepLink(_ url: URL) {
        if let code = ReadingPass.code(fromInviteLink: url) {
            ReadingPassStore.shared.receiveInvite(code)
            return
        }
        guard let partial = dependencies.sharingService.handleIncomingURL(url) else { return }
        DeepLinkRouter.shared.open(bookId: partial.id, partial: partial)
    }

    private func handleSpotlight(_ activity: NSUserActivity) {
        guard let bookId = SpotlightIndexer.bookId(from: activity) else { return }
        DeepLinkRouter.shared.open(bookId: bookId, partial: SpotlightIndexer.knownBook(id: bookId))
    }
}
