#!/usr/bin/env npx tsx

/**
 * Replaces low-res book covers with the best high-res source available.
 *
 * For each book, candidates are tried in order and the first one that is at least
 * MIN_WIDTH px wide with a book-like aspect ratio wins:
 *   1. Google Books publisher image (original artwork, up to 1200x1800)
 *   2. The same, for other editions of the book on Google Books (same title and author;
 *      study guides and summaries excluded)
 *   3. Apple Books artwork, looked up by ISBN (never by title: titles match the wrong book)
 *   4. Open Library large cover
 *   5. The current cover_url (never a cover hotlinked from a summary company such as Headway:
 *      we have no rights to their images)
 *
 * If none is that sharp, the largest candidate at least FALLBACK_MIN_WIDTH px wide is kept:
 * a soft but recognisable cover beats a designed one.
 *
 * Google and Apple URLs are stored directly (both are resizing CDNs). Books with no usable
 * candidate get cover_url = null, so the app shows its typographic cover instead of a
 * blurry scan. Every replaced URL is saved to scripts/data/cover-url-backup.json first.
 *
 * Usage:
 *   npx tsx scripts/backfill-covers.ts [--dry-run] [--featured] [--limit <n>] [--force] [--report <file>] [--ids <id,id>]
 *
 *   --dry-run   Report what would change, write nothing
 *   --featured  Only featured books
 *   --limit     Process at most n books
 *   --force     Re-check books whose cover is already from Google publisher / Apple
 *   --report    Write every decision (old URL, new URL, source, rejections) as JSON
 *   --ids       Only these book ids (comma-separated); implies --force
 *   --unlicensed  Only books whose cover is hotlinked from an UNLICENSED_COVER_HOSTS host
 */

import { createClient } from '@supabase/supabase-js';
import { imageSize } from 'image-size';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

dotenv.config();

const MIN_WIDTH = 500;
const FALLBACK_MIN_WIDTH = 320;
const ASPECT_MIN = 1.1; // some covers are nearly square (The Whole30 is 1.13)
const ASPECT_MAX = 1.8;
const CONCURRENCY = 5;
const APPLE_DELAY_MS = 3000; // iTunes lookup allows roughly 20 requests per minute
const BACKUP_FILE = path.join(__dirname, 'data', 'cover-url-backup.json');

interface BookRow {
  id: string;
  title: string;
  isbn10: string | null;
  isbn13: string | null;
  google_books_id: string | null;
  authors: string[] | null;
  cover_url: string | null;
}

interface Candidate {
  source: 'google' | 'google-edition' | 'apple' | 'openlibrary' | 'current';
  url: string;
}

interface Result {
  book: BookRow;
  chosen?: Candidate & { width: number; height: number };
  rejected: string[];
}

const args = process.argv.slice(2);
const options = {
  dryRun: args.includes('--dry-run'),
  featured: args.includes('--featured'),
  force: args.includes('--force'),
  limit: args.includes('--limit') ? parseInt(args[args.indexOf('--limit') + 1], 10) : undefined,
  report: args.includes('--report') ? args[args.indexOf('--report') + 1] : undefined,
  ids: args.includes('--ids') ? args[args.indexOf('--ids') + 1].split(',') : undefined,
  unlicensed: args.includes('--unlicensed'),
};

const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_KEY!, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const googlePublisherUrl = (id: string) =>
  `https://books.google.com/books/publisher/content/images/frontcover/${id}?fife=w1200-h1800&source=gbs_api`;

const isHighResSource = (url: string | null) =>
  !!url && (url.includes('/books/publisher/content/images/frontcover/') || url.includes('mzstatic.com'));

// Covers from other summary apps: never kept, so these books get a real cover or the typographic one.
const UNLICENSED_COVER_HOSTS = ['makeheadway.com', 'storyblok.com'];
const isUnlicensedCover = (url: string | null) => !!url && UNLICENSED_COVER_HOSTS.some(host => url.includes(host));

type Measured = { width: number; height: number };

