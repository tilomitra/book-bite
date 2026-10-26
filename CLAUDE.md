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
npm run update-book-covers / update-popularity-scores / populate-headway-books
```
Audio ≈ $0.94/book (GPT-4o script + ElevenLabs Turbo v2.5). Default voice Adam `pNInz6obpgDQGcFmaJgB`; others: Bella `EXAVITQu4vr4xnSDxMaL`, Rachel `21m00Tcm4TlvDq8ikWAM`, Antoni `ErXwobaYiN019PkySvjV`.

### Database
Schema: `server/supabase/schema.sql` plus loose SQL files in `server/supabase/` (featured/NYT/extended-summary columns). Apply via the Supabase SQL editor; `migrations/` is empty. ~1,650 books.

## iOS architecture

- `App/`: `BookBiteApp` (entry; handles `bookbite://book/<id>?title=&author=&cover=` via `SharingService`, publishes the server URL to the widget), `RootView` (system `TabView`: Discover, Search, Library — **each tab is already wrapped in a `NavigationStack`; don't add another inside tab root views**), `Configuration/AppConfiguration` (server URL, flags), `DependencyContainer` (`@MainActor` singleton: repositories, `authService`, `searchService`).
- `Core/Repositories`: `BookRepository` protocol; `RemoteBookRepository` does all API calls (books, summaries, summary-generation jobs, favorites). Favorites send the Supabase access token from `SupabaseAuthService.getAccessToken()`.
- `Core/Services`:
  - `NetworkService`: generic `get/post/put/delete`. Use `NetworkService.makeDecoder()` for any server/Supabase JSON (ISO8601 dates with or without fractional seconds). Retries only transient failures of GET requests; decoding failures throw `.decodingError` immediately; POST takes a `timeout:` (book request uses 180s because the server runs the LLM synchronously).
  - `SearchService`: hits `/books/search?source=local` directly with `URLSession.shared` (not via the repository); tests stub it with a `URLProtocol`.
  - `SupabaseAuthService`: talks to Supabase Auth REST directly; session persisted in UserDefaults. Sign-in is optional (anonymous use is allowed).
  - `AudioPlaybackService` (shared, `@MainActor`): AVPlayer + lock-screen controls; `MiniAudioPlayer` overlay in `RootView`.
  - `RecentBooksStore` (shared, `@MainActor`): books opened in `BookDetailView`, newest first, max 20, in UserDefaults (works signed out).
  - `WidgetBridge`: writes the server URL and the latest `DailyIdea` JSON to the app group `group.tilo.BookBite` and reloads widget timelines.
  - `CacheService`, `OfflineStorageService` (downloads of saved books; `HybridBookRepository` falls back to it), `ExportService` (PDF/text, no UI yet).
- Cover images: always build URLs with `URL.bookCover(from:)` (`Shared/Utilities/URLHelpers.swift`). Stored Google Books URLs are `zoom=1&edge=curl` (128px, page curl baked in); the helper forces https, drops `edge` and adds `fife=w800`. Keep `zoom=1`: without it Google sometimes returns the title page. The widget does the same inline (`fife=w400`).
- `Core/Models`: `Book` and `Summary` use snake_case `CodingKeys` matching the DB columns. `Summary`/`KeyIdea` have lenient `init(from:)` (nullable columns, unknown confidence → `.medium`). Use `summary.summaryReadTimeMinutes` for display; the stored `read_time_minutes` is an unreliable LLM guess (often the whole book's length).
- `Features/<Feature>/{Views,ViewModels}`:
  - Featured = **Discover** tab, "editorial" style: hidden nav bar with a custom serif header (date + "Discover"), `Color.paper` background, `DailyIdeaCard` as a pull quote between rules (via the `DailyIdeaProviding` repository protocol; failure hides it), then one `BookShelf` per genre (serif title; `ShelfBookCard` = `EditorialCover` + title + author), "See all" → `BookGridView`. `EditorialCover` is the 2:3 cover with book-shaped corners and shadow.
  - Search = **Search** tab (`BookSearchView`): `.searchable`, live search (350 ms debounce in `SearchViewModel`); empty query shows the category list (`LibraryViewModel` → `CategoryBooksView`). "Request it" links push `RequestView` (Google Books search → request new book).
  - Library = **Library** tab (`Features/MyLibrary`, `MyLibraryView`/`MyLibraryViewModel`; named "My" because `LibraryViewModel` is Search's category list): editorial header with an account button that opens `SettingsView` in a sheet, then shelves "Recently opened" (`RecentBooksStore`), "Saved" (favorites; signed out shows a sign-in prompt), "Downloaded" (offline books).
  - Navigation to a book from shelves, grids and the idea card uses the iOS 18 zoom transition: `.navigationTransition(.zoom(sourceID: book.id, in: ns))` on `BookDetailView`, `.zoomSource(id:in:)` (wraps `matchedTransitionSource`) on the cover. Each `BookShelf`/`BookGridView`/`DailyIdeaCard` owns its `@Namespace`.
  - BookDetail: `BookDetailView` is one reading page on `Color.paper` with a wash of the cover's color behind the header (`CoverTint.color(for:)`: CIAreaAverage of the cover, saturation boosted, cached per URL); cover is `EditorialCover(width: 160)`. Opening it records the book in `RecentBooksStore`. (header, Read/Listen/Ask actions, hook, key ideas, how to apply, who it's for). "Read summary" pushes `SummaryReaderView` (extended summary, serif, text size in `@AppStorage("readerTextSize")`). Chat opens as a sheet. Bookmark = favorite (needs sign-in; downloads the book for offline).
  - AudioPlayer, Settings (downloaded books, clear cache, version), Authentication.
- Editorial tab roots (Discover, Library) hide the navigation bar with `.editorialNavigationBar()` and use `EditorialHeader(title:caption:trailing:)` (`Shared/Components`); keep the header visible in loading/error states too (UI test relies on it). Pass `caption:`/`trailing:` with labels: an unlabeled trailing closure binds to `trailing`.
- Design rule: keep the UI monochrome and quiet. No badges, ratings, or decorative color on book lists; color comes from book covers only. `Shared/Design/DesignSystem.swift` still holds old tokens used by Request/Auth/Audio views.

## Widget (`BookBiteWidget/DailyIdeaWidget.swift`)

Self-contained (shares no app source files): its own lightweight `WidgetDailyIdea` decoder. The timeline provider fetches `/summaries/daily-idea?date=<local yyyy-MM-dd>` from the server URL the app stored in the app group (default production), falls back to the app's cached idea, downloads the cover, and refreshes at local midnight. Tapping opens `bookbite://book/<id>?…&cover=`. Both targets have the `group.tilo.BookBite` app group entitlement (`BookBite/BookBite.entitlements` now also wired via `CODE_SIGN_ENTITLEMENTS`). The project uses file-system-synchronized groups, so new files in `BookBiteWidget/` join the target automatically (`Info.plist` is excluded).

## Roadmap

`TODO.md` lists the remaining design ideas (key-idea cards, Continue reading, Live Activity, App Intents, Lock Screen widgets, covers, accessibility, showing analysis/citations).

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
