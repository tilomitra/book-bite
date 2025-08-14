# BookBite

BookBite is a native iOS application for discovering and reading concise summaries of non-fiction books. Get the key insights from business and technology books in under 10 minutes.

## Features

- **📚 Smart Search**: Real-time search across titles, authors, and categories
- **⚡ Quick Summaries**: 8-10 minute reading time for each book
- **🎯 Confidence Indicators**: Visual badges showing reliability of key insights
- **💼 Workplace Applications**: Role-specific guidance for applying concepts at work
- **🔍 Book Comparison**: Side-by-side analysis of related books
- **📄 Export Options**: Generate PDFs and mind maps for sharing
- **📱 Modern Design**: Clean SwiftUI interface with dark mode support

## Screenshots

[Screenshots would go here when available]

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

BookBite follows a clean MVVM architecture with repository pattern:

```
BookBite/
├── App/                     # App configuration and entry point
├── Core/                    # Data models, repositories, and services
│   ├── Models/             # Book, Summary, Confidence models
│   ├── Repositories/       # Data access layer
│   └── Services/           # Business logic services
├── Features/               # Feature-specific UI and view models
│   ├── Search/            # Book search and discovery
│   ├── BookDetail/        # Detailed book views with tabs
│   ├── Comparison/        # Side-by-side book comparison
│   └── Export/            # PDF and mind map export
├── Shared/                # Reusable components and extensions
└── Resources/             # JSON fixtures and assets
```

## Key Components

### Search System
- Debounced real-time search with 300ms delay
- Filters across title, author, subtitle, and categories
- Empty states and loading indicators

### Book Details
- **Overview Tab**: One-sentence hook and expandable key ideas
- **Apply Tab**: Workplace-specific implementation guidance
- **Analysis Tab**: Common pitfalls and critical perspectives  
- **References Tab**: Citations with external links

### Data Management
- Protocol-based repository for easy backend integration
- Local JSON fixtures for offline operation
- Mock async delays to simulate network behavior

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

## Sample Data

The app includes sample summaries for popular business and technology books:
- The Manager's Path by Camille Fournier
- Accelerate by Nicole Forsgren, Jez Humble, Gene Kim
- Inspired by Marty Cagan
- Thinking in Systems by Donella H. Meadows
- The Lean Startup by Eric Ries

## Future Enhancements

- Backend API integration for real-time summary generation
- User accounts and personalization
- Reading progress tracking
- Social features and book recommendations
- Apple Watch companion app

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