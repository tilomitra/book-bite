#!/usr/bin/env npx tsx

/**
 * Rewrites existing extended summaries in the chaptered format (intro, 5-8 "## " chapters,
 * "## The takeaway"; see src/services/extendedSummaryPrompt.ts). Non-fiction books with a
 * summary only; the newest summary row of each book is updated.
 *
 * Resumable: summaries already in the new format are skipped (unless --force), so re-run it
 * after an interruption. Each old text is appended to a JSONL backup before it is overwritten.
 *
 * Cost: GPT-6 Luna at $0.10 / $0.50 per 1M input / output tokens (override with
 * LUNA_USD_PER_M_INPUT / LUNA_USD_PER_M_OUTPUT). Reasoning tokens bill as output. A dry run
 * generates one sample and prices the whole run from its real token usage.
 *
 * Usage:
 *   npm run regenerate-extended-summaries -- --dry-run --limit 1
 *   npm run regenerate-extended-summaries -- --featured --by-popularity --limit 50
 *
 *   --dry-run          Print what would change and the estimated cost, generate one sample to
 *                      stdout, write nothing
 *   --limit N          Rewrite at most N summaries
 *   --ids a,b          Only these book ids
 *   --featured         Featured books first
 *   --by-popularity    Most-read books first (after featured, with --featured)
 *   --force            Also rewrite summaries already in the new format
 *   --concurrency N    Parallel requests (default 2)
 *   --delay-ms N       Pause after each book per worker (default 1000)
 *   --backup <path>    JSONL backup of replaced text (default scripts/data/extended-summary-backup.jsonl)
 */

import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import { isFiction } from '../src/utils/fiction';
import { isChapteredSummary as isNewFormat, parseExtendedSummary, wordCount } from '../src/services/extendedSummaryPrompt';
import type { OpenAIService } from '../src/services/openaiService';

dotenv.config();

const PAGE_SIZE = 1000;
const USD_PER_M_INPUT = Number(process.env.LUNA_USD_PER_M_INPUT ?? 0.10);
const USD_PER_M_OUTPUT = Number(process.env.LUNA_USD_PER_M_OUTPUT ?? 0.50);
// Used before a sample exists: ~1.2k prompt tokens, ~2k text + ~2k reasoning tokens, 1.2 attempts
const FALLBACK_TOKENS = { input: 1500, output: 5000 };
const MAX_RETRIES = 4;

interface Options {
  dryRun: boolean;
  limit: number;
  ids: string[] | null;
  featured: boolean;
  byPopularity: boolean;
  force: boolean;
  concurrency: number;
  delayMs: number;
  backup: string;
}

function parseArgs(argv: string[]): Options {
  const value = (flag: string) => {
    const i = argv.indexOf(flag);
    return i >= 0 ? argv[i + 1] : undefined;
  };
  const number = (flag: string, fallback: number) => {
    const raw = value(flag);
    if (raw === undefined) return fallback;
    const n = Number(raw);
    if (!Number.isFinite(n) || n < 0) throw new Error(`${flag} needs a number`);
    return n;
  };
  return {
    dryRun: argv.includes('--dry-run'),
    limit: number('--limit', Infinity),
    ids: value('--ids')?.split(',').map(s => s.trim()).filter(Boolean) ?? null,
    featured: argv.includes('--featured'),
    byPopularity: argv.includes('--by-popularity'),
    force: argv.includes('--force'),
    concurrency: Math.max(1, number('--concurrency', 2)),
    delayMs: number('--delay-ms', 1000),
    backup: value('--backup') ?? path.join(__dirname, 'data', 'extended-summary-backup.jsonl')
  };
}

interface BookRow {
  id: string;
  title: string;
  subtitle: string | null;
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
  key_ideas: { idea?: string }[] | null;
  books: BookRow | BookRow[] | null;
}

interface Candidate {
  summaryId: string;
  book: BookRow;
  oldText: string;
  hook: string | null;
  keyIdeas: string[];
}

