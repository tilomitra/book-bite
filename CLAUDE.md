# CLAUDE.md

Guidance for Claude Code when working in this repository. Keep it accurate: update it whenever the architecture, commands, or gotchas change.

## What this is

BookBite shows AI-generated non-fiction book summaries (one-sentence hook, key ideas, how-to-apply, extended summary, audio summary, chat-with-the-book).

- **iOS app** (`BookBite/`): SwiftUI, MVVM, iOS 18.5+ deployment target, bundle id `tilo.BookBite`. Built with Xcode 26 (iOS 26 simulator SDK).
- **Widget extension** (`BookBiteWidget/`, target `BookBiteWidget`, bundle id `tilo.BookBite.BookBiteWidget`): "Idea of the Day" Home Screen widget (small, medium), embedded in the app.
- **Server** (`server/`): Express + TypeScript, Supabase (Postgres) for data, OpenAI for summaries/chat, ElevenLabs for audio, Bull/Redis for the summary job queue.
- The app is **remote-only**: all books/summaries come from the server. There is no bundled data or offline-first mode (only per-book offline downloads via `OfflineStorageService`). `HybridBookRepository` is just a wrapper around `RemoteBookRepository`.

## Running it locally (do this first)

```bash
# 1. Server (needs server/.env; Redis must be running for summary jobs)
cd server && npm install && PORT=3001 npx tsx src/index.ts   # dev: npm run dev (port 3000)

# 2. iOS: build, install, launch pointing at the local server
xcodebuild -project BookBite.xcodeproj -scheme BookBite \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/bb-dd build
xcrun simctl boot 'iPhone 17 Pro'
xcrun simctl install booted /tmp/bb-dd/Build/Products/Debug-iphonesimulator/BookBite.app
SIMCTL_CHILD_BOOKBITE_SERVER_URL=http://localhost:3001/api xcrun simctl launch booted tilo.BookBite
```

### Known environment gotchas
- **Port 3000 is often taken** on this machine by another project's Next.js dev server. Don't kill it — run BookBite on 3001 and pass `BOOKBITE_SERVER_URL` (Debug builds read it; default `http://localhost:3000/api`). Release builds use `https://book-bite.onrender.com/api`.
- **Supabase project `yjejgiltdbuombrzdtbv` (free tier) pauses when idle.** Symptom: every DB-backed endpoint 500s with a Cloudflare "521 Web server is down" HTML page in the error. Only the user can restore it (Supabase dashboard); the Supabase MCP here is not authorized and there is no `supabase` CLI.
- **Render deploy (`book-bite.onrender.com`) is suspended**, so release builds have no backend.
- **No iOS simulator runtime may be installed** after Xcode updates (`xcrun simctl list runtimes` empty). Fix: `xcodebuild -downloadPlatform iOS` (~8 GB, run in background).
- `xcodebuild test` can shut the simulator down; re-boot it before installing/launching.
- `tsx` server startup takes several seconds; wait for `Server running on` before curling.
- A server left running on 3001 from an older checkout can be stale (e.g. `/summaries/daily-idea` → "Route not found"). Restart it after pulling.
- The `bookbite://` URL scheme is **not registered** (no Info.plist URL types), so `simctl openurl` and shared links can't open the app. The widget's `widgetURL` still works because widgets open their own app.

## Commands

### iOS
```bash
xcodebuild -project BookBite.xcodeproj -scheme BookBite -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild test -project BookBite.xcodeproj -scheme BookBite -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BookBiteTests
# single test: -only-testing:BookBiteTests/SearchServiceTests/testSearchByTitle
```
Unit tests use Swift Testing (`@Test`, `#expect`); 50 tests, all should pass. UI tests (`BookBiteUITests`) are XCTest templates.

### Server
```bash
cd server
npm run dev        # tsx watch
npm run build      # tsc
npx tsc --noEmit   # type-check
npm test           # jest (basic smoke tests)
npm run lint       # eslint, config in server/.eslintrc.cjs
```

