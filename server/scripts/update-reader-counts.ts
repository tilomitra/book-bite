#!/usr/bin/env npx tsx

/**
 * Set every book's popularity_score to its Open Library reader count.
 *
 * The reader count (readinglog_count) is how many Open Library users marked the book
 * want-to-read, currently-reading or already-read. It is a much stronger popularity signal
 * than ratings, which most books have only a handful of.
 *
 * For each book the script searches Open Library by title and author and picks the matching
 * work with the most readers, which fixes books that were linked to an obscure edition.
 * It stores that work in open_library_id and fills cover_url when the book has none.
 * Books with no match keep their open_library_id (if any) and get that work's count, or 0.
 *
 * Usage:
 *   npx tsx scripts/update-reader-counts.ts [options]
 *
 * Options:
 *   --dry-run          Print changes without writing to the database
 *   --limit <n>        Process at most n books
 *   --title <text>     Only process books whose title contains this text
 *   --concurrency <n>  Books processed in parallel (default 3)
 *
 * Free: only calls Open Library.
 */

import { config } from 'dotenv';
import chalk from 'chalk';

config();

interface OpenLibraryWork {
  key: string;
  title: string;
  author_name?: string[];
  cover_i?: number;
  readinglog_count?: number;
}

interface BookRow {
  id: string;
  title: string;
  authors: string[] | null;
  open_library_id: string | null;
  cover_url: string | null;
  popularity_score: number | null;
}

const OPEN_LIBRARY = 'https://openlibrary.org';
const FIELDS = 'key,title,author_name,cover_i,readinglog_count';

async function getJson(url: string, params: Record<string, string | number> = {}): Promise<any> {
  const query = new URLSearchParams(Object.entries(params).map(([k, v]) => [k, String(v)])).toString();
  const response = await fetch(query ? `${url}?${query}` : url, {
    headers: { 'User-Agent': 'BookBite/1.0 (reader count script)' },
    signal: AbortSignal.timeout(30000)
  });
  if (!response.ok) throw new Error(`GET ${url} failed with status ${response.status}`);
  return response.json();
}

async function withRetry<T>(fn: () => Promise<T>, attempts = 3): Promise<T> {
  for (let i = 1; ; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i >= attempts) throw error;
      await new Promise(resolve => setTimeout(resolve, 2000 * i));
    }
  }
}

