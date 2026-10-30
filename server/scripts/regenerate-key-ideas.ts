#!/usr/bin/env npx tsx

/**
 * Rewrites key ideas that are only headings ("Redefining Courageous Leadership") into claims that
 * stand on their own (see src/services/keyIdeaPrompt.ts). Newest summary row of each non-fiction book
 * whose ideas average under --min-words words. Ids, tags, confidence and sources of each idea stay.
 *
 * Resumable: rewritten books no longer count as thin. Old ideas are appended to a JSONL backup first.
 * Afterwards re-run embed-ideas and embed-books: Ask and recommendations read this text.
 *
 * Usage:
 *   npm run regenerate-key-ideas -- --dry-run --ids <uuid>
 *   npm run regenerate-key-ideas -- --featured --by-popularity --limit 50
 *
 *   --dry-run          Print the old and new ideas of one sample and the estimated cost, write nothing
 *   --limit N          Rewrite at most N books
 *   --ids a,b          Only these book ids (thin or not)
 *   --featured         Featured books first
 *   --by-popularity    Most-read books first (after featured, with --featured)
 *   --min-words N      Average idea length below which a book is thin (default 10)
 *   --concurrency N    Parallel requests (default 2)
 *   --delay-ms N       Pause after each book per worker (default 500)
 *   --backup <path>    JSONL backup (default scripts/data/key-ideas-backup.jsonl)
 */

import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import { isFiction } from '../src/utils/fiction';
import { MIN_AVERAGE_IDEA_WORDS, hasThinIdeas } from '../src/services/keyIdeaPrompt';
import type { OpenAIService } from '../src/services/openaiService';

dotenv.config();

const PAGE_SIZE = 1000;
const USD_PER_M_INPUT = Number(process.env.LUNA_USD_PER_M_INPUT ?? 0.10);
const USD_PER_M_OUTPUT = Number(process.env.LUNA_USD_PER_M_OUTPUT ?? 0.50);

type Idea = { idea?: string } & Record<string, unknown>;

interface BookRow {
  id: string;
  title: string;
  authors: string[] | null;
  description: string | null;
  categories: string[] | null;
  is_featured: boolean | null;
  popularity_score: number | null;
}

interface SummaryRow {
  id: string;
  book_id: string;
  created_at: string;
  extended_summary: string | null;
  one_sentence_hook: string | null;
  key_ideas: Idea[] | null;
  books: BookRow | BookRow[] | null;
}

interface Candidate {
  row: SummaryRow;
  book: BookRow;
  ideas: Idea[];
}

function parseArgs(argv: string[]) {
  const value = (flag: string) => {
    const i = argv.indexOf(flag);
    return i >= 0 ? argv[i + 1] : undefined;
  };
  const number = (flag: string, fallback: number) => {
    const n = Number(value(flag) ?? fallback);
    if (!Number.isFinite(n) && n !== Infinity) throw new Error(`${flag} needs a number`);
    return n;
  };
  return {
    dryRun: argv.includes('--dry-run'),
    limit: number('--limit', Infinity),
    ids: value('--ids')?.split(',').map(s => s.trim()).filter(Boolean) ?? null,
    featured: argv.includes('--featured'),
    byPopularity: argv.includes('--by-popularity'),
    minWords: number('--min-words', MIN_AVERAGE_IDEA_WORDS),
    concurrency: Math.max(1, number('--concurrency', 2)),
    delayMs: number('--delay-ms', 500),
    backup: value('--backup') ?? path.join(__dirname, 'data', 'key-ideas-backup.jsonl')
  };
}

type Options = ReturnType<typeof parseArgs>;

