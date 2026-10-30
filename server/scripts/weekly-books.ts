#!/usr/bin/env npx tsx

/**
 * Weekly book pipeline: finds well-regarded non-fiction books the catalogue lacks, adds the best
 * ones with summaries, then embeds them and checks their covers. Runs every week from
 * .github/workflows/weekly-books.yml; safe to run by hand.
 *
 * 1. Candidates, in this order:
 *    - NYT non-fiction bestseller lists (needs NYT_API_KEY): what people read this week
 *    - scripts/data/curated-books.json: hand-picked books not yet in the database
 *    - Open Library: recent books (published in the last 2 years) with the most readers
 *    - Open Library: the most-read books per genre, and the monthly trending list
 * 2. Filters: not in the database (title + author surname), not fiction, English, has a cover,
 *    no workbooks/summaries/journals, enough Open Library readers (NYT and curated books skip this).
 * 3. Vetting: the model rates the candidates that are left (curated books skip this) and picks a
 *    genre. Only books rated 4 or 5 ("a book people recommend for its ideas") stay.
 * 4. Adds up to --limit books (max 2 per author): first up to --discover new finds, then curated
 *    books, then more finds. Generates the summary and extended summary for each.
 * 5. Runs embed-books, embed-ideas and backfill-covers --ids for the new books.
 *
 * Usage:
 *   npx tsx scripts/weekly-books.ts [options]
 *
 * Options:
 *   --dry-run           Find, filter and vet candidates, print the picks. No DB writes, no summaries.
 *   --limit <n>         Books to add (default 20)
 *   --discover <n>      Of those, slots kept for NYT and Open Library finds before the curated
 *                       list fills the rest (default 8)
 *   --min-readers <n>   Open Library readers needed for older books (default 300; recent books need 25)
 *   --feature           Mark added books as featured (they then appear on Discover's genre shelves)
 *   --no-vet            Skip the model vetting (not recommended: Open Library lists are noisy)
 *   --skip-post         Do not run the embedding and cover scripts afterwards
 *   --report <file>     Write a Markdown report (also appended to $GITHUB_STEP_SUMMARY when set)
 *
 * Cost: about $0.003 per added book plus well under $0.01 for vetting. 20 books ≈ $0.07.
 */

import { config } from 'dotenv';
import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';
import chalk from 'chalk';
import OpenAI from 'openai';
import { isFiction } from '../src/utils/fiction';
import {
  CuratedBook,
  OPEN_LIBRARY,
  OPEN_LIBRARY_FIELDS,
  OpenLibraryDoc,
  bookKey,
  buildBookRow,
  findOnOpenLibrary,
  generateSummaries,
  getJson,
  lastName,
  loadExistingKeys,
  withRetry
} from './lib/bookImport';

config();

const VET_MODEL = 'gpt-6-luna';
const NYT_LISTS = [
  'combined-print-and-e-book-nonfiction',
  'hardcover-nonfiction',
  'paperback-nonfiction',
  'advice-how-to-and-miscellaneous',
  'business-books'
];
// Open Library subject → app genre. The genre is only a hint for the vetting model.
const OPEN_LIBRARY_SUBJECTS: Record<string, string> = {
  psychology: 'Psychology',
  'self-help': 'Self-Help',
  business: 'Business',
  economics: 'Economics',
  history: 'History',
  science: 'Science',
  biography: 'Biography',
  health: 'Health',
  philosophy: 'Philosophy',
  technology: 'Technology',
  leadership: 'Leadership',
  personal_finance: 'Finance',
  parenting: 'Parenting',
  time_management: 'Productivity',
  social_science: 'Society',
  spirituality: 'Spirituality',
  meditation: 'Mindfulness',
  marketing: 'Marketing',
  interpersonal_relations: 'Relationships',
  authorship: 'Writing'
};
// Genres the app already uses (categories in curated-books.json), so new books join existing shelves.
const GENRES = [
  'Psychology', 'Self-Help', 'Business', 'Economics', 'Finance', 'History', 'Science', 'Technology',
  'Biography', 'Health', 'Philosophy', 'Society', 'Parenting', 'Relationships', 'Productivity',
  'Leadership', 'Career', 'Marketing', 'Writing', 'Spirituality', 'Mindfulness', 'Travel'
];
const RECENT_MIN_READERS = 25;
const MAX_PER_AUTHOR = 2;
// Not books to summarize: companions to other books, journals, textbooks, bundles.
const JUNK_TITLE =
  /\b(workbook|summary|study guide|analysis of|journal|planner|notebook|colou?ring|box(ed)? set|collection|textbook|for dummies|cookbook|recipes|calendar|activity book|edition|volume|vol\.|book \d|part \d)\b/i;

