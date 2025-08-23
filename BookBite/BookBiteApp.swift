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
    
    var body: some Scene {
        WindowGroup {
            RootView(deepLinkBook: deepLinkBook)
                .environmentObject(dependencies)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        if let book = dependencies.sharingService.handleIncomingURL(url) {
            deepLinkBook = book
        }
    }
}