/** Size of a usable cover image, or why it is not one. Images below MIN_WIDTH come back with `small`. */
async function measure(url: string): Promise<(Measured & { small: boolean }) | string> {
  try {
    const response = await fetch(url, { redirect: 'follow', signal: AbortSignal.timeout(20000) });
    if (!response.ok) return `HTTP ${response.status}`;
    const { width, height } = imageSize(new Uint8Array(await response.arrayBuffer()));
    if (!width || !height) return 'unreadable';
    if (width < FALLBACK_MIN_WIDTH) return `${width}x${height} too small`;
    const aspect = height / width;
    if (aspect < ASPECT_MIN || aspect > ASPECT_MAX) return `${width}x${height} not book-shaped`;
    return { width, height, small: width < MIN_WIDTH };
  } catch (error) {
    return error instanceof Error ? error.message : 'failed';
  }
}

const normalize = (text: string) =>
  text.toLowerCase().split(':')[0].replace(/^the /, '').replace(/[^a-z0-9]+/g, ' ').trim();
const NOT_THE_BOOK = /study guide|summary|cliffs ?notes|analysis|workbook|quicklet|sparknotes|journal/i;

/** Set when the Google Books API refuses requests (daily quota): the run stops instead of writing worse covers. */
let googleQuotaError: string | null = null;

/** Google Books volume ids of other editions: same title (ignoring subtitle), same author surname. */
async function otherGoogleEditions(book: BookRow): Promise<string[]> {
  const surname = book.authors?.[0]?.split(' ').pop()?.toLowerCase();
  if (!surname) return [];
  const query = encodeURIComponent(`${book.title.split(':')[0]} ${book.authors![0]}`);
  try {
    let response: Response;
    let json: any;
    // Google sometimes answers 503 "Service temporarily unavailable"; retry those before giving up
    for (let attempt = 1; ; attempt++) {
      response = await fetch(
        `https://www.googleapis.com/books/v1/volumes?q=${query}&maxResults=20&printType=books&langRestrict=en&key=${process.env.GOOGLE_BOOKS_API_KEY}`
      );
      json = await response.json();
      if (!json.error || response.status < 500 || attempt === 4) break;
      await new Promise(resolve => setTimeout(resolve, 5000 * attempt));
    }
    if (json.error) {
      googleQuotaError = json.error.message ?? `HTTP ${response.status}`;
      throw new Error(googleQuotaError!);
    }
    return (json.items ?? [])
      .filter((volume: any) => {
        const info = volume.volumeInfo ?? {};
        return volume.id !== book.google_books_id
          && info.imageLinks
          && (info.language ?? 'en') === 'en'
          && normalize(info.title ?? '') === normalize(book.title)
          && !NOT_THE_BOOK.test(`${info.title} ${info.subtitle ?? ''}`)
          && (info.authors ?? []).some((author: string) => author.toLowerCase().includes(surname));
      })
      .map((volume: any) => volume.id)
      .slice(0, 5);
  } catch (error) {
    if (googleQuotaError) throw error;
    return [];
  }
}

let lastAppleCall = 0;
async function appleArtwork(isbns: string[]): Promise<string | null> {
  for (const isbn of isbns) {
    const wait = lastAppleCall + APPLE_DELAY_MS - Date.now();
    lastAppleCall = Date.now() + Math.max(0, wait);
    if (wait > 0) await new Promise(resolve => setTimeout(resolve, wait));
    try {
      const response = await fetch(`https://itunes.apple.com/lookup?isbn=${isbn}`);
      const json = await response.json();
      const artwork: string | undefined = json.results?.[0]?.artworkUrl100;
      if (artwork) return artwork.replace(/\/\d+x\d+bb\./, '/1600x1600bb.');
    } catch {
      // Rate limited or not found: try the next ISBN
    }
  }
  return null;
}

async function processBook(book: BookRow): Promise<Result> {
  const result: Result = { book, rejected: [] };
  const isbns = [book.isbn13, book.isbn10].filter((isbn): isbn is string => !!isbn);

  const candidates: Array<() => Promise<Candidate[]>> = [
    async () => (book.google_books_id ? [{ source: 'google', url: googlePublisherUrl(book.google_books_id) }] : []),
    async () => (await otherGoogleEditions(book)).map(id => ({ source: 'google-edition', url: googlePublisherUrl(id) })),
    async () => {
      const url = isbns.length ? await appleArtwork(isbns) : null;
      return url ? [{ source: 'apple', url }] : [];
    },
    async () => (isbns.length ? [{ source: 'openlibrary', url: `https://covers.openlibrary.org/b/isbn/${isbns[0]}-L.jpg?default=false` }] : []),
    async () => (book.cover_url && !isUnlicensedCover(book.cover_url) ? [{ source: 'current', url: book.cover_url }] : []),
  ];

  let fallback: Result['chosen'];
  for (const next of candidates) {
    for (const candidate of await next()) {
      const size = await measure(candidate.url);
      if (typeof size === 'string') {
        result.rejected.push(`${candidate.source}: ${size}`);
      } else if (size.small) {
        result.rejected.push(`${candidate.source}: ${size.width}x${size.height} soft`);
        if (!fallback || size.width > fallback.width) fallback = { ...candidate, width: size.width, height: size.height };
      } else {
        result.chosen = { ...candidate, width: size.width, height: size.height };
        return result;
      }
    }
  }
  result.chosen = fallback;
  return result;
}