### Data scripts (`server/scripts/`, all call services directly, cost real API money)
```bash
npm run populate-books                      # Google Books + NYT, with AI summaries
npm run add-curated-books -- --dry-run      # ~$0.003/book; hand-picked list in scripts/data/curated-books.json (Open Library covers); drop --dry-run to insert + summarize
npx tsx scripts/populate-books.ts 30 high google   # [booksPerCategory] [priority] [source]
npm run generate-summaries                  # books missing summaries
npm run generate-extended-summaries
npm run generate-audio -- --title "Atomic Habits"   # or --book-id <uuid>, --list-missing, --dry-run, --force --voice-id <id>
npm run backfill-covers -- --dry-run --featured --report /tmp/covers.json   # see "Covers" below; drop --dry-run to write
npm run embed-books -- --dry-run            # see "Recommendations"; only re-embeds books whose text changed, a few cents for all
npm run update-reader-counts -- --dry-run   # free; sets popularity_score = Open Library reader count for every book (see below)
npm run update-book-covers / populate-headway-books
```
`popularity_score` is the Open Library reader count (users who marked the book want-to-read/reading/read; e.g. 48 Laws of Power ≈ 52k, most books < 500, 0 = no match). Both `update-reader-counts` and `add-curated-books` pick the matching work with the most readers, which avoids linking to an obscure edition. Don't run the old `update-popularity-scores` (Google Books rating formula, a different scale; it overwrites 0 scores). Featured flag (`is_featured`) is separate: new books aren't featured, so they don't appear on Discover's genre shelves until flagged.
Audio ≈ $0.94/book (GPT-4o script + ElevenLabs Turbo v2.5). Default voice Adam `pNInz6obpgDQGcFmaJgB`; others: Bella `EXAVITQu4vr4xnSDxMaL`, Rachel `21m00Tcm4TlvDq8ikWAM`, Antoni `ErXwobaYiN019PkySvjV`.

### Database
Schema: `server/supabase/schema.sql` plus loose SQL files in `server/supabase/` (featured/NYT/extended-summary columns, `add-book-embeddings.sql` for pgvector). Apply via the Supabase SQL editor; `migrations/` is empty. ~2,060 books.

## iOS architecture