// Like add-curated-books.ts, but hyphens become spaces so "Purpose-Driven" matches "Purpose Driven".
function normalizeTitle(title: string): string {
  return title
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .split(/[:(]|\. /)[0]
    .replace(/&/g, 'and')
    .replace(/[-\u2010-\u2015]/g, ' ')
    .replace(/[^a-z0-9 ]/g, '')
    .replace(/^the /, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function lastName(author: string): string {
  const parts = author.replace(/\./g, ' ').trim().split(/\s+/);
  const last = parts[parts.length - 1];
  return /^(jr|sr|ii|iii)$/i.test(last) && parts.length > 1 ? parts[parts.length - 2] : last;
}

function normalizeName(name: string): string {
  return name.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
}

function authorMatches(names: string[] = [], author: string): boolean {
  const wanted = normalizeName(lastName(author));
  return names.some(name => normalizeName(name).includes(wanted));
}

// Open Library titles often run on past ours without a colon ("Eat That Frog! 21 Great Ways...",
// "The Myth of Sisyphus and Other Essays"), so a title that starts with ours, at a word break, matches too.
function titleMatches(candidate: string, wanted: string): boolean {
  const title = normalizeTitle(candidate);
  return title === wanted || title.startsWith(`${wanted} `);
}

// The matching work with the most readers, from a strict title/author search and a free-text one.
// Most readers also picks the main work over spin-offs that share the title ("... for Students").
async function findMainWork(title: string, author: string): Promise<OpenLibraryWork | null> {
  const wantedTitle = normalizeTitle(title);
  const searches = [{ title, author }, { q: `${title.split(':')[0]} ${lastName(author)}` }];
  const matches: OpenLibraryWork[] = [];
  for (const params of searches) {
    const data = await withRetry(() => getJson(`${OPEN_LIBRARY}/search.json`, { ...params, limit: 20, fields: FIELDS }));
    matches.push(
      ...((data.docs || []) as OpenLibraryWork[]).filter(
        d => titleMatches(d.title, wantedTitle) && authorMatches(d.author_name, author)
      )
    );
  }
  matches.sort((a, b) => (b.readinglog_count || 0) - (a.readinglog_count || 0));
  return matches[0] || null;
}

async function findWork(openLibraryId: string): Promise<OpenLibraryWork | null> {
  const data = await withRetry(() =>
    getJson(`${OPEN_LIBRARY}/search.json`, { q: `key:"/works/${openLibraryId}"`, fields: FIELDS })
  );
  return data.docs?.[0] || null;
}

async function loadBooks(supabase: any): Promise<BookRow[]> {
  const books: BookRow[] = [];
  const pageSize = 1000;
  for (let from = 0; ; from += pageSize) {
    const { data, error } = await supabase
      .from('books')
      .select('id, title, authors, open_library_id, cover_url, popularity_score')
      .order('id')
      .range(from, from + pageSize - 1);
    if (error) throw new Error(`Failed to load books: ${error.message}`);
    books.push(...(data || []));
    if (!data || data.length < pageSize) break;
  }
  return books;
}

async function main() {
  const args = process.argv.slice(2);
  const value = (flag: string) => {
    const i = args.indexOf(flag);
    return i >= 0 ? args[i + 1] : undefined;
  };
  const dryRun = args.includes('--dry-run');
  const limit = value('--limit') ? parseInt(value('--limit')!, 10) : undefined;
  const titleFilter = value('--title')?.toLowerCase();
  const concurrency = Math.max(1, parseInt(value('--concurrency') || '3', 10));

  const { supabase } = await import('../src/config/supabase');
  let books = await loadBooks(supabase);
  if (titleFilter) books = books.filter(b => b.title.toLowerCase().includes(titleFilter));
  if (limit) books = books.slice(0, limit);
  console.log(chalk.blue(`📚 ${books.length} books${dryRun ? ' (dry run)' : ''}`));

  const stats = { updated: 0, rematched: 0, coversAdded: 0, noMatch: 0, failed: 0 };
  let next = 0;

  async function processBook(book: BookRow) {
    const author = book.authors?.[0] || '';
    let work = author ? await findMainWork(book.title, author) : null;
    if (!work) {
      stats.noMatch++;
      if (book.open_library_id) work = await findWork(book.open_library_id);
    }

    const workId = work?.key.replace('/works/', '') || book.open_library_id;
    const readers = work?.readinglog_count || 0;
    const update: Record<string, any> = { popularity_score: readers };
    if (workId !== book.open_library_id) {
      update.open_library_id = workId;
      stats.rematched++;
      console.log(chalk.yellow(`  🔁 ${book.title}: ${book.open_library_id ?? 'none'} → ${workId} (${readers} readers)`));
    }
    if (!book.cover_url && work?.cover_i) {
      update.cover_url = `https://covers.openlibrary.org/b/id/${work.cover_i}-L.jpg`;
      stats.coversAdded++;
    }

    if (!dryRun) {
      const { error } = await supabase.from('books').update(update).eq('id', book.id);
      if (error) throw new Error(error.message);
    }
    stats.updated++;
  }

  async function worker() {
    while (next < books.length) {
      const book = books[next++];
      try {
        await processBook(book);
      } catch (error) {
        stats.failed++;
        console.log(chalk.red(`  ❌ ${book.title}: ${(error as Error).message}`));
      }
      if ((stats.updated + stats.failed) % 100 === 0) {
        console.log(chalk.gray(`  … ${stats.updated + stats.failed}/${books.length}`));
      }
    }
  }

  await Promise.all(Array.from({ length: concurrency }, worker));

  console.log(chalk.blue('\n📊 Results'));
  console.log(`   Updated: ${stats.updated}`);
  console.log(`   Re-matched to another work: ${stats.rematched}`);
  console.log(`   Covers added: ${stats.coversAdded}`);
  console.log(`   No title/author match: ${stats.noMatch}`);
  console.log(`   Failed: ${stats.failed}`);
}

main().catch(error => {
  console.error(chalk.red(error.message));
  process.exit(1);
});
