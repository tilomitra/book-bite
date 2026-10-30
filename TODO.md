# TODO: design roadmap

Ideas for taking the app to Apple Design Award level. Done so far: Editorial Discover tab, cover-to-book zoom transition, Library tab, idea-of-the-day widget.

## Signature interaction
- [x] Key ideas as a swipeable card stack with page-turn haptics (instead of a long scroll on the book page).
- [x] A small "finished" moment: finishing a summary adds the book's spine to your shelf in Library.

## Personal
- [x] "Continue reading" row at the top of Discover (needs reading progress tracking).
- [ ] Short onboarding to pick interests; order Discover shelves by them; "Because you read X" shelves.

## Platform integration
- [ ] Live Activity + Dynamic Island while an audio summary plays.
- [ ] CarPlay and Apple Watch audio playback.
- [x] App Intents / Siri / Shortcuts ("Read today's idea"), Spotlight indexing of books and ideas.
- [ ] Liquid Glass on the mini audio player and reader controls.
- [ ] Lock Screen / StandBy widget families (the first widget ships Home Screen sizes).
- [x] Register the `bookbite://` URL scheme (or Universal Links) so shared book links open the app; today only the widget's tap can.
- [x] Deep links carry only title/author/cover; fetch the full book by id on open.

## Visual craft
- [ ] Consistent covers: crops, and covers that are missing or wrong. (Page curls and low-res Google Books thumbnails are fixed client-side in `URL.bookCover(from:)`.)
- [x] Reader typography: hyphenation, measure, layouts that reflow at the largest Dynamic Type sizes.

## Accessibility
- [ ] VoiceOver custom rotor to jump between key ideas.
- [ ] Audit Reduce Motion everywhere; localization.

## Content
- [x] Chapters for featured books (210 of 211 regenerated 2026-10-26, $0.33).
- [ ] Chapters for the rest of the non-fiction catalogue (~1,500 books, ~$2.30, ~1 hour): `npm run regenerate-extended-summaries -- --by-popularity` (resumable; skips books already done; dry-run first).
- [ ] Replace covers hotlinked from Headway (no rights): `cd server && npm run backfill-covers -- --unlicensed --dry-run --report /tmp/covers.json`, check the report, then run it again without `--dry-run`. Books with no other cover get the typographic one.
- [ ] Unfeature or delete the placeholder book "Unti9780063422506" (`544bc854-8962-43fe-b02e-cc7aa5833362`), an NYT import with no real title; its regeneration fails.
- [ ] Reader hyphenation sometimes breaks at the wrong place ("Gett-ing").
- [ ] Citations are decoded but not shown.

## Trust
- [x] Show the summary's analysis (critiques, limitations, pitfalls) and citations; they are decoded but not displayed.

## Catalogue (needs you at your desk)
- [ ] Build the app in Xcode and run the unit tests (the "Newly added" shelves and `NewBooksTests` were written without a compiler).
- [ ] Deploy the server (merge to `main`) so `GET /api/books/new` exists; until then the "Newly added" shelves stay hidden.
- [ ] Clean up the catalogue: read `server/scripts/data/catalog-removals.md` (754 books), delete entries from `catalog-removals.json` for books to keep, then `cd server && npm run clean-catalog -- --apply scripts/data/catalog-removals.json`. Keep `scripts/data/removed-books-backup.jsonl` (git-ignored) to restore by hand.
- [ ] Add the 233 new curated books: `npm run add-curated-books -- --dry-run`, then `npm run add-curated-books` (~$0.70). Or let the weekly job add them over a few months.
- [ ] After both: `npm run embed-books` and `npm run embed-ideas` (a few cents), and `npm run backfill-covers` for the new books.
- [ ] Add GitHub repository secrets for the weekly job (Settings → Secrets and variables → Actions): `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `OPENAI_API_KEY`, `NYT_API_KEY`, `GOOGLE_BOOKS_API_KEY`.
- [ ] First weekly run by hand: Actions → Weekly books → Run workflow with "dry run" on; check the report, then run it without.

## Ask (needs you at your desk)
- [ ] Apply `server/supabase/add-idea-embeddings.sql` in the Supabase SQL editor (project `yjejgiltdbuombrzdtbv`). Creates `idea_embeddings` and the `match_ideas` RPC; until then Ask falls back to whole-book matching and cites weaker books.
- [ ] Backfill it: `cd server && npm run embed-ideas -- --dry-run`, then `npm run embed-ideas` (a couple of cents). Re-run after generating summaries.
- [ ] Restart the local server on 3001 so it has the `/api/ask` routes.
- [ ] Later: "Did it work?" check-ins for the "This week" action (designed in the Ask the Shelf canvas, not built).

