# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BookBite is a native iOS application built with SwiftUI for iOS 18.5+. The project uses Xcode 16.4 and Swift 5.0.

## Common Development Commands

### Building and Running
```bash
# Build the project
xcodebuild -project BookBite.xcodeproj -scheme BookBite build

# Clean build folder
xcodebuild clean -project BookBite.xcodeproj -scheme BookBite
```

### Testing
```bash
# Run all tests
xcodebuild test -project BookBite.xcodeproj -scheme BookBite -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test
xcodebuild test -project BookBite.xcodeproj -scheme BookBite -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:BookBiteTests/TestClassName/testMethodName
```

## Architecture

### Project Structure
- **BookBite/**: Main app source code
  - `BookBiteApp.swift`: App entry point with @main attribute and WindowGroup configuration
  - `ContentView.swift`: Root SwiftUI view
  - `Assets.xcassets/`: Visual assets and app icons
- **BookBiteTests/**: Unit tests using Swift Testing framework (import Testing)
- **BookBiteUITests/**: UI tests using XCTest framework

### Key Implementation Details
- The app uses standard SwiftUI architecture with `App` protocol conformance
- Testing uses both the new Swift Testing framework for unit tests and XCTest for UI automation
- No external dependencies currently - pure Apple ecosystem
- Configured for Universal app (iPhone and iPad support)

### Development Patterns
- SwiftUI views should follow the single responsibility principle
- Use @State, @Binding, @ObservedObject, and @StateObject appropriately for state management
- Test files follow the pattern: `[FeatureName]Tests.swift`
- UI tests use XCUIApplication for app launch and interaction

## Build Configuration
- **Bundle ID**: `tilo.BookBite`
- **Minimum iOS**: 18.5
- **Supported Devices**: iPhone and iPad
- **Swift Version**: 5.0
- **Xcode Version**: 16.4