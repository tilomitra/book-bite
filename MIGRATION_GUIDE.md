# BookBite Server Migration Guide

This guide explains how to migrate from the hardcoded local data to the new server-based architecture.

## Migration Overview

BookBite now supports three data source modes:
- **Local**: Uses bundled JSON files (original behavior)
- **Remote**: Uses server API exclusively
- **Hybrid**: Uses server API with local fallback (recommended)

## Server Setup

### 1. Deploy the Node.js Server

#### Option A: Railway (Recommended)
1. Create account at [Railway](https://railway.app)
2. Connect your GitHub repository
3. Deploy the `/server` directory
4. Set environment variables in Railway dashboard

#### Option B: Vercel
1. Install Vercel CLI: `npm i -g vercel`
2. Navigate to `/server` directory
3. Run `vercel` and follow prompts

#### Option C: Manual Deployment
1. Build the server: `cd server && npm run build`
2. Deploy `dist/` folder to your hosting provider
3. Set environment variables on your hosting platform

### 2. Setup Supabase Database

1. Create a new project at [supabase.com](https://supabase.com)
2. Go to SQL Editor
3. Copy and run the schema from `server/supabase/schema.sql`
4. Note your project URL and service key

### 3. Get API Keys

#### Google Books API
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Enable Google Books API
4. Create API key in Credentials section

#### Anthropic Claude API
1. Sign up at [Anthropic](https://anthropic.com)
2. Get API key from dashboard
3. Note: Requires paid plan for production use

### 4. Configure Environment Variables

Set these on your hosting platform:

```bash
# Server Configuration
PORT=3000
NODE_ENV=production

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your_service_key

# Google Books API
GOOGLE_BOOKS_API_KEY=your_google_books_key

# Claude API
ANTHROPIC_API_KEY=your_anthropic_key

# Redis (if using external Redis)
REDIS_URL=redis://your-redis-url

# CORS (allow your domains)
CORS_ORIGIN=https://yourdomain.com
```

## iOS App Configuration

### 1. Update Server URL

In `BookBite/App/Configuration/AppConfiguration.swift`:

```swift
var baseServerURL: String {
    #if DEBUG
    return "http://localhost:3000/api" // For development
    #else
    return "https://your-production-server.com/api" // Your deployed server
    #endif
}
```

### 2. Choose Data Source Mode

The app defaults to **Hybrid** mode, which is recommended. You can change this in `AppConfiguration.swift`:

```swift
var currentDataSource: DataSource {
    return .hybrid // .local, .remote, or .hybrid
}
```

### 3. Test the Migration

1. Build and run the app
2. Go to Settings tab
3. Verify connection status
4. Test search functionality
5. Try generating a summary (requires server)

## Migration Steps

### Phase 1: Setup and Test
1. Deploy server with environment variables
2. Test server endpoints manually
3. Update iOS app configuration
4. Test in debug mode with local server

### Phase 2: Production Deployment
1. Deploy server to production
2. Update iOS app with production URLs
3. Test all features end-to-end
4. Submit app update

### Phase 3: Data Population
1. Use admin endpoints to import initial books
2. Generate summaries for popular books
3. Monitor server performance
4. Set up monitoring and backups

## API Usage Examples

### Import a Book by ISBN
```bash
curl -X POST https://your-server.com/api/books/import \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-admin-token" \
  -d '{"isbn": "9781491973899"}'
```

### Generate Summary
```bash
curl -X POST https://your-server.com/api/summaries/book/{bookId}/generate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-admin-token" \
  -d '{"style": "full"}'
```

### Search Books
```bash
curl "https://your-server.com/api/books/search?q=leadership"
```

## Troubleshooting

### Common Issues

#### 1. Connection Errors
- Check server URL in app configuration
- Verify server is running and accessible
- Check firewall and CORS settings

#### 2. Authentication Errors
- Verify Supabase keys are correct
- Check JWT token expiration
- Ensure user has admin role for admin endpoints

#### 3. API Quota Exceeded
- Monitor Google Books API usage
- Implement request throttling
- Consider caching strategies

#### 4. Summary Generation Fails
- Check Anthropic API key and quota
- Verify book description exists
- Check job queue status

### Debug Mode Features

In debug builds, the Settings screen includes:
- Manual data source switching
- Cache management tools
- Connection status indicator
- Debug logging toggle

### Rollback Plan

If issues occur, you can quickly rollback:
1. Change `currentDataSource` to `.local` in `AppConfiguration.swift`
2. Rebuild and redeploy app
3. App will use original bundled data

## Performance Optimization

### Caching Strategy
- Books cached for 30 minutes
- Summaries cached until updated
- Search results not cached (for freshness)
- Offline cache persists between app launches

### API Rate Limiting
- 100 requests per 15 minutes per IP
- Implement exponential backoff for failed requests
- Use background queue for summary generation

### Monitoring
- Health check endpoint: `/health`
- Monitor API response times
- Track cache hit rates
- Monitor database performance

## Cost Estimation

### Monthly Operating Costs
- Server hosting: $10-50 (Railway/Vercel)
- Supabase database: $25-100 (depending on usage)
- Claude API: $50-500 (depends on summary generation volume)
- Google Books API: Free (generous quota)
- Redis: $15-30 (if external)

**Total: ~$100-700/month** depending on usage

## Security Considerations

- All API endpoints use HTTPS
- Admin operations require authentication
- Rate limiting prevents abuse
- Input validation on all endpoints
- SQL injection protection via parameterized queries
- CORS properly configured

## Next Steps

After successful migration:
1. Set up monitoring and alerts
2. Implement user accounts and personalization
3. Add more book sources (Open Library, etc.)
4. Implement book comparison features
5. Add social features (reviews, ratings)
6. Consider push notifications for new summaries