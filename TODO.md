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
- [ ] Run `npm run regenerate-extended-summaries` so existing summaries get chapters (about $3 for all; dry-run first).
- [ ] Citations are decoded but not shown.

## Trust
- [x] Show the summary's analysis (critiques, limitations, pitfalls) and citations; they are decoded but not displayed.