async function fetchBooks(): Promise<BookRow[]> {
  const books: BookRow[] = [];
  for (let from = 0; ; from += 1000) {
    let query = supabase
      .from('books')
      .select('id,title,isbn10,isbn13,google_books_id,authors,cover_url')
      .order('created_at')
      .range(from, from + 999);
    if (options.featured) query = query.eq('is_featured', true);
    if (options.ids) query = query.in('id', options.ids);
    const { data, error } = await query;
    if (error) throw new Error(error.message);
    books.push(...(data as BookRow[]));
    if (data.length < 1000) break;
  }
  const todo = options.unlicensed
    ? books.filter(book => isUnlicensedCover(book.cover_url))
    : options.force || options.ids
      ? books
      : books.filter(book => !isHighResSource(book.cover_url));
  return options.limit ? todo.slice(0, options.limit) : todo;
}

function backup(results: Result[]) {
  const existing: Record<string, string> = fs.existsSync(BACKUP_FILE)
    ? JSON.parse(fs.readFileSync(BACKUP_FILE, 'utf8'))
    : {};
  for (const { book } of results) {
    // Keep the oldest known URL: re-runs must not overwrite the original with our own replacement
    if (book.cover_url && !existing[book.id]) existing[book.id] = book.cover_url;
  }
  fs.writeFileSync(BACKUP_FILE, JSON.stringify(existing, null, 2) + '\n');
}

async function main() {
  const books = await fetchBooks();
  console.log(`Checking ${books.length} books${options.dryRun ? ' (dry run)' : ''}`);

  const results: Result[] = [];
  let index = 0;
  await Promise.all(
    Array.from({ length: CONCURRENCY }, async () => {
      while (index < books.length && !googleQuotaError) {
        const book = books[index++];
        let result: Result;
        try {
          result = await processBook(book);
        } catch (error) {
          if (googleQuotaError) break; // leave this book for the next run
          throw error;
        }
        results.push(result);
        const chosen = result.chosen ? `${result.chosen.source} ${result.chosen.width}x${result.chosen.height}` : 'NONE → typographic';
        console.log(`[${results.length}/${books.length}] ${result.book.title.slice(0, 50).padEnd(50)} ${chosen}`);
      }
    })
  );

  if (googleQuotaError) {
    console.warn(`\nStopped early, Google Books API: ${googleQuotaError}`);
    console.warn(`Saving the ${results.length} books checked so far; re-run after the quota resets.`);
  }

  const changed = results.filter(r => (r.chosen?.url ?? null) !== r.book.cover_url);
  const tally: Record<string, number> = {};
  for (const r of results) tally[r.chosen?.source ?? 'none'] = (tally[r.chosen?.source ?? 'none'] || 0) + 1;
  console.log('\nChosen source:', tally);
  console.log(`${changed.length} of ${results.length} cover URLs would change`);

  if (options.report) {
    const report = results.map(r => ({
      id: r.book.id,
      title: r.book.title,
      authors: r.book.authors,
      old: r.book.cover_url,
      new: r.chosen?.url ?? null,
      source: r.chosen?.source ?? null,
      size: r.chosen ? `${r.chosen.width}x${r.chosen.height}` : null,
      rejected: r.rejected,
    }));
    fs.writeFileSync(options.report, JSON.stringify(report, null, 2));
    console.log(`Report written to ${options.report}`);
  }

  if (options.dryRun || changed.length === 0) return;

  backup(changed);
  for (const r of changed) {
    const { error } = await supabase.from('books').update({ cover_url: r.chosen?.url ?? null }).eq('id', r.book.id);
    if (error) console.error(`Failed to update ${r.book.title}: ${error.message}`);
  }
  console.log(`Updated ${changed.length} books. Previous URLs saved to ${path.relative(process.cwd(), BACKUP_FILE)}`);
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});