type Source = 'nyt' | 'curated' | 'recent' | 'popular';
const SOURCE_ORDER: Source[] = ['nyt', 'curated', 'recent', 'popular'];

interface Candidate {
  title: string;
  author: string;
  category: string;
  source: Source;
  doc?: OpenLibraryDoc | null;
  readers: number;
  year?: number;
  nyt?: { list: string; rank: number; weeks: number; date: string };
  score?: number;
  reason?: string;
}

interface Options {
  dryRun: boolean;
  limit: number;
  discover: number;
  minReaders: number;
  feature: boolean;
  vet: boolean;
  post: boolean;
  report?: string;
}

function parseArgs(): Options {
  const args = process.argv.slice(2);
  const value = (flag: string) => {
    const i = args.indexOf(flag);
    return i >= 0 ? args[i + 1] : undefined;
  };
  return {
    dryRun: args.includes('--dry-run'),
    limit: Math.max(1, parseInt(value('--limit') || '20', 10)),
    discover: Math.max(0, parseInt(value('--discover') || '8', 10)),
    minReaders: Math.max(0, parseInt(value('--min-readers') || '300', 10)),
    feature: args.includes('--feature'),
    vet: !args.includes('--no-vet'),
    post: !args.includes('--skip-post'),
    report: value('--report')
  };
}

