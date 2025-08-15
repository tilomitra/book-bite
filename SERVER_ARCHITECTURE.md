# BookBite Server Architecture

## Overview

BookBite has been transformed from a local-only iOS app to a full-stack application with a Node.js/Express backend, Supabase database, and intelligent data source management.

## Architecture Components

### Backend Server (`/server`)
- **Framework**: Node.js with Express and TypeScript
- **Database**: Supabase (PostgreSQL with real-time capabilities)
- **Authentication**: Supabase Auth with JWT tokens
- **AI Integration**: Anthropic Claude 3 Sonnet for summary generation
- **External APIs**: Google Books API for metadata
- **Background Jobs**: Bull queue with Redis for async processing
- **Caching**: NodeCache for in-memory caching

### iOS App Updates
- **Network Layer**: New `NetworkService` with retry logic and error handling
- **Repository Pattern**: Three repository implementations:
  - `LocalBookRepository`: Original bundled data
  - `RemoteBookRepository`: Server-only data source
  - `HybridBookRepository`: Smart fallback with offline support
- **Cache Management**: `CacheService` for offline data persistence
- **Settings**: New settings screen for cache and data source management

## API Endpoints

### Books API
```
GET    /api/books                    # List books (paginated)
GET    /api/books/search?q=query     # Search books
GET    /api/books/:id                # Get book details
GET    /api/books/:id/cover          # Get book cover
POST   /api/books                    # Create book (admin)
POST   /api/books/import             # Import by ISBN (admin)
PUT    /api/books/:id                # Update book (admin)
DELETE /api/books/:id                # Delete book (admin)
```

### Summaries API
```
GET    /api/summaries/book/:bookId        # Get summary
GET    /api/summaries/job/:jobId          # Check generation job
GET    /api/summaries                     # List all (admin)
POST   /api/summaries/book/:bookId/generate  # Generate summary (admin)
PUT    /api/summaries/:id                 # Update summary (admin)
DELETE /api/summaries/:id                 # Delete summary (admin)
```

## Database Schema

### Books Table
```sql
- id (UUID, primary key)
- title (text, required)
- subtitle (text, optional)
- authors (text[], required)
- isbn10, isbn13 (varchar, optional)
- published_year (integer)
- publisher (text)
- categories (text[])
- cover_url (text)
- description (text)
- source_attribution (text[])
- google_books_id (varchar)
- created_at, updated_at (timestamps)
```

### Summaries Table
```sql
- id (UUID, primary key)
- book_id (UUID, foreign key)
- one_sentence_hook (text, required)
- key_ideas (JSONB, structured data)
- how_to_apply (JSONB, structured data)
- common_pitfalls (text[])
- critiques (text[])
- who_should_read (text)
- limitations (text)
- citations (JSONB)
- read_time_minutes (integer)
- style (enum: brief, full)
- llm_model, llm_version (text)
- generation_date (timestamp)
- created_at, updated_at (timestamps)
```

### Summary Generation Jobs Table
```sql
- id (UUID, primary key)
- book_id (UUID, foreign key)
- status (enum: pending, processing, completed, failed)
- error_message (text)
- retry_count (integer)
- created_at, updated_at (timestamps)
```

## Data Flow

### Book Search Flow
1. User searches for books
2. **Hybrid Mode**: Try remote API first
3. **Fallback**: Use local search if remote fails
4. **Cache**: Store successful remote results locally
5. **Offline**: Use cached results when offline

### Summary Generation Flow
1. Admin triggers summary generation via API
2. Job created in database with 'pending' status
3. Background worker picks up job
4. Worker calls Claude API with structured prompt
5. Generated summary saved to database
6. Job status updated to 'completed'
7. Client can poll job status or fetch completed summary

### Import Book Flow
1. Admin provides ISBN via API
2. System searches Google Books API
3. Book metadata imported and normalized
4. Book saved to database with source attribution
5. Optional: Trigger summary generation job

## Key Features

### Intelligent Data Sources
- **Local**: Fast, always available, limited content
- **Remote**: Fresh data, AI summaries, requires internet
- **Hybrid**: Best of both worlds with automatic fallback

### Offline Support
- Automatic caching of frequently accessed data
- Graceful degradation when offline
- Cache management tools in settings
- Network status monitoring

### AI-Powered Summaries
- Structured prompts for consistent output
- Two styles: brief (3-4 key ideas) and full (5-7 key ideas)
- Confidence levels for each key idea
- Actionable application points
- Citations and source references

### Scalable Architecture
- Async job processing for expensive operations
- Caching at multiple levels (memory, file system)
- Rate limiting and security middleware
- Row-level security in database
- Background processing with retry logic

### Security & Performance
- JWT-based authentication
- Role-based access control (admin vs public)
- API rate limiting (100 req/15min)
- Input validation with Zod schemas
- SQL injection prevention
- CORS configuration
- Health check endpoints

## Deployment

### Recommended Stack
- **Server**: Railway or Vercel
- **Database**: Supabase (managed PostgreSQL)
- **Queue**: Redis (Railway add-on or external)
- **CDN**: Automatic with hosting providers
- **Monitoring**: Built-in health checks

### Environment Configuration
- Development: Local server with test database
- Staging: Deployed server with staging database
- Production: Production server with monitoring

## Future Enhancements

### Planned Features
1. **User Accounts**: Personal libraries and reading history
2. **Social Features**: Reviews, ratings, sharing
3. **Comparison Tool**: Side-by-side book analysis
4. **Notifications**: New summaries, reading reminders
5. **Multiple AI Providers**: Fallback AI services
6. **More Book Sources**: Open Library, Goodreads integration
7. **Export Improvements**: PDF summaries, Notion integration

### Performance Optimizations
1. **CDN**: Static asset caching
2. **Database**: Read replicas for scaling
3. **Cache**: Redis cluster for distributed caching
4. **API**: GraphQL for efficient data fetching
5. **Mobile**: Background sync, prefetching

### Analytics & Insights
1. **Usage Tracking**: Popular books, search patterns
2. **Performance Monitoring**: API response times, error rates
3. **Cost Optimization**: AI usage patterns, cache hit rates
4. **User Insights**: Feature usage, retention metrics

## Technical Decisions

### Why Node.js/Express?
- Familiar JavaScript ecosystem
- Great TypeScript support
- Excellent async handling for AI API calls
- Large community and package ecosystem

### Why Supabase?
- PostgreSQL with modern API
- Built-in authentication and RLS
- Real-time capabilities for future features
- Great developer experience

### Why Claude (Anthropic)?
- Superior reasoning capabilities for book analysis
- Large context window (200K tokens)
- Structured output support
- Reliable API with good rate limits

### Why Hybrid Repository Pattern?
- Provides the best user experience
- Graceful degradation when offline
- Easy to switch between data sources
- Future-proof for additional sources

## Monitoring & Maintenance

### Key Metrics to Monitor
- API response times and error rates
- Database query performance
- AI API usage and costs
- Cache hit rates
- User session duration

### Regular Maintenance
- Database backups and cleanup
- Cache cleaning (old files)
- API key rotation
- Dependency updates
- Performance optimization

### Alerting Setup
- Server downtime alerts
- High error rate alerts
- Database connection issues
- AI API quota warnings
- Disk space monitoring

This architecture provides a solid foundation for BookBite's growth while maintaining excellent user experience and developer productivity.