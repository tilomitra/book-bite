# BookBite Server Scripts

This directory contains the essential scripts for managing books and summaries in the BookBite database.

## Available Scripts

### 📚 Book Population

#### `populate-books.ts` - Comprehensive Book Population
**Purpose**: The primary script for populating books from multiple sources (Google Books API + NYT Bestsellers API).

**Usage**:
```bash
# Default: 25 books per category, all priorities, all sources
npm run populate-books

# Predefined configurations
npm run populate-books-google      # Google Books only
npm run populate-books-nyt         # NYT Bestsellers only  
npm run populate-books-high-priority  # High priority categories only

# Custom configuration
npx tsx scripts/populate-books.ts [booksPerCategory] [priority] [source]
npx tsx scripts/populate-books.ts 30 high google
npx tsx scripts/populate-books.ts 15 all nyt
```

**Features**:
- 35+ Google Books categories + 16+ NYT bestseller lists
- Priority filtering (high/medium/low)
- Source filtering (google/nyt/all)
- Automatic deduplication across all sources
- Generates both regular and extended summaries
- Comprehensive progress tracking and error handling

### 🤖 Summary Generation

#### `generate-missing-summaries.ts` - Complete Summary Generation
**Purpose**: Generates both regular and extended summaries for books that don't have any summaries.

**Usage**:
```bash
# Default: 5 books per batch, max 100 books
npm run generate-summaries

# Custom batch processing
npx tsx scripts/generate-missing-summaries.ts [batchSize] [maxBooks]
npx tsx scripts/generate-missing-summaries.ts 3 50
```

**Features**:
- Creates complete summary records (regular + extended)
- Uses GPT-4 for regular summaries, GPT-3.5-turbo for extended
- Smart rate limiting and batch processing
- Comprehensive error handling and progress tracking

#### `generate-extended-summaries.ts` - Extended Summary Backfill
**Purpose**: Generates extended summaries for books that already have regular summaries but are missing extended ones.

**Usage**:
```bash
# Default: 3 books per batch, max 50 books
npm run generate-extended-summaries

# Custom batch processing  
npx tsx scripts/generate-extended-summaries.ts [batchSize] [maxBooks]
npx tsx scripts/generate-extended-summaries.ts 2 30
```

**Features**:
- Cost-effective extended summary generation only
- Uses GPT-3.5-turbo for cost efficiency
- Longer batch delays for cost control
- Word count tracking and reporting

### 🖼️ Utilities

#### `update-book-covers.ts` - Book Cover Enhancement
**Purpose**: Updates book cover images using Open Library API for better quality covers.

**Usage**:
```bash
npm run update-book-covers
```

**Features**:
- High-quality cover images from Open Library
- Multiple size options (S, M, L)
- Dry-run mode for testing
- Comprehensive error handling

## Script Consolidation

This directory was recently consolidated from 12+ scripts down to 4 essential ones:

### ✅ Kept Scripts:
- `populate-books.ts` - Unified book population (replaces 7 separate scripts)
- `generate-missing-summaries.ts` - Complete summary generation  
- `generate-extended-summaries.ts` - Extended summary backfill
- `update-book-covers.ts` - Cover image enhancement

### ❌ Removed Scripts:
- `populate-books-by-category.ts` - Merged into `populate-books.ts`
- `populate-nyt-bestsellers.ts` - Merged into `populate-books.ts`
- `populate-business-books.ts` - Redundant (covered by new script)
- `populate-featured-books.ts` - Redundant (covered by new script)
- `populate-food-travel-books.ts` - Redundant (covered by new script)
- `populate-nonfiction-books.ts` - Redundant (covered by new script)
- `setup-featured-books.ts` - Wrapper script (no longer needed)
- `generate-summaries.ts` - Outdated (used old database schema)

## Usage Recommendations

### 1. Initial Database Population
```bash
# Start with high-priority categories for best content
npm run populate-books-high-priority

# Add NYT bestsellers for popular books
npm run populate-books-nyt

# Fill in with broader categories as needed
npm run populate-books-google
```

### 2. Summary Generation Workflow
```bash
# Generate summaries for any books without them
npm run generate-summaries

# Backfill extended summaries if needed
npm run generate-extended-summaries
```

### 3. Maintenance
```bash
# Update book covers for better visual quality
npm run update-book-covers
```

## Environment Variables Required

- `GOOGLE_BOOKS_API_KEY` - For Google Books API access
- `NYT_API_KEY` - For NYT Bestsellers API access (optional)
- `OPENAI_API_KEY` - For AI summary generation
- `SUPABASE_URL` - Database connection
- `SUPABASE_SERVICE_KEY` - Database access

## Rate Limiting & Cost Management

All scripts include built-in rate limiting and cost management:
- Configurable batch sizes and delays
- Progress tracking and resumability
- Error handling and retry logic
- Cost-effective model selection (GPT-3.5-turbo for extended summaries)