async function loadCandidates(options: Options): Promise<{ candidates: Candidate[]; counts: Record<string, number> }> {
  const { supabase } = await import('../src/config/supabase');
  const rows: SummaryRow[] = [];
  for (let from = 0; ; from += PAGE_SIZE) {
    let query = supabase
      .from('summaries')
      .select('id, book_id, created_at, extended_summary, one_sentence_hook, key_ideas, books!inner(id, title, subtitle, authors, description, categories, is_featured, popularity_score)')
      .order('id')
      .range(from, from + PAGE_SIZE - 1);
    if (options.ids) query = query.in('book_id', options.ids);
    const { data, error } = await query;
    if (error) throw new Error(`Failed to load summaries: ${error.message}`);
    rows.push(...((data || []) as unknown as SummaryRow[]));
    if (!data || data.length < PAGE_SIZE) break;
  }

  // Newest summary per book: what the app shows (regeneration can leave duplicates)
  const newest = new Map<string, SummaryRow>();
  for (const row of rows) {
    const current = newest.get(row.book_id);
    if (!current || row.created_at > current.created_at) newest.set(row.book_id, row);
  }

  const counts = { books: newest.size, fiction: 0, alreadyNew: 0 };
  const candidates: Candidate[] = [];
  for (const row of newest.values()) {
    const book = Array.isArray(row.books) ? row.books[0] : row.books;
    if (!book) continue;
    if (isFiction(book)) { counts.fiction++; continue; }
    if (!options.force && isNewFormat(row.extended_summary)) { counts.alreadyNew++; continue; }
    candidates.push({
      summaryId: row.id,
      book,
      oldText: row.extended_summary ?? '',
      hook: row.one_sentence_hook,
      keyIdeas: (row.key_ideas || []).map(k => k?.idea).filter((i): i is string => Boolean(i))
    });
  }

  candidates.sort((a, b) => {
    if (options.featured && Boolean(a.book.is_featured) !== Boolean(b.book.is_featured)) {
      return a.book.is_featured ? -1 : 1;
    }
    if (options.byPopularity) return (b.book.popularity_score ?? 0) - (a.book.popularity_score ?? 0);
    return a.book.title.localeCompare(b.book.title);
  });
  return { candidates: candidates.slice(0, options.limit), counts: { ...counts, eligible: candidates.length } };
}

const cost = (input: number, output: number) => (input * USD_PER_M_INPUT + output * USD_PER_M_OUTPUT) / 1e6;

const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

function isRateLimit(error: unknown): boolean {
  const cause = (error as { cause?: { status?: number } })?.cause;
  const message = error instanceof Error ? error.message : String(error);
  return cause?.status === 429 || /429|rate limit/i.test(message);
}

async function generate(openai: OpenAIService, c: Candidate) {
  return openai.generateExtendedSummaryDetailed(
    c.book.title,
    c.book.authors || [],
    c.book.description || '',
    c.book.categories || [],
    { subtitle: c.book.subtitle, hook: c.hook, keyIdeas: c.keyIdeas }
  );
}

async function withRetries<T>(label: string, fn: () => Promise<T>): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (attempt >= MAX_RETRIES) throw error;
      const wait = (isRateLimit(error) ? 20000 : 3000) * 2 ** attempt;
      console.log(`   ⏳ ${label}: ${error instanceof Error ? error.message : error}; retrying in ${wait / 1000}s`);
      await sleep(wait);
    }
  }
}

