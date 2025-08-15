# BookBite Server

Node.js/Express API server for the BookBite iOS application. Provides book metadata, AI-generated summaries, and content management capabilities.

## Features

- **Book Management**: CRUD operations for books with metadata from Google Books API
- **AI Summaries**: Generate book summaries using Claude (Anthropic) API
- **Search**: Full-text search across books with external API integration
- **Authentication**: Supabase Auth integration with role-based access control
- **Background Jobs**: Async summary generation using Bull/Redis
- **Caching**: Redis-based caching for improved performance
- **Rate Limiting**: API rate limiting and security middleware

## Tech Stack

- **Framework**: Express.js with TypeScript
- **Database**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth
- **AI**: Anthropic Claude API (@anthropic-ai/sdk)
- **External APIs**: Google Books API
- **Queue**: Bull (Redis)
- **Caching**: NodeCache + Redis
- **Validation**: Zod

## Setup

### 1. Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

Required environment variables:
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_KEY` - Supabase service role key
- `GOOGLE_BOOKS_API_KEY` - Google Books API key
- `ANTHROPIC_API_KEY` - Claude API key
- `REDIS_URL` - Redis connection URL

### 2. Install Dependencies

```bash
npm install
```

### 3. Setup Supabase Database

1. Create a new Supabase project
2. Run the schema migration:
   ```bash
   # Copy the contents of supabase/schema.sql and run it in Supabase SQL editor
   ```

### 4. Setup Redis (for background jobs)

Local development:
```bash
# macOS with Homebrew
brew install redis
brew services start redis

# Or using Docker
docker run -d -p 6379:6379 redis:alpine
```

### 5. Start Development Server

```bash
npm run dev
```

Server will start on http://localhost:3000

## API Endpoints

### Books

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/api/books` | List all books (paginated) | Public |
| GET | `/api/books/search?q=query` | Search books | Public |
| GET | `/api/books/:id` | Get book by ID | Public |
| GET | `/api/books/:id/cover` | Get book cover | Public |
| POST | `/api/books` | Create new book | Admin |
| POST | `/api/books/import` | Import book by ISBN | Admin |
| PUT | `/api/books/:id` | Update book | Admin |
| DELETE | `/api/books/:id` | Delete book | Admin |

### Summaries

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/api/summaries/book/:bookId` | Get summary for book | Public |
| GET | `/api/summaries/job/:jobId` | Check generation job status | Public |
| GET | `/api/summaries` | List all summaries | Admin |
| POST | `/api/summaries/book/:bookId/generate` | Generate summary | Admin |
| PUT | `/api/summaries/:id` | Update summary | Admin |
| DELETE | `/api/summaries/:id` | Delete summary | Admin |

### Health Check

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Server health status |

## Authentication

The API uses Supabase Auth with JWT tokens. Include the token in requests:

```
Authorization: Bearer <jwt-token>
```

Admin endpoints require users with `role: 'admin'` in their user metadata.

## Book Import Workflow

1. Search external APIs (Google Books) for book metadata
2. Import book data into local database
3. Generate AI summary asynchronously
4. Cache results for fast retrieval

## Summary Generation

Summaries are generated using Claude 3.5 Sonnet with structured prompts:
- **Brief**: 3-4 key ideas, 2-3 application points
- **Full**: 5-7 key ideas, 4-5 application points

Generation happens asynchronously via background jobs to handle API rate limits and processing time.

## Development

### Scripts

- `npm run dev` - Start development server with hot reload
- `npm run build` - Build TypeScript to JavaScript
- `npm start` - Start production server
- `npm run lint` - Run ESLint
- `npm test` - Run tests

### Project Structure

```
src/
├── config/          # Configuration files
├── controllers/     # Request handlers
├── middleware/      # Express middleware
├── models/          # TypeScript types and schemas
├── routes/          # Express routes
├── services/        # Business logic
└── utils/           # Utility functions
```

## Deployment

### Railway (Recommended)

1. Connect your GitHub repository to Railway
2. Set environment variables in Railway dashboard
3. Railway will automatically deploy on git push

### Docker

```bash
docker build -t bookbite-server .
docker run -p 3000:3000 --env-file .env bookbite-server
```

## Rate Limits

- Default: 100 requests per 15 minutes per IP
- Configure via `RATE_LIMIT_WINDOW_MS` and `RATE_LIMIT_MAX_REQUESTS`

## Monitoring

Health check endpoint at `/health` returns:
```json
{
  "status": "ok",
  "timestamp": "2023-12-01T12:00:00.000Z"
}
```