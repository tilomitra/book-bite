#!/usr/bin/env npx tsx

/**
 * Finds books that don't belong in the catalogue (fiction, textbooks, workbooks, obscure
 * self-published titles) and removes them in a second, reviewed step.
 *
 * Step 1 (read-only): rates every book with the same model and rubric as weekly-books.ts and writes
 * the removal list to a JSON file plus a Markdown report. Review the report, delete lines from the
 * JSON for books you want to keep.
 *   npx tsx scripts/clean-catalog.ts --out scripts/data/catalog-removals.json --report /tmp/clean.md
 *
 * Step 2: deletes the books in that file. Each book row and its summaries are first appended to
 * scripts/data/removed-books-backup.jsonl. Deleting a book also deletes its summaries, embeddings and
 * audio (ON DELETE CASCADE).
 *   npx tsx scripts/clean-catalog.ts --apply scripts/data/catalog-removals.json
 *
 * A book is removed when:
 *   - it is fiction (isFiction), or
 *   - the model rates it 1–2, or 3 with fewer than 50 Open Library readers.
 * Known books (featured, NYT, or 100+ readers) are removed only for fiction or a rating of 1.
 * Books someone saved or has in their reading history are never removed (listed as kept).
 * Books the model did not rate (a failed batch) are kept.
 *
 * Options:
 *   --out <file>       Removal list to write (step 1; default scripts/data/catalog-removals.json)
 *   --report <file>    Markdown report (step 1)
 *   --limit <n>        Rate only the first n books (to try it out)
 *   --catalog <file>   Read books from a JSON array (e.g. GET /api/books pages) instead of Supabase;
 *                      no in-use check. For a preview without the service key.
 *   --apply <file>     Step 2: delete the books listed in this file
 *
 * Cost: rating ~2,200 books is about 75 model calls, well under $1.
 */

import { config } from 'dotenv';
import fs from 'fs';
import path from 'path';
import chalk from 'chalk';
import { isFiction } from '../src/utils/fiction';
import { JUNK_TITLE, rateBooks } from './lib/bookVetting';

config();

const KNOWN_READERS = 100;
const OBSCURE_READERS = 50;
const PAGE_SIZE = 1000;
const BACKUP_PATH = path.join(__dirname, 'data', 'removed-books-backup.jsonl');

interface BookRow {
  id: string;
  title: string;
  authors: string[] | null;
  categories: string[] | null;
  published_year?: number | null;
  popularity_score?: number | null;
  is_featured?: boolean | null;
  is_nyt_bestseller?: boolean | null;
}

interface Removal {
  id: string;
  title: string;
  author: string;
  reason: string;
}

function argValue(flag: string): string | undefined {
  const args = process.argv.slice(2);
  const i = args.indexOf(flag);
  return i >= 0 ? args[i + 1] : undefined;
}

async function supabaseClient(): Promise<any> {
  return (await import('../src/config/supabase')).supabase;
}

async function fetchAll<T>(supabase: any, table: string, select: string): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0; ; from += PAGE_SIZE) {
    const { data, error } = await supabase.from(table).select(select).order('id').range(from, from + PAGE_SIZE - 1);
    if (error) throw new Error(`Failed to load ${table}: ${error.message}`);
    rows.push(...(data || []));
    if (!data || data.length < PAGE_SIZE) break;
  }
  return rows;
}

function isKnown(book: BookRow): boolean {
  return Boolean(book.is_featured || book.is_nyt_bestseller || (book.popularity_score || 0) >= KNOWN_READERS);
}

function firstAuthor(book: BookRow): string {
  return book.authors?.[0] || 'Unknown';
}