// NYT titles are upper case; this is only used when Open Library has no match.
function titleCase(title: string): string {
  return title.toLowerCase().replace(/(^|[\s:(-])(\w)/g, (_, sep, c) => sep + c.toUpperCase());
}

// "Bill O'Reilly and Martin Dugard" → "Bill O'Reilly"
function firstAuthor(author: string): string {
  return author.split(/\s+(?:and|with|&)\s+|,\s*/)[0].trim();
}

async function nytCandidates(): Promise<Candidate[]> {
  if (!process.env.NYT_API_KEY) {
    console.log(chalk.yellow('   NYT_API_KEY not set, skipping NYT lists'));
    return [];
  }
  const out: Candidate[] = [];
  for (const list of NYT_LISTS) {
    try {
      const data = await withRetry(() =>
        getJson(`https://api.nytimes.com/svc/books/v3/lists/current/${list}.json`, { 'api-key': process.env.NYT_API_KEY! })
      );
      for (const b of data.results?.books || []) {
        if (!b.title || !b.author) continue;
        out.push({
          title: titleCase(b.title),
          author: firstAuthor(b.author),
          category: '',
          source: 'nyt',
          readers: 0,
          nyt: { list, rank: b.rank, weeks: b.weeks_on_list || 0, date: data.results.published_date }
        });
      }
    } catch (error) {
      console.log(chalk.yellow(`   NYT ${list}: ${error instanceof Error ? error.message : error}`));
    }
    // The NYT API allows 5 requests a minute
    await new Promise(resolve => setTimeout(resolve, 12500));
  }
  return out.sort((a, b) => a.nyt!.rank - b.nyt!.rank);
}

function curatedCandidates(): Candidate[] {
  const list: CuratedBook[] = JSON.parse(fs.readFileSync(path.join(__dirname, 'data', 'curated-books.json'), 'utf8'));
  return list.map(b => ({ ...b, source: 'curated' as const, readers: 0 }));
}

async function openLibrarySearch(q: string, limit: number, category: string, source: Source): Promise<Candidate[]> {
  try {
    const data = await withRetry(() =>
      getJson(`${OPEN_LIBRARY}/search.json`, { q, sort: 'readinglog', limit, fields: OPEN_LIBRARY_FIELDS })
    );
    return ((data.docs || []) as OpenLibraryDoc[])
      .filter(d => d.author_name?.length)
      .map(d => ({
        title: d.title,
        author: d.author_name![0],
        category,
        source,
        doc: d,
        readers: d.readinglog_count || 0,
        year: d.first_publish_year
      }));
  } catch (error) {
    console.log(chalk.yellow(`   Open Library "${q}": ${error instanceof Error ? error.message : error}`));
    return [];
  }
}

async function openLibraryCandidates(): Promise<Candidate[]> {
  const year = new Date().getFullYear();
  const out = await openLibrarySearch(`first_publish_year:[${year - 1} TO ${year}] subject_key:nonfiction language:eng`, 100, '', 'recent');
  for (const [subject, genre] of Object.entries(OPEN_LIBRARY_SUBJECTS)) {
    out.push(...(await openLibrarySearch(`subject_key:${subject} language:eng`, 200, genre, 'popular')));
    out.push(
      ...(await openLibrarySearch(`subject_key:${subject} first_publish_year:[${year - 1} TO ${year}] language:eng`, 30, genre, 'recent'))
    );
  }
  try {
    const trending = await getJson(`${OPEN_LIBRARY}/trending/monthly.json`, { limit: 200 });
    for (const w of trending.works || []) {
      if (w.author_name?.length) out.push({ title: w.title, author: w.author_name[0], category: '', source: 'popular', readers: 0 });
    }
  } catch (error) {
    console.log(chalk.yellow(`   Open Library trending: ${error instanceof Error ? error.message : error}`));
  }
  return out;
}

/** Why a candidate fails the cheap checks, or null when it passes. */
function rejectReason(c: Candidate, options: Options): string | null {
  // Curated books are hand-picked ("The Bullet Journal Method" is not a journal)
  if (c.source === 'curated') return null;
  if (JUNK_TITLE.test(c.title)) return 'title looks like a workbook, summary or bundle';
  const doc = c.doc;
  if (!doc) return c.source === 'nyt' ? null : 'not on Open Library';
  if (!doc.cover_i && c.source !== 'nyt') return 'no cover';
  if (doc.language?.length && !doc.language.includes('eng')) return 'not in English';
  if (isFiction({ title: c.title, authors: [c.author], categories: doc.subject?.slice(0, 80) })) return 'fiction';
  if (c.source === 'nyt') return null;
  const recent = (doc.first_publish_year || 0) >= new Date().getFullYear() - 1;
  const needed = recent ? RECENT_MIN_READERS : options.minReaders;
  if ((doc.readinglog_count || 0) < needed) return `only ${doc.readinglog_count || 0} readers`;
  return null;
}

/** Asks the model to rate each candidate 1–5 and pick its genre. */
async function vet(candidates: Candidate[]): Promise<void> {
  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  for (let i = 0; i < candidates.length; i += 30) {
    const batch = candidates.slice(i, i + 30);
    const list = batch
      .map((c, n) => `${n + 1}. "${c.title}" by ${c.author}${c.year ? ` (${c.year})` : ''}${c.nyt ? ' [NYT bestseller]' : ''}`)
      .join('\n');
    const prompt = `BookBite is an app with summaries of non-fiction books: key ideas, how to apply them, and answers to readers' problems drawn from ideas across the catalogue. Rate each book below for the catalogue.

5 = a widely recommended non-fiction book with clear ideas readers can learn from or apply (e.g. Thinking, Fast and Slow; Educated; The Psychology of Money)
4 = a well-reviewed non-fiction book from a known author or publisher, worth a summary
3 = real but minor, niche or dated
2 = not a good fit: textbook, reference work, anthology, poetry, a companion to another book, a primary religious text, a political tract or a celebrity book without ideas
1 = fiction, a children's book, a summary/workbook of another book, self-published filler, or unknown to you

Rules: rate 1 if you are not sure the book exists as described. Pick the genre from: ${GENRES.join(', ')}.

Books:
${list}

Reply with JSON: {"books": [{"n": 1, "score": 5, "genre": "Psychology", "reason": "max 12 words"}]}, one entry per book.`;
    try {
      const response = await withRetry(() =>
        openai.chat.completions.create({
          model: VET_MODEL,
          max_completion_tokens: 8000,
          response_format: { type: 'json_object' },
          messages: [{ role: 'user', content: prompt }]
        })
      );
      const parsed = JSON.parse(response.choices[0].message.content || '{}');
      for (const r of parsed.books || []) {
        const c = batch[Number(r.n) - 1];
        if (!c) continue;
        c.score = Number(r.score) || 0;
        c.reason = typeof r.reason === 'string' ? r.reason : undefined;
        if (GENRES.includes(r.genre)) c.category = r.genre;
      }
    } catch (error) {
      console.log(chalk.yellow(`   Vetting batch failed: ${error instanceof Error ? error.message : error}`));
    }
  }
}

function runScript(args: string[]): boolean {
  console.log(chalk.blue(`\n▶ npx tsx ${args.join(' ')}`));
  const result = spawnSync('npx', ['tsx', ...args], { cwd: path.join(__dirname, '..'), stdio: 'inherit' });
  if (result.status !== 0) console.log(chalk.yellow(`   ${args[0]} exited with ${result.status}`));
  return result.status === 0;
}

function escapeCell(text: string): string {
  return text.replace(/\|/g, '\\|');
}

async function main() {
  const options = parseArgs();
  console.log(chalk.blue(`📚 Weekly books${options.dryRun ? ' (dry run)' : ''}: up to ${options.limit}`));

  // Reading the catalogue is safe in a dry run too; without Supabase keys nothing is deduplicated.
  let supabase: any = null;
  let existing = new Set<string>();
  if (process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_KEY) {
    supabase = (await import('../src/config/supabase')).supabase;
    existing = await loadExistingKeys(supabase);
    console.log(chalk.gray(`   ${existing.size} existing title/author keys loaded`));
  } else if (!options.dryRun) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_KEY are required');
  } else {
    console.log(chalk.yellow('   No Supabase keys: books already in the catalogue are not filtered out'));
  }
  if (!options.dryRun && !process.env.OPENAI_API_KEY) throw new Error('OPENAI_API_KEY is required');
  const vetting = options.vet && !!process.env.OPENAI_API_KEY;
  if (options.vet && !vetting) console.log(chalk.yellow('   No OPENAI_API_KEY: skipping vetting'));

  console.log(chalk.blue('🔎 Finding candidates'));
  const all = [...(await nytCandidates()), ...curatedCandidates(), ...(await openLibraryCandidates())];
  console.log(chalk.gray(`   ${all.length} candidates before filtering`));

  // Drop books in the catalogue and duplicates; the first (highest-priority) source wins.
  const seen = new Set(existing);
  const fresh: Candidate[] = [];
  for (const c of all) {
    const key = bookKey(c.title, c.author);
    if (seen.has(key)) continue;
    seen.add(key);
    fresh.push(c);
  }

  // NYT and trending entries need an Open Library lookup (proper-case title, readers, subjects, cover).
  // Stop looking once there are plenty of finds: the lists are long and Open Library is slow.
  // Curated books are looked up only when picked.
  const rejected: Candidate[] = [];
  const passed: Candidate[] = [];
  const wanted = options.limit * 3;
  let found = 0;
  for (const c of fresh) {
    if (c.source !== 'curated' && found >= wanted) continue;
    if (c.doc === undefined && c.source !== 'curated') {
      c.doc = await findOnOpenLibrary(c).catch(() => null);
      if (c.doc) {
        const before = bookKey(c.title, c.author);
        c.title = c.doc.title;
        c.readers = c.doc.readinglog_count || 0;
        c.year = c.doc.first_publish_year;
        // The Open Library title can match a book the NYT spelling missed
        const after = bookKey(c.title, c.author);
        if (after !== before) {
          if (seen.has(after)) continue;
          seen.add(after);
        }
      }
    }
    const reason = rejectReason(c, options);
    if (reason) {
      c.reason = reason;
      rejected.push(c);
    } else {
      passed.push(c);
      if (c.source !== 'curated') found++;
    }
  }
  console.log(chalk.gray(`   ${passed.length} passed the filters, ${rejected.length} rejected`));

  const toVet = passed.filter(c => c.source !== 'curated');
  if (vetting && toVet.length) {
    console.log(chalk.blue(`🧐 Vetting ${toVet.length} candidates`));
    await vet(toVet);
  }

  const order = (c: Candidate) => SOURCE_ORDER.indexOf(c.source);
  const picks: Candidate[] = [];
  const perAuthor = new Map<string, number>();
  const ranked = passed
    .filter(c => c.source === 'curated' || !vetting || (c.score ?? 0) >= 4)
    .sort((a, b) => order(a) - order(b) || (b.score ?? 0) - (a.score ?? 0) || b.readers - a.readers);
  const pick = (c: Candidate) => {
    const author = lastName(c.author).toLowerCase();
    if (picks.includes(c) || (perAuthor.get(author) || 0) >= MAX_PER_AUTHOR) return;
    if (!c.category) c.category = 'Society';
    perAuthor.set(author, (perAuthor.get(author) || 0) + 1);
    picks.push(c);
  };
  // First the reserved slots for finds, then everything in rank order.
  for (const c of ranked.filter(c => c.source !== 'curated')) {
    if (picks.length >= Math.min(options.discover, options.limit)) break;
    pick(c);
  }
  for (const c of ranked) {
    if (picks.length >= options.limit) break;
    pick(c);
  }
  if (vetting) for (const c of toVet) if ((c.score ?? 0) < 4) rejected.push({ ...c, reason: `rated ${c.score ?? '?'}: ${c.reason ?? ''}` });

  console.log(chalk.blue(`\n✅ ${picks.length} picks`));
  for (const c of picks) {
    console.log(`   [${c.source}] ${c.title} — ${c.author} (${c.category}, ${c.readers} readers${c.score ? `, rated ${c.score}` : ''})`);
  }

  const added: { candidate: Candidate; id: string }[] = [];
  const failed: { candidate: Candidate; error: string }[] = [];
  if (!options.dryRun) {
    const { OpenAIService } = await import('../src/services/openaiService');
    const openai = new OpenAIService();
    for (const c of picks) {
      const label = `${c.title} — ${c.author}`;
      try {
        const row: any = await buildBookRow(c, c.doc);
        if (!row) throw new Error('not found on Open Library or Google Books');
        if (options.feature) row.is_featured = true;
        if (c.nyt) {
          Object.assign(row, {
            is_nyt_bestseller: true,
            nyt_list: c.nyt.list,
            nyt_rank: c.nyt.rank,
            nyt_weeks_on_list: c.nyt.weeks,
            nyt_last_updated: c.nyt.date
          });
        }
        const { data: saved, error } = await supabase.from('books').insert(row).select().single();
        if (error) throw new Error(`Book insert failed: ${error.message}`);
        added.push({ candidate: c, id: saved.id });
        console.log(chalk.green(`  ✅ Added: ${label}`));
        await generateSummaries(supabase, openai, saved);
        console.log(chalk.green(`    🤖 Summaries generated`));
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        failed.push({ candidate: c, error: message });
        console.error(chalk.red(`  ❌ ${label}: ${message}`));
      }
    }

    if (options.post && added.length) {
      runScript(['scripts/embed-books.ts']);
      runScript(['scripts/embed-ideas.ts']);
      runScript(['scripts/backfill-covers.ts', '--ids', added.map(a => a.id).join(',')]);
    }
  }

  const lines = [
    `## Weekly books${options.dryRun ? ' (dry run)' : ''}`,
    '',
    options.dryRun ? `${picks.length} books would be added.` : `${added.length} added, ${failed.length} failed.`,
    '',
    '| Book | Author | Genre | Source | Readers | Rating |',
    '| --- | --- | --- | --- | --- | --- |',
    ...picks.map(
      c => `| ${escapeCell(c.title)} | ${escapeCell(c.author)} | ${c.category} | ${c.source} | ${c.readers} | ${c.score ?? '–'} |`
    ),
    ...(failed.length ? ['', '### Failed', '', ...failed.map(f => `- ${f.candidate.title}: ${f.error}`)] : []),
    '',
    `<details><summary>Rejected (${rejected.length})</summary>`,
    '',
    ...rejected.map(c => `- ${escapeCell(c.title)} — ${escapeCell(c.author)}: ${c.reason}`),
    '',
    '</details>',
    ''
  ];
  const report = lines.join('\n');
  if (options.report) fs.writeFileSync(options.report, report);
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, report);

  console.log(chalk.blue('\n📊 Results'));
  console.log(`   ${options.dryRun ? 'Would add' : 'Added'}: ${options.dryRun ? picks.length : added.length}`);
  console.log(`   Failed: ${failed.length}`);
  // A run that tried and added nothing is broken (paused Supabase, bad key): fail the job.
  if (!options.dryRun && picks.length && !added.length) process.exit(1);
}

main().catch(error => {
  console.error(chalk.red(`💥 ${error instanceof Error ? error.message : error}`));
  process.exit(1);
});
