# BookBite

BookBite is a comprehensive iOS application for discovering, exploring, and learning from non-fiction books. Get AI-powered summaries, key insights, and practical applications from thousands of books across business, self-help, science, and more.

## Features

### Core Features
- **📚 Extensive Library**: Access thousands of non-fiction books across 35+ categories
- **🤖 AI-Powered Summaries**: Intelligent summaries with key insights and extended analysis
- **⚡ Quick Reading**: 8-10 minute summaries for busy professionals
- **🎯 Smart Discovery**: Featured books, swipe-based discovery, and intelligent recommendations
- **🔍 Advanced Search**: Real-time search across titles, authors, categories, and topics
- **📖 Book Requests**: Request any book and get AI-generated summaries on-demand
- **⭐ Reader Reviews**: Community ratings and reviews from Open Library integration

### Reading Experience
- **📑 Multiple Summary Types**: 
  - Quick summaries for rapid understanding
  - Extended summaries for deeper insights
  - Key ideas extraction
  - Practical applications
  - Critical analysis
  - References and citations
- **💼 Workplace Applications**: Role-specific guidance for applying concepts
- **🔄 Flexible Data Sources**: Choose between local (offline), remote (server), or hybrid modes
- **🌓 Dark Mode Support**: Eye-friendly reading in low-light conditions

### Backend Capabilities
- **🔄 Real-time Sync**: Seamless integration with Node.js/Express backend
- **📊 Database Integration**: PostgreSQL via Supabase for scalable data storage
- **🤖 AI Integration**: OpenAI-powered summary generation
- **📚 Multiple Data Sources**: Google Books API and NYT Bestsellers integration
- **⚡ Background Processing**: Async job queue for efficient summary generation

## Screenshots

*Note: The app features a clean, modern SwiftUI interface with tab-based navigation. Key screens include:*
- **Featured Tab**: Discover trending and recommended books with detailed views
- **Swipe Tab**: Tinder-style book discovery with quick decisions
- **Search Tab**: Advanced search with filters and real-time results
- **Request Tab**: On-demand book request system with AI analysis
- **Settings Tab**: Configure data sources, cache settings, and preferences

## Requirements

- iOS 18.5+
- Xcode 16.4+
- Swift 5.0+

## Installation

1. Clone the repository:
```bash
git clone git@github.com:tilomitra/book-bite.git
cd book-bite
```

2. Open the project in Xcode:
```bash
open BookBite.xcodeproj
```

3. Build and run on your preferred simulator or device.

## Architecture

BookBite follows a clean MVVM architecture with repository pattern for both iOS and backend:

### iOS App Structure
```
BookBite/
├── App/                     # App configuration and entry point
│   ├── BookBiteApp.swift  # Main app with @main attribute
│   ├── RootView.swift     # Tab-based navigation
│   └── Configuration/     # Settings and dependency injection
├── Core/                    # Data models, repositories, and services
│   ├── Models/            # Book, Summary, User, Request models
│   ├── Repositories/      # Data access abstraction
│   │   ├── BookRepository.swift       # Protocol definition
│   │   ├── LocalBookRepository.swift  # Bundled JSON data
│   │   ├── RemoteBookRepository.swift # Server API integration
│   │   └── HybridBookRepository.swift # Smart fallback logic
│   └── Services/          # NetworkService, CacheService, etc.
├── Features/               # Feature-specific modules
│   ├── Featured/          # Featured books carousel
│   ├── Swipe/            # Tinder-style book discovery
│   ├── Search/           # Advanced search functionality
│   ├── Request/          # Book request system
│   ├── BookDetail/       # Detailed book views with tabs
│   └── Settings/         # App configuration
├── Shared/                # Reusable UI components
└── Resources/            # Assets and fixtures
    └── Fixtures/         # Bundled JSON data for offline use
```

### Backend Structure
```
server/
├── src/
│   ├── config/           # Database and app configuration
│   ├── controllers/      # HTTP request handlers
│   ├── middleware/       # Auth, error handling, rate limiting
│   ├── models/          # TypeScript types and Zod schemas
│   ├── routes/          # API endpoint definitions
│   └── services/        # Business logic and integrations
│       ├── GoogleBooksService.ts  # Book metadata
│       ├── OpenAIService.ts       # AI summaries
│       ├── NYTService.ts          # Bestsellers
│       └── QueueService.ts        # Background jobs
├── scripts/              # Data population utilities
└── supabase/            # Database schema and migrations
```

## Key Components

### iOS Features
- **Smart Search**: Debounced real-time search with 300ms delay, filters across title, author, subtitle, and categories
- **Book Detail Tabs**: 
  - Overview: AI-generated summary and key ideas
  - Apply: Workplace-specific implementation guidance
  - Analysis: Critical perspectives and common pitfalls
  - References: Citations with external links
- **Request System**: On-demand book requests with automatic AI summary generation
- **Data Management**: Protocol-based repository pattern with local/remote/hybrid modes
- **Caching**: Smart caching with configurable TTL and automatic cleanup
- **Network Monitoring**: Automatic online/offline detection and fallback