- `App/`: `BookBiteApp` (entry; shows `OnboardingView` until `@AppStorage("hasCompletedOnboarding")`, then `RootView`; handles `bookbite://book/<id>?title=&author=&cover=` via `SharingService`, publishes the server URL to the widget), `RootView` (system `TabView`: Discover, Search, Library — **each tab is already wrapped in a `NavigationStack`; don't add another inside tab root views**), `Configuration/AppConfiguration` (server URL, flags), `DependencyContainer` (`@MainActor` singleton: repositories, `authService`, `searchService`).
- `Core/Repositories`: `BookRepository` protocol plus capability protocols (`DailyIdeaProviding`, `RecommendationsProviding`, …) that view models check with `as?`; `RemoteBookRepository` does all API calls (books, summaries, summary-generation jobs, favorites, recommendations), and `HybridBookRepository` must forward each new one. Favorites send the Supabase access token from `SupabaseAuthService.getAccessToken()`.
- `Core/Services`:
  - `NetworkService`: generic `get/post/put/delete`. Use `NetworkService.makeDecoder()` for any server/Supabase JSON (ISO8601 dates with or without fractional seconds). Retries only transient failures of GET requests; decoding failures throw `.decodingError` immediately; POST takes a `timeout:` (book request uses 180s because the server runs the LLM synchronously).
  - `SearchService`: hits `/books/search?source=local` directly with `URLSession.shared` (not via the repository); tests stub it with a `URLProtocol`.
  - `SupabaseAuthService`: talks to Supabase Auth REST directly; session persisted in UserDefaults. Sign-in is optional (anonymous use is allowed).
  - `AudioPlaybackService` (shared, `@MainActor`): AVPlayer + lock-screen controls; `MiniAudioPlayer` overlay in `RootView`.
  - `RecentBooksStore` (shared, `@MainActor`): books opened in `BookDetailView`, newest first, max 20, in UserDefaults (works signed out).
  - `OnboardingPreferences`: onboarding taste answers in UserDefaults (`preferredGenres`, `readingGoals`, `likedBookIds`) plus the topic and goal lists. Goal ids must match `READING_GOALS` on the server.
  - `WidgetBridge`: writes the server URL and the latest `DailyIdea` JSON to the app group `group.tilo.BookBite` and reloads widget timelines.
  - `CacheService`, `OfflineStorageService` (downloads of saved books; `HybridBookRepository` falls back to it), `ExportService` (PDF/text, no UI yet).
- Cover images: always build URLs with `URL.bookCover(from:)` (`Shared/Utilities/URLHelpers.swift`). Older stored Google Books URLs are `books/content?…zoom=1&edge=curl` (128px, page curl baked in); the helper forces https, drops `edge` and adds `fife=w800`. Keep `zoom=1`: without it Google sometimes returns the title page. The widget does the same inline (`fife=w400`). Backfilled covers (see "Covers") pass through unchanged.
- Show covers with `EditorialCover(book:width:)` / `BookCoverView(book:size:)`: with the book they fall back to `TypographicCover` (Shared/Components; serif title + author on a bookcloth colour picked from the title) when `cover_url` is null or fails to load. `BookDetailView` tints with `TypographicCover.cloth(for:)` when there is no image.
- `Core/Models`: `Book` and `Summary` use snake_case `CodingKeys` matching the DB columns. `Summary`/`KeyIdea` have lenient `init(from:)` (nullable columns, unknown confidence → `.medium`). Use `summary.summaryReadTimeMinutes` for display; the stored `read_time_minutes` is an unreliable LLM guess (often the whole book's length).
- `Features/<Feature>/{Views,ViewModels}`:
  - Featured = **Discover** tab, "editorial" style: hidden nav bar with a custom serif header (date + "Discover"), `Color.paper` background, `DailyIdeaCard` as a pull quote between rules (via the `DailyIdeaProviding` repository protocol; failure hides it), then the personal shelves from `POST books/for-you` ("For you", "More like …", goal shelves; see "Recommendations"), then one `BookShelf` per genre (serif title; `ShelfBookCard` = `EditorialCover` + `book.shelfTitle` (no subtitle) + `book.shelfAuthor` (first author, "& others"); nothing truncates: titles and card text wrap, so the row is an `HStack`, since a `LazyHStack` sizes to its first card and clips taller ones; `BookShelf(heading:)` turns "More like X" into a small-caps "MORE LIKE" eyebrow over title X), "See all" → `BookGridView`. With recommendation scores, genre shelves are ordered by affinity (mean score of their 5 closest books, +0.05 for picked topics) and books within a shelf by score; without them (request empty or failed) picked topics come first and books are by popularity. `EditorialCover` is the 2:3 cover with book-shaped corners and shadow.
  - Search = **Search** tab (`BookSearchView`): `.searchable`, live search (350 ms debounce in `SearchViewModel`); empty query shows the category list (`LibraryViewModel` → `CategoryBooksView`). "Request it" links push `RequestView` (Google Books search → request new book).
  - Library = **Library** tab (`Features/MyLibrary`, `MyLibraryView`/`MyLibraryViewModel`; named "My" because `LibraryViewModel` is Search's category list): editorial header with an account button that opens `SettingsView` in a sheet, then shelves "Recently opened" (`RecentBooksStore`), "Saved" (favorites; signed out shows a sign-in prompt), "Downloaded" (offline books).
  - Navigation to a book from shelves, grids and the idea card uses the iOS 18 zoom transition: `.navigationTransition(.zoom(sourceID: book.id, in: ns))` on `BookDetailView`, `.zoomSource(id:in:)` (wraps `matchedTransitionSource`) on the cover. Each `BookShelf`/`BookGridView`/`DailyIdeaCard` owns its `@Namespace`.
  - BookDetail: `BookDetailView` is one reading page on `Color.paper` with a wash of the cover's color behind the header (`CoverTint.color(for:)`: CIAreaAverage of the cover, saturation boosted, cached per URL); cover is `EditorialCover(width: 160)`. Opening it records the book in `RecentBooksStore`. (header, Read/Listen/Ask actions, hook, key ideas, how to apply, who it's for). "Read summary" pushes `SummaryReaderView` (extended summary, serif, text size in `@AppStorage("readerTextSize")`). Chat opens as a sheet. Bookmark = favorite (needs sign-in; downloads the book for offline).
  - Onboarding (`Features/Onboarding`, first launch only): `WelcomeView` (featured covers and feature icons orbiting the "B" mark on three rings via `TimelineView`, background washed with `CoverTint` colours of the first covers) → "Get Started" raises `OnboardingAuthSheet` (Apple, email sign-up/sign-in, or browse as guest; email confirmation projects get a "check your inbox" state) → `TopicsView` (genres → `OnboardingPreferences.preferredGenres`) → `GoalsView` (reading goals → `readingGoals`) → `LovedBooksView` (grid of the 36 most popular featured books with covers, picked topics first → `likedBookIds`; skipped when offline) → `NotificationsPromptView` (`DailyIdeaReminder` schedules a repeating 8 AM local notification). `OnboardingPreferences.migrateExistingInstall()` marks onboarding done for installs with a saved session or guest choice. To see onboarding again: delete the app, or launch with `-hasCompletedOnboarding NO`; UI tests pass `-hasCompletedOnboarding YES`.
  - AudioPlayer, Settings (downloaded books, clear cache, version), Authentication (`AuthenticationView`, the older sign-in sheet still used from Library/BookDetail).
- Editorial tab roots (Discover, Library) hide the navigation bar with `.editorialNavigationBar()` and use `EditorialHeader(title:caption:trailing:)` (`Shared/Components`); keep the header visible in loading/error states too (UI test relies on it). Pass `caption:`/`trailing:` with labels: an unlabeled trailing closure binds to `trailing`.
- Design rule: keep the UI monochrome and quiet. No badges, ratings, or decorative color on book lists; color comes from book covers only. `Shared/Design/DesignSystem.swift` still holds old tokens used by Request/Auth/Audio views.

## Widget (`BookBiteWidget/DailyIdeaWidget.swift`)

Self-contained (shares no app source files): its own lightweight `WidgetDailyIdea` decoder. The timeline provider fetches `/summaries/daily-idea?date=<local yyyy-MM-dd>` from the server URL the app stored in the app group (default production), falls back to the app's cached idea, downloads the cover, and refreshes at local midnight. Tapping opens `bookbite://book/<id>?…&cover=`. Both targets have the `group.tilo.BookBite` app group entitlement (`BookBite/BookBite.entitlements` now also wired via `CODE_SIGN_ENTITLEMENTS`). The project uses file-system-synchronized groups, so new files in `BookBiteWidget/` join the target automatically (`Info.plist` is excluded).

## Roadmap

`TODO.md` lists the remaining design ideas (key-idea cards, Continue reading, Live Activity, App Intents, Lock Screen widgets, covers, accessibility, showing analysis/citations).

## Recommendations

Personal Discover shelves from embeddings. `server/supabase/add-book-embeddings.sql` adds pgvector, the `book_embeddings` table (one `text-embedding-3-small` vector per book, separate from `books` so `select *` stays small, `content_hash` to skip unchanged books) and the `match_books(taste, exclude_ids, match_count)` RPC (cosine, books with a summary only, service key only). `scripts/embed-books.ts` fills it from title, authors, categories, description, hook, key ideas and "who should read"; re-run it after adding books or summaries.

`POST /api/books/for-you` (`recommendationService.ts`) takes `{likedBookIds, recentBookIds, goals, genres}` (sent by the app from onboarding answers and `RecentBooksStore`; POST keeps them out of URLs). It builds a taste vector: weighted, normalized sum of liked books (1.0), recently opened books (0.7, ×0.85 per position), goals (0.8) and topics (0.4). Goals and topics are embedded from server-side text keyed by id/genre name (clients can't make it embed arbitrary text), cached in memory. It returns `shelves` ("For you", up to 2 "More like <title>" from the newest seeds, up to 2 goal shelves mixing goal + 30% taste; ranked by similarity +0.05 for "known" books (featured, NYT, a popularity rank, or ≥ 100 Open Library readers) because the catalog has many obscure self-published titles that match topics closely; known books excluded, max 2 books per author, one edition per book (main title + author), later shelves avoid the first 12 of earlier ones and their other editions, shelves under 4 books dropped) and `scores` (similarity for the 400 closest books). Empty request → empty response. All ~2,160 books are embedded (2026-10-26; a full run is ~925k tokens, about $0.02). If a run dies on a network error, re-run it: it resumes from the hashes. If the endpoint fails, the app falls back to the default Discover order. Signed-in favorites and reading history aren't used yet.

## Covers

`server/scripts/backfill-covers.ts` picks the sharpest cover per book and writes it to `books.cover_url`: Google Books publisher image (`books/publisher/content/images/frontcover/<id>?fife=w1200-h1800`, the original artwork) → the same for other Google editions with matching title + author surname → Apple Books by ISBN (never by title: "Drive" matched the wrong book) → Open Library → current URL. First candidate ≥500px wide with aspect 1.1–1.8 wins; else the largest ≥320px; else `null` (app shows `TypographicCover`). URLs are stored directly (Google/Apple are resizing CDNs; rehosting ~2k covers would hit the Supabase free-tier 1 GB storage). Replaced URLs are kept in `server/scripts/data/cover-url-backup.json` (oldest URL wins on re-runs). By default it skips books already on Google publisher/Apple URLs, so re-run it after adding books; new books still get 128px `books/content` URLs from the importers. iTunes lookup is rate limited (~20/min), so a full run takes a while. The other-edition step uses the Google Books API key, whose daily query quota a full run can exhaust (that also breaks the server's Google search / book requests until midnight Pacific); the script stops and saves what it checked when that happens. `--ids a,b` re-checks specific books. Check `--report` output visually before writing: other-edition matches are the riskiest.

## Server architecture

`src/index.ts` → routes → controllers (HTTP only) → services (business logic, Supabase/API calls). Zod schemas/types in `src/models/types.ts`. All handlers wrap in try/catch and call `next(err)`; `middleware/errorHandler.ts` maps messages to status codes (invalid uuid → 400, "not found" → 404). Stack traces only when `DEBUG_ERRORS=true`.

Routes (prefix `/api`):
- `books`: `/`, `/featured`, `/nyt-bestsellers`, `/search`, `/categories`, `/category/:category`, `/:id`, `/:id/cover`; admin POST/PUT/DELETE.
- `summaries`: `/book/:bookId`, `POST /book/:bookId/generate` (public, rate-limited 20/h/IP), `/job/:jobId`, `/daily-idea?date=YYYY-MM-DD` ("Idea of the day": `{date, book, idea, hook}`, same pick for everyone on a date, from featured books with summaries; logic in `dailyIdeaService.ts`); admin list/update/delete.
- `search`: `/books` (Google Books), `/book/:googleBooksId`, `POST /request` (adds book + generates summaries synchronously; 409 with `{book}` if it exists).
- `books/:bookId/chat/...` (conversations, messages, SSE streaming), `books/:bookId/ratings`, `isbn/:isbn/ratings`.
- `user/*` (favorites, reading-history, recommendations) and `auth/*` (profile, stats, account) require `Authorization: Bearer <supabase jwt>`.
- `audio/book/:bookId`, `audio/job/:jobId` public; `audio/.../generate`, `audio/missing`, `audio/quota` admin-only.

Behaviour worth knowing:
- Admin = Supabase JWT with `app_metadata.role === 'admin'` (never trust `user_metadata`, users can write it).
- PostgREST returns at most 1000 rows per request; `BookService.fetchAllBooks()` pages through for categories. `?limit` is clamped to 1–1000, `?page` ≥ 1.
- Search fetches all matches' ids/titles, ranks title-exact > title-prefix > title-contains > subtitle > description, then loads the page. Search terms are sanitized for PostgREST `.or()` (commas/parens break it). Google Books results (non-UUID ids) are appended only for `source=all|google` after local results run out.
- Summary generation: `generate` returns `{id, bookId, status}`; if a summary exists it returns `id: "existing-<bookId>", status: "completed"` and the app fetches the summary directly. `/job/:jobId` returns the same camelCase shape. The Bull worker updates the DB job via `job.data.jobId`. `getSummaryByBookId` takes the newest row (regeneration can create duplicates).
- `app.set('trust proxy', 1)` for Render.

## Environment (`server/.env`, see `.env.example`)
`PORT`, `NODE_ENV`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY`, `GOOGLE_BOOKS_API_KEY`, `NYT_API_KEY`, `OPENAI_API_KEY`, `ELEVENLABS_API_KEY`, `REDIS_URL`, `RATE_LIMIT_WINDOW_MS`, `RATE_LIMIT_MAX_REQUESTS`, `CORS_ORIGIN`, optional `DEBUG_ERRORS`.

## Known open issues
- Discover tab only loads the first 100 of ~216 featured books (default `limit=100`).
- Some covers (Open Library) load slowly via redirects; makeheadway.com covers are hotlinked.
- `BookDetailViewModel` polling `Task` captures `self` strongly (bounded to 5 min).
- `SearchService` bypasses the injected repository.
- The summary's analysis fields (pitfalls, critiques, limitations) and citations are decoded but not shown in the app.
