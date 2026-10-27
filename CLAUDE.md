# CLAUDE.md

Guidance for Claude Code when working in this repository. Keep it accurate: update it whenever the architecture, commands, or gotchas change.

## What this is

BookBite shows AI-generated non-fiction book summaries (one-sentence hook, key ideas, how-to-apply, extended summary, audio summary, chat-with-the-book).

- **iOS app** (`BookBite/`): SwiftUI, MVVM, iOS 18.5+ deployment target, bundle id `tilo.BookBite`. Built with Xcode 26 (iOS 26 simulator SDK).
- **Widget extension** (`BookBiteWidget/`, target `BookBiteWidget`, bundle id `tilo.BookBite.BookBiteWidget`): "Idea of the Day" Home Screen widget (small, medium), embedded in the app.
- **Landing page** (`server/public/`): static one-page site served by the Express server at `/` (so `book-bite.onrender.com/`). See "Landing page" below.
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

### Physical iPhone
```bash
xcodebuild -project BookBite.xcodeproj -scheme BookBite -configuration Debug -destination 'id=00008140-000C69302EA2801C' \
  -derivedDataPath /tmp/bb-dd-device -allowProvisioningUpdates CODE_SIGN_ENTITLEMENTS=<copy of BookBite.entitlements without applesignin> build
xcrun devicectl device install app --device 436DAA2B-928F-54A1-9777-1FECF00A7994 /tmp/bb-dd-device/Build/Products/Debug-iphoneos/BookBite.app
```
- xcodebuild wants the hardware UDID (`xcodebuild -showdestinations`); devicectl uses the CoreDevice id (`xcrun devicectl list devices`).
- Team `H6DZU85MBF` is a free personal team: it can't sign Sign in with Apple, so device builds override `CODE_SIGN_ENTITLEMENTS` with an app-group-only file. Free-team installs expire after 7 days.
- Server URL resolution (Debug): `BOOKBITE_SERVER_URL` launch env var → Info.plist `BookBiteServerURL` (from the `BOOKBITE_SERVER_URL` build setting; set only for `sdk=iphoneos*` Debug to `http://Zenith.local:3001/api`, the Mac's Bonjour name) → `http://localhost:3000/api`. Info.plist has `NSAllowsLocalNetworking` for plain-http `.local` hosts. Phone and Mac must share Wi-Fi and the server must run on 3001.

### Known environment gotchas
- **Port 3000 is often taken** on this machine by another project's Next.js dev server. Don't kill it — run BookBite on 3001 and pass `BOOKBITE_SERVER_URL` (Debug builds read it; default `http://localhost:3000/api`). Release builds use `https://book-bite.onrender.com/api`.
- **Supabase project `yjejgiltdbuombrzdtbv` (free tier) pauses when idle.** Symptom: every DB-backed endpoint 500s with a Cloudflare "521 Web server is down" HTML page in the error. Only the user can restore it (Supabase dashboard); the Supabase MCP here is not authorized and there is no `supabase` CLI.
- **Render deploy** (`book-bite.onrender.com`, service `srv-d2h8n32dbo4c73aqd4q0`, Ohio, starter plan) auto-deploys `main` from `server/` with `yarn install && yarn build` / `yarn start`; Redis is the free Key Value `book-bite-redis` (`REDIS_URL=redis://red-dbg273p42hec73dc693g:6379`, internal only). `NODE_ENV=production` makes yarn skip devDependencies, so `YARN_PRODUCTION=false` must stay set or the build picks up Render's global (newer) `tsc` and fails on `moduleResolution`. yarn ignores `package-lock.json`, so TypeScript and Node (22.x) are pinned in `package.json`.
- **No iOS simulator runtime may be installed** after Xcode updates (`xcrun simctl list runtimes` empty). Fix: `xcodebuild -downloadPlatform iOS` (~8 GB, run in background).
- `xcodebuild test` can shut the simulator down; re-boot it before installing/launching.
- `tsx` server startup takes several seconds; wait for `Server running on` before curling.
- A server left running on 3001 from an older checkout can be stale (e.g. `/summaries/daily-idea` → "Route not found"). Restart it after pulling.
- The `bookbite://` URL scheme is registered in `BookBite/Info.plist` (merged with the generated plist via `INFOPLIST_FILE`; the file is excluded from the synchronized group's resources). Test: `xcrun simctl openurl booted 'bookbite://book/<uuid>?title=Atomic%20Habits'`.

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
npm run regenerate-extended-summaries -- --dry-run --limit 1   # rewrite existing extended summaries into the chapter format (see below); ~$0.0016/book, ~$3 for all
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

- `App/`: `BookBiteApp` (entry; shows `OnboardingView` until `@AppStorage("hasCompletedOnboarding")`, then `RootView`; handles `bookbite://book/<id>?title=&author=&cover=` via `SharingService` and Spotlight taps (`CSSearchableItemActionType`), publishes the server URL to the widget, starts `SpotlightIndexer`), `RootView` (system `TabView`: Discover, Search, Library — **each tab is already wrapped in a `NavigationStack`; don't add another inside tab root views**; Discover's stack has a `NavigationPath` and a `navigationDestination(for: BookRoute.self)`), `Configuration/AppConfiguration` (server URL, flags), `DependencyContainer` (`@MainActor` singleton: repositories, `authService`, `searchService`).
- Opening a book from outside the app goes through `DeepLinkRouter.shared` (`App/DeepLinkRouter.swift`): `open(bookId:partial:)` fetches the full book with `fetchBook(by:)` (5 s cap, falls back to the partial book from the link), then publishes `pending`; `RootView` consumes it (also on appear, so links during onboarding/cold launch wait) by switching to Discover and replacing its path with `[BookRoute(book)]`.
- `App/Intents/`: App Intents + `BookBiteShortcuts` (`AppShortcutsProvider`). `TodaysIdeaIntent` ("Today's idea in BookBite") fetches the idea of the day via `DailyIdeaProviding` (falls back to the widget's cached idea in the app group if it's today's), speaks it and shows `DailyIdeaSnippetView` (cover is downloaded up front because snippets render out of process). `ContinueReadingIntent` (`openAppWhenRun`) routes to `ReadingProgressStore.shared.inProgress.first`.
- `Core/Repositories`: `BookRepository` protocol plus capability protocols (`DailyIdeaProviding`, `RecommendationsProviding`, …) that view models check with `as?`; `RemoteBookRepository` does all API calls (books, summaries, summary-generation jobs, favorites, recommendations), and `HybridBookRepository` must forward each new one. Favorites send the Supabase access token from `SupabaseAuthService.getAccessToken()`.
- `Core/Services`:
  - `NetworkService`: generic `get/post/put/delete`. Use `NetworkService.makeDecoder()` for any server/Supabase JSON (ISO8601 dates with or without fractional seconds). Retries only transient failures of GET requests; decoding failures throw `.decodingError` immediately; POST takes a `timeout:` (book request uses 180s because the server runs the LLM synchronously).
  - `SearchService`: hits `/books/search?source=local` directly with `URLSession.shared` (not via the repository); tests stub it with a `URLProtocol`.
  - `SupabaseAuthService`: talks to Supabase Auth REST directly; session persisted in UserDefaults. Sign-in is optional (anonymous use is allowed).
  - `AudioPlaybackService` (shared, `@MainActor`): AVPlayer + lock-screen controls; `MiniAudioPlayer` overlay in `RootView`.
  - `RecentBooksStore` (shared, `@MainActor`): books opened in `BookDetailView`, newest first, max 20, in UserDefaults (works signed out).
  - `ReadingProgressStore` / `SavedIdeasStore` (shared, `@MainActor`, UserDefaults): reading position (+ the summary's length, for "N min left") + finished summaries, and kept key ideas. The reader and book page write them; Discover/Library read them. They encode dates as ISO 8601 because they decode with `NetworkService.makeDecoder()`; a mismatched encoder silently loses everything on relaunch (`LocalStoresTests` covers the round trip).
  - `OnboardingPreferences`: onboarding taste answers in UserDefaults (`preferredGenres`, `readingGoals`, `likedBookIds`) plus the topic and goal lists. Goal ids must match `READING_GOALS` on the server.
  - `SpotlightIndexer` (shared, `@MainActor`): indexes books from `RecentBooksStore` and `ReadingProgressStore` in CoreSpotlight (title, authors, cached summary hook or description, cover thumbnail) by subscribing to their published arrays; ids `book.<id>`, domain `books`. Only added/removed books are re-indexed (indexed ids in UserDefaults `spotlightIndexedBookIds`; bump `formatVersion` to re-index everything).
  - `WidgetBridge`: writes the server URL and the latest `DailyIdea` JSON to the app group `group.tilo.BookBite` and reloads widget timelines.
  - `CacheService`, `OfflineStorageService` (downloads of saved books; `HybridBookRepository` falls back to it), `ExportService` (PDF/text, no UI yet).
- Cover images: always build URLs with `URL.bookCover(from:)` (`Shared/Utilities/URLHelpers.swift`). Older stored Google Books URLs are `books/content?…zoom=1&edge=curl` (128px, page curl baked in); the helper forces https, drops `edge` and adds `fife=w800`. Keep `zoom=1`: without it Google sometimes returns the title page. The widget does the same inline (`fife=w400`). Backfilled covers (see "Covers") pass through unchanged.
- Show covers with `EditorialCover(book:width:)` / `BookCoverView(book:size:)`: with the book they fall back to `TypographicCover` (Shared/Components; serif title + author on a bookcloth colour picked from the title) when `cover_url` is null or fails to load. `BookDetailView` tints with `TypographicCover.cloth(for:)` when there is no image.
- `Core/Models`: `Book` and `Summary` use snake_case `CodingKeys` matching the DB columns. `Summary`/`KeyIdea` have lenient `init(from:)` (nullable columns, unknown confidence → `.medium`). Use `summary.summaryReadTimeMinutes` for display; the stored `read_time_minutes` is an unreliable LLM guess (often the whole book's length).
- `Features/<Feature>/{Views,ViewModels}`:
  - Featured = **Discover** tab, "editorial" style: hidden nav bar with a custom serif header (date + "Discover"), `Color.paper` background, `DailyIdeaCard` as a pull quote between rules (via the `DailyIdeaProviding` repository protocol; failure hides it), then an **endless feed** of `DiscoverBlock`s (`FeaturedBooksViewModel.blocks`, grown 6 at a time by `loadMore()` when the last 3 blocks appear). Two shelves, then one editorial card (`Views/EditorialCards.swift`: `SpotlightCard` = big cover on a wash of its `CoverTint` + title + hook; `QuickBitesCard` = 3 rows of cover/title/hook; `PassageCard` = one key idea as a quote on a light cover-tint wash), rotating. Cards come from `GET summaries/highlights?page=&limit=` (`HighlightsProviding`; books with a summary by Open Library readers, each with hook + one stable key idea; sorted by recommendation score within a page). After the genre shelves run out the feed keeps going with cards plus "More to explore"-style shelves built from highlights until the catalogue ends. **No book appears twice in the feed** (ids and title+first author, so other editions too, including the idea of the day; a shelf marks only its 12 previewed books; shelves left under 4 books are dropped). The feed is built from the personal shelves from `POST books/for-you` ("For you", "More like …", goal shelves; see "Recommendations"), then one `BookShelf` per genre (serif title; `ShelfBookCard` = `EditorialCover` + `book.shelfTitle` (no subtitle) + `book.shelfAuthor` (first author, "& others"); nothing truncates: titles and card text wrap, so the row is an `HStack`, since a `LazyHStack` sizes to its first card and clips taller ones; `BookShelf(heading:)` turns "More like X" into a small-caps "MORE LIKE" eyebrow over title X), "See all" → `BookGridView`. With recommendation scores, genre shelves are ordered by affinity (mean score of their 5 closest books, +0.05 for picked topics) and books within a shelf by score; without them (request empty or failed) picked topics come first and books are by popularity. `EditorialCover` is the 2:3 cover with book-shaped corners and shadow; it retries a failed load once, because `AsyncImage` reports a load cancelled by a re-render as a failure.
  - Search = **Search** tab (`BookSearchView`): `.searchable`, live search (350 ms debounce in `SearchViewModel`); empty query shows the category list (`LibraryViewModel` → `CategoryBooksView`). "Request it" links push `RequestView` (Google Books search → request new book).
  - Library = **Library** tab (`Features/MyLibrary`, `MyLibraryView`/`MyLibraryViewModel`; named "My" because `LibraryViewModel` is Search's category list): editorial header with an account button that opens `SettingsView` in a sheet, then: `LibraryIntro` (only when everything is empty: explains what fills the Library), "Continue reading" (`ContinueReadingSection`), "Notebook" (`NotebookPreview`: newest 3 kept ideas as serif pull quotes, "See all" → `NotebookView`, by book or newest first, swipe to remove/share, tap opens the book), "Recently opened" (`RecentBooksStore`, minus books under Continue reading), "Saved" (favorites; signed out shows a sign-in prompt), "Finished" (`BookShelf(caption:)` "N finished this year", `FinishedStats`), "Downloaded" (offline books). Pure logic (grouping, share text, finished count) is in `MyLibrary/ViewModels/Notebook.swift`.
  - Continue reading (`Shared/Components/ContinueReading.swift`, on Discover right under the header and in Library): most recent in-progress summary large (cover, serif title, hairline `ReadingProgressBar`, "N min left"), the next ones as compact rows. Minutes left = summary length × unread fraction (`ReadingTime`); the length comes only from the on-device summary (`CacheService`/offline download, full text only), never the network; unknown → "Pick up where you left off".
  - Navigation to a book from shelves, grids and the idea card uses the iOS 18 zoom transition: `.navigationTransition(.zoom(sourceID: book.id, in: ns))` on `BookDetailView`, `.zoomSource(id:in:)` (wraps `matchedTransitionSource`) on the cover. Each `BookShelf`/`BookGridView`/`DailyIdeaCard` owns its `@Namespace`.
  - BookDetail: `BookDetailView` is one reading page on `Color.paper` with a wash of the cover's color behind the header (`CoverTint.color(for:)`: CIAreaAverage of the cover, saturation boosted, cached per URL); cover is `EditorialCover(width: 168)`. Opening it records the book in `RecentBooksStore`. Order: header (serif title, italic subtitle, small-caps authors, year), hook as a centered serif dek, actions, then `DetailSection`s (hairline + serif heading): Key ideas, How to apply it, Who it's for, The other side. The primary button reads `ReadingProgressStore` ("Read summary · N min" / "Continue reading · N min left" with a progress hairline / "Read again" ✓) and pushes `SummaryReaderView` (helpers in `Views/Reader/`): `ReaderDocument` parses the extended summary into chapters at `## ` lines (no headings → one untitled chapter; stray markdown stripped; soft hyphens inserted for hyphenation), contents menu when there are 2+ titled chapters, raised initial + small-caps lead-in, themes Paper/Sepia/Night, Serif/Sans and text size in a popover (`@AppStorage` `readerTheme`, `readerTypeface`, `readerTextSize`; size scales with Dynamic Type), tab bar hidden, hairline progress + "N min left" in the nav bar. Records position in `ReadingProgressStore` (throttled, after the user scrolls), resumes unfinished books, and calls `markFinished` with a soft haptic on reaching the end section. Key ideas are a `KeyIdeaDeck` (`KeyIdeaDeck.swift`): full-width `.paging` pages (one card each, equal height via `fixedSize` on the HStack, edges of the next cards drawn under the current one), "3 of 7" + chevrons, soft haptic per page, VoiceOver sees only the current card (adjustable action turns pages). Each card has Keep (`SavedIdeasStore.toggle`) and Share: `IdeaShareCard` (`IdeaShareCard.swift`) rendered with `ImageRenderer` at 3x for the current card once the cover is downloaded (AsyncImage doesn't load in renderers; fixed light appearance and type size), shared as PNG via `IdeaQuoteImage`. `KeyIdeaText` bolds a short "Lead: …" prefix. "The other side" (`OtherSideSection`) shows critiques, limitations, common pitfalls; folds when > 4 points or > 480 chars; hidden when empty. Chat opens as a sheet. Toolbar bookmark = favorite (needs sign-in; downloads the book for offline).
  - Onboarding (`Features/Onboarding`, first launch only): `WelcomeView` (featured covers and feature icons orbiting the "B" mark on three rings via `TimelineView`, background washed with `CoverTint` colours of the first covers) → "Get Started" raises `OnboardingAuthSheet` (Apple, email sign-up/sign-in, or browse as guest; email confirmation projects get a "check your inbox" state) → `TopicsView` (genres → `OnboardingPreferences.preferredGenres`) → `GoalsView` (reading goals → `readingGoals`) → `LovedBooksView` (grid of the 36 most popular featured books with covers, picked topics first → `likedBookIds`; skipped when offline) → `NotificationsPromptView` (`DailyIdeaReminder` schedules a repeating 8 AM local notification). `OnboardingPreferences.migrateExistingInstall()` marks onboarding done for installs with a saved session or guest choice. To see onboarding again: delete the app, or launch with `-hasCompletedOnboarding NO`; UI tests pass `-hasCompletedOnboarding YES`.
  - AudioPlayer, Settings (downloaded books, clear cache, version), Authentication (`AuthenticationView`, the older sign-in sheet still used from Library/BookDetail).
- Editorial tab roots (Discover, Library) hide the navigation bar with `.editorialNavigationBar()` and use `EditorialHeader(title:caption:trailing:)` (`Shared/Components`); keep the header visible in loading/error states too (UI test relies on it). Pass `caption:`/`trailing:` with labels: an unlabeled trailing closure binds to `trailing`.
- App icon (`AppIcon.appiconset`: light, dark, tinted PNGs): a cream serif "B" (New York) with a bite out of its top-right corner, on oxblood bookcloth (`TypographicCover`'s oxblood). SVG sources in `design/` (render with `qlmanage -t -s 1024 -o . design/app-icon.svg`; the dark PNG is the tinted one's luminance as alpha on cream).
- Design rule: keep the UI monochrome and quiet. No badges, ratings, or decorative color on book lists; color comes from book covers only. `Shared/Design/DesignSystem.swift` still holds old tokens used by Request/Auth/Audio views.

## Widget (`BookBiteWidget/DailyIdeaWidget.swift`)

Self-contained (shares no app source files): its own lightweight `WidgetDailyIdea` decoder. The timeline provider fetches `/summaries/daily-idea?date=<local yyyy-MM-dd>` from the server URL the app stored in the app group (default production), falls back to the app's cached idea, downloads the cover, and refreshes at local midnight. Tapping opens `bookbite://book/<id>?…&cover=`. Both targets have the `group.tilo.BookBite` app group entitlement (`BookBite/BookBite.entitlements` now also wired via `CODE_SIGN_ENTITLEMENTS`). The project uses file-system-synchronized groups, so new files in `BookBiteWidget/` join the target automatically (`Info.plist` is excluded).

## Roadmap

`TODO.md` lists the remaining design ideas (Live Activity, Lock Screen widgets, covers, accessibility, citations, regenerating summaries in the chapter format).

## Recommendations

Personal Discover shelves from embeddings. `server/supabase/add-book-embeddings.sql` adds pgvector, the `book_embeddings` table (one `text-embedding-3-small` vector per book, separate from `books` so `select *` stays small, `content_hash` to skip unchanged books) and the `match_books(taste, exclude_ids, match_count)` RPC (cosine, books with a summary only, service key only). `scripts/embed-books.ts` fills it from title, authors, categories, description, hook, key ideas and "who should read"; re-run it after adding books or summaries.

`POST /api/books/for-you` (`recommendationService.ts`) takes `{likedBookIds, recentBookIds, goals, genres}` (sent by the app from onboarding answers and `RecentBooksStore`; POST keeps them out of URLs). It builds a taste vector: weighted, normalized sum of liked books (1.0), recently opened books (0.7, ×0.85 per position), goals (0.8) and topics (0.4). Goals and topics are embedded from server-side text keyed by id/genre name (clients can't make it embed arbitrary text), cached in memory. It returns `shelves` ("For you", up to 2 "More like <title>" from the newest seeds, up to 2 goal shelves mixing goal + 30% taste; ranked by similarity +0.05 for "known" books (featured, NYT, a popularity rank, or ≥ 100 Open Library readers) because the catalog has many obscure self-published titles that match topics closely; known books excluded, max 2 books per author, one edition per book (main title + author), later shelves avoid the first 12 of earlier ones and their other editions, shelves under 4 books dropped) and `scores` (similarity for the 400 closest books). Empty request → empty response. All ~2,160 books are embedded (2026-10-26; a full run is ~925k tokens, about $0.02). If a run dies on a network error, re-run it: it resumes from the hashes. If the endpoint fails, the app falls back to the default Discover order. Signed-in favorites and reading history aren't used yet.

## Covers

`server/scripts/backfill-covers.ts` picks the sharpest cover per book and writes it to `books.cover_url`: Google Books publisher image (`books/publisher/content/images/frontcover/<id>?fife=w1200-h1800`, the original artwork) → the same for other Google editions with matching title + author surname → Apple Books by ISBN (never by title: "Drive" matched the wrong book) → Open Library → current URL. First candidate ≥500px wide with aspect 1.1–1.8 wins; else the largest ≥320px; else `null` (app shows `TypographicCover`). URLs are stored directly (Google/Apple are resizing CDNs; rehosting ~2k covers would hit the Supabase free-tier 1 GB storage). Replaced URLs are kept in `server/scripts/data/cover-url-backup.json` (oldest URL wins on re-runs). By default it skips books already on Google publisher/Apple URLs, so re-run it after adding books; new books still get 128px `books/content` URLs from the importers. iTunes lookup is rate limited (~20/min), so a full run takes a while. The other-edition step uses the Google Books API key, whose daily query quota a full run can exhaust (that also breaks the server's Google search / book requests until midnight Pacific); the script stops and saves what it checked when that happens. `--ids a,b` re-checks specific books. Check `--report` output visually before writing: other-edition matches are the riskiest.

## Landing page

`server/public/` = `index.html`, `landing.css`, `landing.js`, `books.js`, icons; served by `express.static` (10 min cache) before the API routes. No build step and no libraries. Look: light and playful: Geist with heavy tight headings, one orange accent (`--accent` #ff5b2e) for buttons, selections and chat bubbles, a different pastel per section (peach hero, mint solve, lilac story, butter widget) and an orange rounded CTA panel. No black UI accents. The phone mock-ups keep the app's own paper/ink/serif (Newsreader) tokens so they match the real app. Helmet's CSP allows only same-origin scripts, so no inline `<script>`; `img-src` allows any https host for hotlinked covers; Google Fonts (Newsreader, Hanken Grotesk) pass the default `style-src`/`font-src https:`. Copy follows Headway/Blinkist (outcomes, "15 minutes a day", read or listen, goals) plus the AI angle: applying books to your own problems. Scenes: hero (Discover phone mock with six real covers floating and bobbing around it, nudged by the pointer), "bite" (pinned; a cover gets three bites as you scroll, then its hook reveals word by word), "Bring a problem. Leave with a plan." (pick an example problem: best-match book, three steps taken from that book's real how-to-apply items, and a typed ask-the-book follow-up; hand-written examples in `PROBLEMS`, not live AI), story (pinned phone: key ideas → reader themes → audio → chat), Idea of the Day widget mock tinted by cover hue, two velocity-reactive cover marquees, TestFlight CTA. All scroll scenes run off one rAF loop in `landing.js` reading section progress. `books.js` is a static snapshot (title, author, cover, average `tint`/`hue`) of popular books from `/summaries/highlights`, so the page never depends on Supabase; regenerate it by hand if covers change. The TestFlight link is `TESTFLIGHT_URL` at the top of `landing.js` (placeholder until the public invite exists).

## Server architecture

`src/index.ts` → routes → controllers (HTTP only) → services (business logic, Supabase/API calls). Zod schemas/types in `src/models/types.ts`. All handlers wrap in try/catch and call `next(err)`; `middleware/errorHandler.ts` maps messages to status codes (invalid uuid → 400, "not found" → 404). Stack traces only when `DEBUG_ERRORS=true`.

Routes (prefix `/api`):
- `books`: `/`, `/featured`, `/nyt-bestsellers`, `/search`, `/categories`, `/category/:category`, `/:id`, `/:id/cover`; admin POST/PUT/DELETE.
- `summaries`: `/book/:bookId`, `POST /book/:bookId/generate` (public, rate-limited 20/h/IP), `/job/:jobId`, `/daily-idea?date=YYYY-MM-DD` ("Idea of the day": `{date, book, idea, hook}`, same pick for everyone on a date, from featured books with summaries; logic in `dailyIdeaService.ts`), `/highlights?page=&limit=` (Discover feed: `{items: [{book, hook, idea}], page, hasMore}`, books with a summary by `popularity_score`, limit ≤ 50, cached 30 min; `highlightService.ts`); admin list/update/delete.
- `search`: `/books` (Google Books), `/book/:googleBooksId`, `POST /request` (adds book + generates summaries synchronously; 409 with `{book}` if it exists).
- `books/:bookId/chat/...` (conversations, messages, SSE streaming), `books/:bookId/ratings`, `isbn/:isbn/ratings`.
- `user/*` (favorites, reading-history, recommendations) and `auth/*` (profile, stats, account) require `Authorization: Bearer <supabase jwt>`.
- `audio/book/:bookId`, `audio/job/:jobId` public; `audio/.../generate`, `audio/missing`, `audio/quota` admin-only.

Behaviour worth knowing:
- Non-fiction only: `src/utils/fiction.ts` (`isFiction`) keeps fiction out of the idea of the day, highlights, for-you shelves and `/books/featured`, and the importers skip it. A fiction category without a reliable non-fiction signal counts as fiction; a few mistagged books are hard-coded.
- Extended summaries: `src/services/extendedSummaryPrompt.ts` asks for an intro, 5–8 `## Title` chapters and `## The takeaway`, bans stock phrases, cleans up and validates the output (one retry). The iOS reader splits chapters on `## ` lines; most stored summaries predate this and are plain paragraphs until `regenerate-extended-summaries` runs (writes the newest summary row, backs up old text to `scripts/data/extended-summary-backup.jsonl`, skips ones already in the format).
- Admin = Supabase JWT with `app_metadata.role === 'admin'` (never trust `user_metadata`, users can write it).
- PostgREST returns at most 1000 rows per request; `BookService.fetchAllBooks()` pages through for categories. `?limit` is clamped to 1–1000, `?page` ≥ 1.
- Search fetches all matches' ids/titles, ranks title-exact > title-prefix > title-contains > subtitle > description, then loads the page. Search terms are sanitized for PostgREST `.or()` (commas/parens break it). Google Books results (non-UUID ids) are appended only for `source=all|google` after local results run out.
- Summary generation: `generate` returns `{id, bookId, status}`; if a summary exists it returns `id: "existing-<bookId>", status: "completed"` and the app fetches the summary directly. `/job/:jobId` returns the same camelCase shape. The Bull worker updates the DB job via `job.data.jobId`. `getSummaryByBookId` takes the newest row (regeneration can create duplicates).
- `app.set('trust proxy', 1)` for Render.

## Environment (`server/.env`, see `.env.example`)
`PORT`, `NODE_ENV`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY`, `GOOGLE_BOOKS_API_KEY`, `NYT_API_KEY`, `OPENAI_API_KEY`, `ELEVENLABS_API_KEY`, `REDIS_URL`, `RATE_LIMIT_WINDOW_MS`, `RATE_LIMIT_MAX_REQUESTS`, `CORS_ORIGIN`, optional `DEBUG_ERRORS`.

## Known open issues
- Discover's genre shelves only use the first 100 of ~216 featured books (default `limit=100`); the endless feed below them covers the rest of the catalogue.
- Some covers (Open Library) load slowly via redirects; makeheadway.com covers are hotlinked.
- `BookDetailViewModel` polling `Task` captures `self` strongly (bounded to 5 min).
- `SearchService` bypasses the injected repository.
- The summary's citations are decoded but not shown in the app.
