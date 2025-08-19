# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BookBite is a full-stack application consisting of:
- **iOS App**: Native SwiftUI application for iOS 18.5+ using Xcode 16.4 and Swift 5.0
- **Node.js Server**: Express/TypeScript backend with Supabase database and AI integration

## Common Development Commands

### iOS App Commands

#### Building and Running
```bash
# Build the iOS project
xcodebuild -project BookBite.xcodeproj -scheme BookBite build

# Clean build folder
xcodebuild clean -project BookBite.xcodeproj -scheme BookBite
```

#### Testing
```bash
# Run all iOS tests
xcodebuild test -project BookBite.xcodeproj -scheme BookBite -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test
xcodebuild test -project BookBite.xcodeproj -scheme BookBite -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:BookBiteTests/TestClassName/testMethodName
```

### Server Commands

#### Development
```bash
# Start development server with hot reload
cd server && npm run dev

# Build TypeScript to JavaScript
cd server && npm run build

# Start production server
cd server && npm start
```

#### Testing and Quality
```bash
# Run server tests
cd server && npm test

# Run ESLint
cd server && npm run lint

# Install dependencies
cd server && npm install
```

#### Database Management
```bash
# Run Supabase schema (copy contents to Supabase SQL editor)
cat server/supabase/schema.sql
```

#### Data Population Scripts

##### Comprehensive Book Population (Recommended)
```bash
# Populate books from all sources (Google Books + NYT) with default settings
cd server && npm run populate-books

# Google Books only - 25 books per category, all priorities
cd server && npm run populate-books-google

# NYT Bestsellers only - 15 books per list, all lists
cd server && npm run populate-books-nyt

# High priority categories only (Self-Help, Psychology, Business, History, Biography, etc.)
cd server && npm run populate-books-high-priority

# Custom options: [booksPerCategory] [priority] [source]
cd server && npx tsx scripts/populate-books.ts 30 high google
cd server && npx tsx scripts/populate-books.ts 15 medium nyt
cd server && npx tsx scripts/populate-books.ts 50 all all
```

**Features:**
- **Unified script** combining Google Books API + NYT Bestsellers API
- 35+ comprehensive non-fiction categories + 16+ NYT bestseller lists
- Priority filtering (high/medium/low) for targeted content
- Source filtering (google/nyt/all) for flexible data sourcing
- Automatic deduplication across all sources
- AI-generated summaries + extended summaries in one operation
- Smart rate limiting and comprehensive progress tracking
- Can generate 1,750+ books with full category coverage

##### Summary Generation
```bash
# Generate summaries for books that don't have any summaries (regular + extended)
cd server && npm run generate-summaries

# Generate only extended summaries for books that have regular summaries but lack extended ones
cd server && npm run generate-extended-summaries

# Custom batch processing
cd server && npx tsx scripts/generate-missing-summaries.ts 3 50  # 3 books per batch, max 50 books
cd server && npx tsx scripts/generate-extended-summaries.ts 2 30  # 2 books per batch, max 30 books
```

**Usage Notes:**
- Always start with high priority categories for best content quality
- Monitor API usage to stay within rate limits
- Scripts include automatic deduplication to prevent duplicates
- Each book gets both regular summary and extended summary via AI

## Architecture

### Project Structure

#### iOS App (`/`)
- **BookBite/**: Main app source code
  - `App/`: App configuration and dependency injection
    - `BookBiteApp.swift`: App entry point with @main attribute
    - `RootView.swift`: Main tab-based navigation
    - `Configuration/`: App config and dependency container
  - `Core/`: Business logic and data layer
    - `Models/`: Data models (Book, Summary, Confidence)
    - `Repositories/`: Data access layer with protocol abstraction
      - `BookRepository.swift`: Protocol definition
      - `LocalBookRepository.swift`: Bundled JSON data source
      - `RemoteBookRepository.swift`: Server API data source
      - `HybridBookRepository.swift`: Smart fallback between remote/local
    - `Services/`: Business services (NetworkService, CacheService, etc.)
  - `Features/`: Feature-specific UI and ViewModels
    - `Search/`: Book search functionality
    - `BookDetail/`: Detailed book view with summaries
    - `Settings/`: App settings and data source management
  - `Shared/`: Reusable UI components
  - `Resources/Fixtures/`: Bundled JSON data for offline use
- **BookBiteTests/**: Unit tests using Swift Testing framework
- **BookBiteUITests/**: UI tests using XCTest framework

#### Server (`/server`)
- **src/**: TypeScript server source code
  - `config/`: Configuration files (Supabase connection)
  - `controllers/`: Request handlers for books and summaries
  - `middleware/`: Authentication, error handling, rate limiting
  - `models/`: TypeScript types and Zod schemas
  - `routes/`: Express route definitions
  - `services/`: Business logic (GoogleBooksService, OpenAIService, etc.)
- **supabase/**: Database schema and migrations

### Key Implementation Details

#### iOS App
- Repository pattern with protocol abstraction enables switching between data sources
- Three data source modes: Local (bundled), Remote (server-only), Hybrid (smart fallback)
- Comprehensive caching for offline support with automatic cache management
- Network monitoring for automatic online/offline detection
- SwiftUI with MVVM architecture and Combine for reactive programming

#### Server
- Express.js with TypeScript for type safety
- Supabase (PostgreSQL) for database with row-level security
- Google Books API integration for book metadata enrichment
- OpenAI API for AI-generated book summaries
- Bull job queue with Redis for async summary generation
- JWT authentication with role-based access control (admin/public)
- Comprehensive error handling and request validation with Zod

### Development Patterns

#### iOS Development
- SwiftUI views follow single responsibility principle
- Use repository pattern for data access abstraction
- ViewModels handle business logic and state management
- Dependency injection via DependencyContainer
- Async/await for all network operations
- Proper error handling with user-friendly messages

#### Server Development  
- Controllers handle HTTP requests/responses only
- Services contain business logic and external API integration
- Models define TypeScript types with Zod validation
- Async/await throughout for database and external API calls
- Proper HTTP status codes and error responses
- Background job processing for expensive operations

## Build Configuration

### iOS App
- **Bundle ID**: `tilo.BookBite`
- **Minimum iOS**: 18.5
- **Supported Devices**: iPhone and iPad
- **Swift Version**: 5.0
- **Xcode Version**: 16.4

### Server
- **Node.js**: 20+ (ES2022 support)
- **TypeScript**: 5.3+
- **Database**: PostgreSQL via Supabase
- **Queue**: Redis for background jobs
- **APIs**: Google Books API, OpenAI API

## Environment Setup

### Required Environment Variables (Server)
```bash
# Server
PORT=3000
NODE_ENV=development

# Database
SUPABASE_URL=your_supabase_project_url
SUPABASE_SERVICE_KEY=your_supabase_service_key

# External APIs
GOOGLE_BOOKS_API_KEY=your_google_books_api_key
OPENAI_API_KEY=your_openai_api_key

# Queue
REDIS_URL=redis://localhost:6379
```

### iOS App Configuration
- Update `AppConfiguration.swift` with your server URL
- Choose data source mode (Local/Remote/Hybrid)
- Configure cache settings and timeouts

## Data Sources

The app supports three data source modes:
- **Local**: Uses bundled JSON files (offline-first, limited content)
- **Remote**: Uses server API exclusively (requires internet)
- **Hybrid**: Smart fallback between server and local (recommended)

Switch modes in Settings app or via `AppConfiguration.currentDataSource`.