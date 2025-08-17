# Book Cover Update Script

This script updates book cover images in the BookBite database using the Open Library Covers API.

## Features

- **High-quality covers**: Uses Open Library's extensive collection of book covers
- **Free API**: No API key required, respects rate limits (100 requests per 5 minutes)
- **Multiple sizes**: Supports Small (S), Medium (M), and Large (L) cover sizes
- **Smart filtering**: Only processes books with ISBN numbers
- **Rate limiting**: Built-in delays to respect API limits
- **Batch processing**: Processes books in manageable batches
- **Dry run mode**: Preview changes before making them
- **Comprehensive logging**: Detailed progress and error reporting
- **Database safety**: Only updates books without existing covers (unless forced)

## Usage

### Basic Commands

```bash
# Preview what would be updated (recommended first step)
npm run update-book-covers -- --dry-run

# Update all books missing covers
npm run update-book-covers

# Update a limited number of books
npm run update-book-covers -- --limit 50

# Force update even books that already have covers
npm run update-book-covers -- --force

# Use medium-sized covers instead of large
npm run update-book-covers -- --size M
```

### Command Options

- `--dry-run` - Show what would be updated without making changes
- `--limit <number>` - Limit number of books to process (default: all)
- `--force` - Update covers even if book already has a cover URL
- `--size <S|M|L>` - Cover size: S (small), M (medium), L (large) - default: L
- `--help` - Show help message

### Examples

```bash
# Safe preview of first 10 books
npm run update-book-covers -- --dry-run --limit 10

# Update 100 books with medium-sized covers
npm run update-book-covers -- --limit 100 --size M

# Force update all books with large covers
npm run update-book-covers -- --force
```

## How It Works

1. **Fetches books** from Supabase database that have ISBN numbers
2. **Filters books** that don't have covers (unless `--force` is used)
3. **Queries Open Library** for each book using ISBN-13 or ISBN-10
4. **Verifies cover exists** by checking both metadata and image availability
5. **Updates database** with the new cover URL
6. **Respects rate limits** with configurable delays between requests
7. **Provides detailed reporting** of successes and failures

## API Details

### Open Library Covers API
- **Base URL**: `https://covers.openlibrary.org`
- **Format**: `/b/isbn/{isbn}-{size}.jpg`
- **Sizes**: S (small ~180px), M (medium ~360px), L (large ~580px)
- **Rate Limit**: 100 requests per 5 minutes per IP
- **Free**: No API key required

### Cover URL Format
```
https://covers.openlibrary.org/b/isbn/9780385533225-L.jpg
```

## Error Handling

The script handles various error scenarios:
- Books without ISBN numbers (skipped)
- Covers not found in Open Library (logged)
- Network errors (retried with delays)
- Database update failures (logged with details)

## Performance

- **Rate limiting**: 3-second delays between requests (well under API limits)
- **Batch processing**: Processes books in batches of 20
- **Progress tracking**: Real-time progress updates
- **Memory efficient**: Streams results rather than loading all data

## Monitoring

The script provides comprehensive output:
- Real-time progress for each book
- Summary statistics at the end
- Detailed error reporting for failures
- List of successful updates with new URLs

## Best Practices

1. **Always run dry-run first** to preview changes
2. **Start with small limits** when testing
3. **Monitor API usage** to stay within rate limits
4. **Check results** in the database after running
5. **Use appropriate cover sizes** for your application needs

## Troubleshooting

### Common Issues

**"No books found to process"**
- Books may already have cover URLs (use `--force` to override)
- Books may be missing ISBN numbers
- Check database connection

**"Cover not found"**
- Some books may not be in Open Library's collection
- ISBN may be incorrect in your database
- Try alternative cover sources for missing books

**"Rate limit exceeded"**
- Script has built-in delays to prevent this
- If it occurs, wait 5 minutes and retry
- Consider reducing batch size

### Environment Requirements

Ensure these environment variables are set:
```bash
SUPABASE_URL=your_supabase_project_url
SUPABASE_SERVICE_KEY=your_supabase_service_key
```