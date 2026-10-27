<p align="center">
  <img src="BookBite/Assets.xcassets/AppIcon.appiconset/Bookbite_V2-1024x1024@1x.png" width="128" alt="BookBite app icon">
</p>

<h1 align="center">BookBite</h1>

<p align="center">
  <em>The big ideas from great non-fiction, in the time it takes to drink a coffee.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-18.5%2B-black?logo=apple" alt="iOS 18.5+">
  <img src="https://img.shields.io/badge/SwiftUI-MVVM-F05138?logo=swift&logoColor=white" alt="SwiftUI">
  <img src="https://img.shields.io/badge/server-Express%20%2B%20TypeScript-3178C6?logo=typescript&logoColor=white" alt="Express + TypeScript">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey" alt="MIT license">
</p>

---

BookBite is an iOS app for people who want to learn from books but do not have time to read all of them. Each book gets a one-sentence hook, its key ideas, how to apply them, an honest look at its weak points, and a chaptered summary you can read in about ten minutes. You can also listen to it, or ask the book questions.

The design is quiet and editorial, like a good magazine. The only color comes from the book covers.

## What you can do

### Discover
- **Idea of the Day.** One key idea from a well-known book, set as a pull quote. The same idea for everyone, every day.
- **An endless editorial feed.** Shelves by topic, spotlight cards, quick bites and single passages. No book shows twice.
- **Shelves made for you.** "For you", "More like *Atomic Habits*" and shelves for your reading goals. They come from what you picked during onboarding and what you open.

### Read
- **A real reading page.** Each book has a hook, key ideas, how to apply them, who it is for, and "The other side" (critiques and limits).
- **Key ideas as cards.** Swipe through them, keep the ones you like, or share one as an image.
- **A reader built for long text.** Chapters with a contents menu, Paper, Sepia and Night themes, serif or sans type, and text size that follows Dynamic Type.
- **Picks up where you stopped.** BookBite remembers your place and shows "N min left".
- **Audio summaries** with lock-screen controls.
- **Chat with the book.** Ask questions and get streamed answers.

### Keep
- **Library.** Continue reading, recently opened, saved books, finished books ("12 finished this year") and offline downloads.
- **Notebook.** All the ideas you kept, by book or by date.
- **Request any book.** Search Google Books. BookBite writes the summary on demand.

### Everywhere on iPhone
- **Home Screen widget** with the Idea of the Day (small and medium).
- **Siri and Shortcuts:** "Today's idea in BookBite" and "Continue reading".
- **Spotlight** finds books you have opened.
- **Share links** (`bookbite://book/<id>`) open the book in the app.
- **A daily 8 AM reminder**, if you want one.

Sign-in (Apple or email) is optional. You can use almost all of BookBite as a guest.

## How it works

```
┌─────────────────────┐        ┌──────────────────────────┐
│  iOS app (SwiftUI)  │  HTTPS │  Server (Express + TS)   │
│  + Home Screen      │ ─────▶ │  REST API, rate limits   │
│    widget           │        │  Bull queue on Redis     │
└─────────────────────┘        └──────────┬───────────────┘
                                          │
          ┌───────────────────┬───────────┼──────────────┬─────────────────────┐
          ▼                   ▼           ▼              ▼                     ▼
   Supabase (Postgres   OpenAI          ElevenLabs   Google Books, NYT,    Supabase Auth
   + pgvector)          summaries,      audio        Open Library          (Apple, email)
                        chat,
                        embeddings
```

- The app is **remote-only**. All books and summaries come from the server. You can download single books for offline reading.
- About **2,100 non-fiction books**. Fiction is filtered out.
- **Recommendations** use one `text-embedding-3-small` vector per book in pgvector. The server builds a taste vector from your liked books, recent books, goals and topics.
- **Covers** come from the sharpest source available (Google publisher art, Apple Books, Open Library). When no good cover exists, the app draws a typographic cover on bookcloth.

## Project layout

```
BookBite/              iOS app
├── App/               Entry point, tabs, deep links, App Intents, configuration
├── Core/              Models, repositories (API), services (network, auth, audio, stores)
├── Features/          Featured (Discover), Search, MyLibrary, BookDetail + Reader,
│                      Onboarding, Request, AudioPlayer, Settings, Authentication
└── Shared/            Design system, editorial components, utilities
BookBiteWidget/        "Idea of the Day" widget extension
BookBiteTests/         Unit tests (Swift Testing)
server/
├── src/               routes → controllers → services, Zod types, middleware
├── scripts/           Catalogue, summary, audio, cover and embedding scripts
└── supabase/          Schema and SQL files
```

## Getting started

### Requirements
- Xcode 26 with an iOS simulator runtime
- Node 22 and Redis
- A Supabase project and API keys for OpenAI, Google Books, NYT and ElevenLabs (see `server/.env.example`)

### 1. Start the server
```bash
cd server
cp .env.example .env        # then fill in your keys
npm install
npm run dev                 # http://localhost:3000/api
```

### 2. Run the app
```bash
open BookBite.xcodeproj     # then run the BookBite scheme
```

Debug builds use `http://localhost:3000/api`. To use another server, set the `BOOKBITE_SERVER_URL` launch environment variable. Release builds use the production server.

### 3. Set up the database
Apply `server/supabase/schema.sql` and the other SQL files in `server/supabase/` in the Supabase SQL editor. `add-book-embeddings.sql` turns on recommendations.

## Commands

| Task | Command |
| --- | --- |
| Build the app | `xcodebuild -project BookBite.xcodeproj -scheme BookBite -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` |
| App unit tests | `xcodebuild test … -only-testing:BookBiteTests` |
| Server dev mode | `cd server && npm run dev` |
| Type-check | `cd server && npx tsc --noEmit` |
| Server tests | `cd server && npm test` |
| Lint | `cd server && npm run lint` |

### Catalogue scripts
These scripts call paid APIs. Most take `--dry-run`, so use it first.

| Script | What it does |
| --- | --- |
| `npm run add-curated-books` | Adds books from a hand-picked list, with summaries |
| `npm run populate-books` | Imports books from Google Books and NYT |
| `npm run generate-summaries` | Writes summaries for books that have none |
| `npm run regenerate-extended-summaries` | Rewrites extended summaries into chapters |
| `npm run generate-audio -- --title "Atomic Habits"` | Makes an audio summary |
| `npm run backfill-covers` | Finds sharper covers |
| `npm run embed-books` | Updates the recommendation embeddings |
| `npm run update-reader-counts` | Sets popularity from Open Library reader counts |

## Deployment

The server deploys to [Render](https://render.com) from `main` (`server/`, `yarn build` / `yarn start`), with Redis as a Render Key Value store.

## Roadmap

See [`TODO.md`](TODO.md). Next up: a Live Activity for audio, Lock Screen widgets, chapters for the full catalogue, citations in the app, and more accessibility work.

## Contributing

Contributors and coding agents: read [`CLAUDE.md`](CLAUDE.md) first. It has the architecture, conventions and known issues in detail.

## License

MIT. See [LICENSE.md](LICENSE.md).