async function loadCandidates(options: Options): Promise<Candidate[]> {
  const { supabase } = await import('../src/config/supabase');
  const rows: SummaryRow[] = [];
  for (let from = 0; ; from += PAGE_SIZE) {
    let query = supabase
      .from('summaries')
      .select('id, book_id, created_at, extended_summary, one_sentence_hook, key_ideas, books!inner(id, title, authors, description, categories, is_featured, popularity_score)')
      .order('id')
      .range(from, from + PAGE_SIZE - 1);
    if (options.ids) query = query.in('book_id', options.ids);
    const { data, error } = await query;
    if (error) throw new Error(`Failed to load summaries: ${error.message}`);
    rows.push(...((data || []) as unknown as SummaryRow[]));
    if (!data || data.length < PAGE_SIZE) break;
  }

  const newest = new Map<string, SummaryRow>();
  for (const row of rows) {
    const current = newest.get(row.book_id);
    if (!current || row.created_at > current.created_at) newest.set(row.book_id, row);
  }

  const candidates: Candidate[] = [];
  for (const row of newest.values()) {
    const book = Array.isArray(row.books) ? row.books[0] : row.books;
    if (!book || isFiction(book)) continue;
    const ideas = (row.key_ideas || []).filter(idea => Boolean(idea?.idea));
    if (ideas.length === 0) continue;
    if (!options.ids && !hasThinIdeas(ideas.map(idea => idea.idea!), options.minWords)) continue;
    candidates.push({ row, book, ideas });
  }

  candidates.sort((a, b) => {
    if (options.featured && Boolean(a.book.is_featured) !== Boolean(b.book.is_featured)) {
      return a.book.is_featured ? -1 : 1;
    }
    if (options.byPopularity) return (b.book.popularity_score ?? 0) - (a.book.popularity_score ?? 0);
    return a.book.title.localeCompare(b.book.title);
  });
  return candidates.slice(0, options.limit);
}

const cost = (input: number, output: number) => (input * USD_PER_M_INPUT + output * USD_PER_M_OUTPUT) / 1e6;
const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

function rewrite(openai: OpenAIService, c: Candidate) {
  return openai.rewriteKeyIdeas({
    title: c.book.title,
    authors: c.book.authors || [],
    description: c.book.description || '',
    hook: c.row.one_sentence_hook,
    extendedSummary: c.row.extended_summary,
    currentIdeas: c.ideas.map(idea => idea.idea!)
  });
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const candidates = await loadCandidates(options);
  console.log(`📚 ${candidates.length} books to rewrite`);
  if (candidates.length === 0) return;

  const { OpenAIService } = await import('../src/services/openaiService');
  const openai = new OpenAIService();

  if (options.dryRun) {
    const sample = candidates[0];
    const result = await rewrite(openai, sample);
    console.log(`\n🧪 Sample (not saved): "${sample.book.title}"`);
    sample.ideas.forEach((idea, i) => console.log(`\n- ${idea.idea}\n+ ${result.ideas[i]}`));
    const each = cost(result.usage.inputTokens, result.usage.outputTokens);
    console.log(`\n💰 $${each.toFixed(4)} for this book → ~$${(each * candidates.length).toFixed(2)} for ${candidates.length}`);
    console.log('Dry run: nothing written.');
    return;
  }

  const { supabase } = await import('../src/config/supabase');
  fs.mkdirSync(path.dirname(options.backup), { recursive: true });
  const queue = [...candidates];
  const stats = { done: 0, failed: 0, input: 0, output: 0 };

  async function worker() {
    for (let c = queue.shift(); c; c = queue.shift()) {
      try {
        const result = await rewrite(openai, c);
        stats.input += result.usage.inputTokens;
        stats.output += result.usage.outputTokens;
        fs.appendFileSync(options.backup, JSON.stringify({
          summary_id: c.row.id, book_id: c.book.id, title: c.book.title,
          replaced_at: new Date().toISOString(), key_ideas: c.row.key_ideas
        }) + '\n');
        const ideas = c.ideas.map((idea, i) => ({ ...idea, idea: result.ideas[i] }));
        const { error } = await supabase.from('summaries').update({ key_ideas: ideas }).eq('id', c.row.id);
        if (error) throw new Error(`update failed: ${error.message}`);
        stats.done++;
        console.log(`[${stats.done + stats.failed}/${candidates.length}] ✅ ${c.book.title} · $${cost(stats.input, stats.output).toFixed(3)} so far`);
      } catch (error) {
        stats.failed++;
        console.log(`[${stats.done + stats.failed}/${candidates.length}] ❌ ${c.book.title} (${c.book.id}): ${error instanceof Error ? error.message : error}`);
      }
      if (options.delayMs > 0) await sleep(options.delayMs);
    }
  }

  await Promise.all(Array.from({ length: Math.min(options.concurrency, candidates.length) }, worker));
  console.log(`✅ Rewritten: ${stats.done}  ❌ Failed: ${stats.failed}  💰 $${cost(stats.input, stats.output).toFixed(2)}`);
  console.log(`🗄️  Old ideas backed up to ${options.backup}. Now re-run embed-ideas and embed-books.`);
}

if (require.main === module) {
  main().catch(error => {
    console.error('💥', error instanceof Error ? error.message : error);
    process.exit(1);
  });
}