### Backend Features
- **RESTful API**: Express.js with TypeScript for type safety
- **Database**: PostgreSQL via Supabase with row-level security
- **Authentication**: JWT-based with admin/public roles
- **AI Integration**: OpenAI GPT-4 for intelligent summary generation
- **External APIs**: 
  - Google Books API for metadata enrichment
  - NYT Bestsellers API for trending books
- **Job Queue**: Redis-backed Bull queue for async processing
- **Rate Limiting**: API compliance and protection

## Testing

Run the test suite:

```bash
# Run all tests
xcodebuild test -project BookBite.xcodeproj -scheme BookBite -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test
xcodebuild test -project BookBite.xcodeproj -scheme BookBite -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:BookBiteTests/BookModelTests
```

Test coverage includes:
- Model serialization/deserialization
- Search filtering logic
- UI navigation flows
- Export functionality

## Data Population Scripts

The backend includes powerful scripts for automatically populating the database with thousands of books and AI-generated summaries:

### NYT Bestsellers Integration

Fetch and populate from New York Times bestseller lists:

```bash
# Populate with all NYT non-fiction bestseller lists
cd server && npm run populate-nyt

# Process only high-priority lists (combined, hardcover, business, science, biography)
cd server && npx tsx scripts/populate-nyt-bestsellers.ts --priority

# Process specific list
cd server && npx tsx scripts/populate-nyt-bestsellers.ts --list business-books
```

**Features:**
- Fetches from 16+ NYT non-fiction bestseller lists
- Includes rank and weeks on list metadata
- Automatic deduplication across lists
- AI-generated summaries with extended analysis

### Category-Based Book Discovery

Automatically discover and add books by category using Google Books API:

```bash
# Get 50 books per category (all priorities)
cd server && npx tsx scripts/populate-books-by-category.ts 50

# Get 25 books per category, high priority categories only
cd server && npx tsx scripts/populate-books-by-category.ts 25 high

# Get 10 books per category, medium priority categories only  
cd server && npx tsx scripts/populate-books-by-category.ts 10 medium

# Get 5 books per category, low priority categories only
cd server && npx tsx scripts/populate-books-by-category.ts 5 low
```

**Features:**
- 35+ comprehensive non-fiction categories (Self-Help, Business, Science, History, etc.)
- Automatic deduplication across categories
- AI-generated summaries and extended summaries
- Smart rate limiting for API compliance
- Progress tracking and detailed statistics

**Categories Include:**
- **High Priority**: Self-Help, Psychology, Business, History, Biography, Memoir, Leadership, etc.
- **Medium Priority**: Economics, Innovation, Biology, Philosophy, Politics, Health, etc.
- **Low Priority**: Art, Music, Travel, Cooking

### Manual Book Curation

For curated lists of popular books:

```bash
# Populate with handpicked popular non-fiction books
cd server && npx tsx scripts/populate-nonfiction-books.ts
```

This script includes 75+ carefully selected popular non-fiction books across categories like:
- Self-Help & Personal Development
- Biography & Memoir  
- Science & Nature
- Business & Economics
- History & Politics
- Health & Wellness

### Extended Summary Generation

Generate cost-effective extended summaries for existing books:

```bash
# Generate extended summaries for all books without them
cd server && npm run generate-extended-summaries
```

## Sample Data

The app includes curated summaries for popular non-fiction books across multiple categories:

### Business & Leadership
- The Manager's Path by Camille Fournier
- Accelerate by Nicole Forsgren, Jez Humble, Gene Kim
- Inspired by Marty Cagan
- The Lean Startup by Eric Ries
- Good to Great by Jim Collins
- The Creative Act by Rick Rubin

### Personal Development
- Atomic Habits by James Clear
- The 7 Habits of Highly Effective People by Stephen Covey
- Deep Work by Cal Newport
- The Power of Now by Eckhart Tolle

### Science & Technology
- Sapiens by Yuval Noah Harari
- Thinking in Systems by Donella H. Meadows
- The Gene by Siddhartha Mukherjee
- Astrophysics for People in a Hurry by Neil deGrasse Tyson

### Psychology & Philosophy
- Thinking, Fast and Slow by Daniel Kahneman
- Man's Search for Meaning by Viktor Frankl
- The Body Keeps the Score by Bessel van der Kolk
- Meditations by Marcus Aurelius

## Current Implementation Status

### ✅ Completed Features
- Native iOS app with SwiftUI
- Tab-based navigation (Featured, Swipe, Search, Request, Settings)
- Book detail views with multiple tabs
- Local/Remote/Hybrid data source modes
- Caching and offline support
- AI-powered book request system
- Backend API with Express/TypeScript
- Supabase database integration
- Google Books API integration
- NYT Bestsellers integration
- OpenAI summary generation
- Background job processing
- Data population scripts

### 🚧 In Progress
- Enhanced swipe gestures for book discovery
- PDF export functionality
- Mind map generation

### 📋 Future Enhancements
- User accounts and authentication
- Personalized recommendations
- Reading progress tracking
- Social features (sharing, discussions)
- Apple Watch companion app
- Android version
- Web application
- Audio summaries
- Multi-language support

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## Acknowledgments

- Built with SwiftUI and modern iOS development practices
- Inspired by the need for accessible business book insights
- Sample book data sourced from public domain information