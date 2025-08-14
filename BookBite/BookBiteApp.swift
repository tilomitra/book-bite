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
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(dependencies)
        }
    }
}
