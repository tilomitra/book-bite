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
- [x] Chapters for the rest of the non-fiction catalogue (1,519 of 1,522 regenerated 2026-10-30, $2.35). Three failed because they aren't real books: "Statistical Reference Index", "Professional Journal of the United States Army" and the placeholder "Unti9780063422506".
- [x] Replace covers hotlinked from Headway (78 books, 2026-10-30; the 34 no script source found were matched by hand). *Flux* has a square cover: no sharp 2:3 English edition found.
- [x] Unfeature the placeholder book "Unti9780063422506" (`544bc854-8962-43fe-b02e-cc7aa5833362`). Still in the catalogue; delete it if wanted.
- [ ] Reader hyphenation sometimes breaks at the wrong place ("Gett-ing"). Not reproduced: `Hyphenator` gives "Get-ting" on iOS 26.3 (covered by a test) and no stored summary contains it; needs a screenshot of the book and text size.
- [x] Show citations: "Sources" at the end of the book page.

## Trust
- [x] Show the summary's analysis (critiques, limitations, pitfalls) and citations; they are decoded but not displayed.

## Ask (needs you at your desk)
- [ ] Apply `server/supabase/add-idea-embeddings.sql` in the Supabase SQL editor (project `yjejgiltdbuombrzdtbv`). Creates `idea_embeddings` and the `match_ideas` RPC; until then Ask falls back to whole-book matching and cites weaker books.
- [ ] Backfill it: `cd server && npm run embed-ideas -- --dry-run`, then `npm run embed-ideas` (a couple of cents). Re-run after generating summaries.
- [ ] Restart the local server on 3001 so it has the `/api/ask` routes.
- [ ] Later: "Did it work?" check-ins for the "This week" action (designed in the Ask the Shelf canvas, not built).


## Reading pass (5 free books, Give 5 get 5, $9/month Unlimited)
- [ ] Apply `server/supabase/add-reading-pass.sql` in the Supabase SQL editor. Until then `/api/user/reading-pass` fails and signed-in readers fall back to the pass on their device.
- [ ] Create the subscription in App Store Connect: group "Bookgist Unlimited", product `tilo.BookBite.unlimited.monthly`, 1 month, $9.00. Needs the paid developer team (the free team can't sign In-App Purchase).
- [ ] Set `APP_STORE_URL` on Render once the app is live (invite pages link to the TestFlight placeholder until then).
- [ ] Server-side enforcement: `/summaries/book/:id` still returns the full text to everyone. Gate it once older app versions are gone, with App Store Server API checks for subscribers.
- [ ] Universal links for `/invite/<code>` (needs Associated Domains, so the paid team) and a deferred deep link, so a new install gets the code without typing it.
- [ ] Push a notification to the inviter when a friend joins (today Library shows it on the next refresh).

## Analytics (PostHog)
- [ ] Create a PostHog US Cloud project and set `POSTHOG_PROJECT_KEY` for the BookBite target's Release configuration. Until then analytics are off. Confirm the first events arrive (Debug: launch with `SIMCTL_CHILD_POSTHOG_PROJECT_KEY=<key>`).
- [ ] Turn on "Discard client IP data" in the PostHog project settings.
- [ ] Update the App Store Connect privacy answers: Device ID and User ID for analytics.
- [ ] Delete PostHog data on account deletion: call PostHog's API from `DELETE auth/account`, or disclose that it stays in `privacy.html`'s Delete section. Do this before shipping.
- [ ] Deploy `privacy.html` no later than the app release that turns analytics on.
- [ ] Track invite shares (`ShareLink` doesn't report completion; redemptions are tracked).
- [ ] Build the funnels and retention dashboards: onboarding → first book → finished, reading pass → invite or subscribe.