async function findRemovals() {
  const catalogPath = argValue('--catalog');
  const limit = argValue('--limit') ? parseInt(argValue('--limit')!, 10) : Infinity;
  const outPath = argValue('--out') || path.join(__dirname, 'data', 'catalog-removals.json');
  const reportPath = argValue('--report');

  let books: BookRow[];
  const inUse = new Set<string>();
  if (catalogPath) {
    books = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
    console.log(chalk.yellow(`   Reading ${books.length} books from ${catalogPath}; books in use are not protected`));
  } else {
    const supabase = await supabaseClient();
    books = await fetchAll<BookRow>(
      supabase,
      'books',
      'id, title, authors, categories, published_year, popularity_score, is_featured, is_nyt_bestseller'
    );
    for (const table of ['user_favorites', 'user_reading_history']) {
      const rows = await fetchAll<{ book_id: string }>(supabase, table, 'book_id');
      rows.forEach(r => inUse.add(r.book_id));
    }
    console.log(chalk.gray(`   ${books.length} books, ${inUse.size} saved or read by someone`));
  }
  books = books.slice(0, limit);
  if (!process.env.OPENAI_API_KEY) throw new Error('OPENAI_API_KEY is required');

  const fiction = books.filter(b => isFiction(b));
  const toRate = books.filter(b => !isFiction(b));
  console.log(chalk.blue(`🧐 Rating ${toRate.length} books (${fiction.length} fiction already)`));
  const ratings = await rateBooks(
    toRate.map(b => ({
      title: b.title,
      author: firstAuthor(b),
      year: b.published_year,
      note: [`${b.popularity_score || 0} readers`, b.is_nyt_bestseller ? 'NYT bestseller' : '', JUNK_TITLE.test(b.title) ? 'title suggests a workbook or companion' : '']
        .filter(Boolean)
        .join(', ')
    })),
    (done, total) => process.stdout.write(chalk.gray(`\r   ${done}/${total}`))
  );
  process.stdout.write('\n');

  const removals: Removal[] = [];
  const kept: Removal[] = [];
  const unrated: BookRow[] = [];
  const consider = (book: BookRow, reason: string) => {
    const entry = { id: book.id, title: book.title, author: firstAuthor(book), reason };
    (inUse.has(book.id) ? kept : removals).push(entry);
  };
  fiction.forEach(b => consider(b, 'fiction'));
  toRate.forEach((book, i) => {
    const rating = ratings[i];
    if (!rating) {
      unrated.push(book);
      return;
    }
    const readers = book.popularity_score || 0;
    const remove = isKnown(book)
      ? rating.score <= 1
      : rating.score <= 2 || (rating.score === 3 && readers < OBSCURE_READERS);
    if (remove) consider(book, `rated ${rating.score}, ${readers} readers: ${rating.reason ?? ''}`);
  });

  fs.writeFileSync(outPath, JSON.stringify(removals, null, 2) + '\n');
  const cell = (s: string) => s.replace(/\|/g, '\\|');
  const report = [
    '## Catalogue cleanup',
    '',
    `${removals.length} of ${books.length} books to remove. ${kept.length} would be removed but are saved or read by someone. ${unrated.length} could not be rated (kept).`,
    '',
    `Removal list: \`${outPath}\`. Delete entries to keep those books, then run \`--apply\`.`,
    '',
    '| Book | Author | Why |',
    '| --- | --- | --- |',
    ...removals.map(r => `| ${cell(r.title)} | ${cell(r.author)} | ${cell(r.reason)} |`),
    ...(kept.length ? ['', '### Kept: in use', '', ...kept.map(r => `- ${r.title} — ${r.author}: ${r.reason}`)] : []),
    ''
  ].join('\n');
  if (reportPath) fs.writeFileSync(reportPath, report);

  console.log(chalk.blue('\n📊 Results'));
  console.log(`   To remove: ${removals.length} of ${books.length}`);
  console.log(`   Kept (in use): ${kept.length}`);
  console.log(`   Not rated (kept): ${unrated.length}`);
  console.log(chalk.gray(`   Removal list: ${outPath}${reportPath ? `, report: ${reportPath}` : ''}`));
}

async function applyRemovals(file: string) {
  const removals: Removal[] = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!removals.length) {
    console.log('Nothing to remove');
    return;
  }
  const supabase = await supabaseClient();
  console.log(chalk.blue(`🗑  Removing ${removals.length} books (backup: ${BACKUP_PATH})`));

  let removed = 0;
  for (let i = 0; i < removals.length; i += 100) {
    const ids = removals.slice(i, i + 100).map(r => r.id);
    // Re-check: someone may have saved one of these since the list was made
    const used = new Set<string>();
    for (const table of ['user_favorites', 'user_reading_history']) {
      const { data, error } = await supabase.from(table).select('book_id').in('book_id', ids);
      if (error) throw new Error(`Failed to check ${table}: ${error.message}`);
      (data || []).forEach((r: any) => used.add(r.book_id));
    }
    const deletable = ids.filter(id => !used.has(id));
    if (used.size) console.log(chalk.yellow(`   Skipping ${used.size} books that are now in use`));
    if (!deletable.length) continue;

    const { data: rows, error } = await supabase.from('books').select('*, summaries(*)').in('id', deletable);
    if (error) throw new Error(`Backup read failed: ${error.message}`);
    fs.appendFileSync(BACKUP_PATH, (rows || []).map((r: any) => JSON.stringify(r)).join('\n') + '\n');

    const { error: deleteError } = await supabase.from('books').delete().in('id', deletable);
    if (deleteError) throw new Error(`Delete failed: ${deleteError.message}`);
    removed += deletable.length;
    console.log(chalk.green(`   Removed ${removed}/${removals.length}`));
  }
  console.log(chalk.blue(`\n✅ Removed ${removed} books. The server caches lists for up to 30 minutes.`));
}

async function main() {
  const applyFile = argValue('--apply');
  if (applyFile) await applyRemovals(applyFile);
  else await findRemovals();
}

main().catch(error => {
  console.error(chalk.red(`💥 ${error instanceof Error ? error.message : error}`));
  process.exit(1);
});