function describe(c: Candidate) {
  const author = c.book.authors?.[0] ?? 'unknown';
  return `"${c.book.title}" by ${author}`;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  console.log(`📚 Loading summaries${options.ids ? ` for ${options.ids.length} book ids` : ''}...`);
  const { candidates, counts } = await loadCandidates(options);
  console.log(`   ${counts.books} books with a summary; ${counts.fiction} fiction skipped; ${counts.alreadyNew} already in the new format${options.force ? ' (rewritten anyway: --force)' : ''}`);
  console.log(`   ${candidates.length} to rewrite${Number.isFinite(options.limit) ? ` (--limit ${options.limit})` : ''}`);
  const fallback = cost(FALLBACK_TOKENS.input, FALLBACK_TOKENS.output);
  console.log(`💰 Estimate: ~$${fallback.toFixed(4)}/book → ~$${(fallback * candidates.length).toFixed(2)} (GPT-6 Luna, $${USD_PER_M_INPUT}/$${USD_PER_M_OUTPUT} per 1M in/out)`);
  if (candidates.length === 0) return;

  const { OpenAIService } = await import('../src/services/openaiService');
  const openai = new OpenAIService();

  if (options.dryRun) {
    console.log('\nWould rewrite:');
    candidates.slice(0, 20).forEach((c, i) => {
      const old = c.oldText.trim();
      console.log(`  ${i + 1}. ${describe(c)} — ${wordCount(old)} words now${old ? `, starts "${old.slice(0, 70).replace(/\s+/g, ' ')}…"` : ' (empty)'}`);
    });
    if (candidates.length > 20) console.log(`  … and ${candidates.length - 20} more`);

    const sample = candidates[0];
    console.log(`\n🧪 Sample (not saved): ${describe(sample)}`);
    const started = Date.now();
    const result = await generate(openai, sample);
    const sampleCost = cost(result.usage.inputTokens, result.usage.outputTokens);
    const { chapters } = parseExtendedSummary(result.text);
    console.log('─'.repeat(72));
    console.log(result.text);
    console.log('─'.repeat(72));
    console.log(`${wordCount(result.text)} words, ${chapters.length} chapters, ${result.attempts} attempt(s), ${Math.round((Date.now() - started) / 1000)}s`);
    console.log(`Format problems: ${result.problems.length ? result.problems.join('; ') : 'none'}`);
    console.log(`Tokens: ${result.usage.inputTokens} in, ${result.usage.outputTokens} out (incl. reasoning) → $${sampleCost.toFixed(4)}`);
    console.log(`💰 At this sample's usage: ~$${(sampleCost * candidates.length).toFixed(2)} for this run (${candidates.length} books), ~$${(sampleCost * counts.eligible).toFixed(2)} for all ${counts.eligible} eligible`);
    console.log('\nDry run: nothing written.');
    return;
  }

  const { supabase } = await import('../src/config/supabase');
  fs.mkdirSync(path.dirname(options.backup), { recursive: true });

  const queue = [...candidates];
  const total = candidates.length;
  const stats = { done: 0, failed: 0, withProblems: 0, input: 0, output: 0 };
  const failures: string[] = [];
  const startedAt = Date.now();

  async function worker() {
    for (let c = queue.shift(); c; c = queue.shift()) {
      const label = describe(c);
      try {
        const result = await withRetries(label, () => generate(openai, c!));
        stats.input += result.usage.inputTokens;
        stats.output += result.usage.outputTokens;
        // Keep a format-breaking answer out of the app: the old text stays and a re-run retries it
        if (!isNewFormat(result.text)) throw new Error(`bad format: ${result.problems.join('; ')}`);
        if (result.problems.length > 0) stats.withProblems++;

        fs.appendFileSync(options.backup, JSON.stringify({
          summary_id: c.summaryId, book_id: c.book.id, title: c.book.title,
          replaced_at: new Date().toISOString(), extended_summary: c.oldText
        }) + '\n');
        const { error } = await supabase
          .from('summaries')
          .update({ extended_summary: result.text }) // updated_at is set by a trigger
          .eq('id', c.summaryId);
        if (error) throw new Error(`update failed: ${error.message}`);

        stats.done++;
        const n = stats.done + stats.failed;
        const elapsed = (Date.now() - startedAt) / 1000;
        const eta = Math.round((elapsed / n) * (total - n) / 60);
        console.log(`[${n}/${total}] ✅ ${label} — ${wordCount(result.text)} words${result.problems.length ? ` (⚠️ ${result.problems.join('; ')})` : ''} · $${cost(stats.input, stats.output).toFixed(3)} so far · ~${eta} min left`);
      } catch (error) {
        stats.failed++;
        failures.push(`${label} (${c.book.id}): ${error instanceof Error ? error.message : error}`);
        console.log(`[${stats.done + stats.failed}/${total}] ❌ ${label}: ${error instanceof Error ? error.message : error}`);
      }
      if (options.delayMs > 0) await sleep(options.delayMs);
    }
  }

  await Promise.all(Array.from({ length: Math.min(options.concurrency, total) }, worker));

  console.log('═'.repeat(72));
  console.log(`✅ Rewritten: ${stats.done}  ❌ Failed: ${stats.failed}  ⚠️ Saved with minor problems: ${stats.withProblems}`);
  console.log(`💰 ${stats.input.toLocaleString()} in / ${stats.output.toLocaleString()} out tokens → $${cost(stats.input, stats.output).toFixed(2)}`);
  console.log(`🗄️  Old text backed up to ${options.backup}`);
  if (failures.length) {
    console.log('Failures (re-run to retry them):');
    failures.forEach(f => console.log(`  - ${f}`));
  }
}

if (require.main === module) {
  main().catch(error => {
    console.error('💥', error instanceof Error ? error.message : error);
    process.exit(1);
  });
}
