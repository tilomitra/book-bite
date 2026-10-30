#!/usr/bin/env npx tsx

/**
 * Add a hand-picked list of well-known non-fiction books, with covers and summaries.
 *
 * The list is in scripts/data/curated-books.json ({ title, author, category }).
 * For each book the script:
 * 1. Skips it if a book with the same title and author is already in the database.
 * 2. Looks it up on Open Library (metadata, ISBN, cover image, ratings).
 *    When GOOGLE_BOOKS_API_KEY is set, Google Books fills in books and descriptions Open Library lacks.
 * 3. Inserts the book, then generates the summary and the extended summary with OpenAI.
 *
 * Usage:
 *   npx tsx scripts/add-curated-books.ts [options]
 *
 * Options:
 *   --dry-run          Look up books and print what would be added. No DB writes, no OpenAI calls.
 *   --limit <n>        Process at most n books from the list
 *   --category <name>  Only process books in this category
 *   --no-summaries     Insert books but do not generate summaries
 *   --concurrency <n>  Books processed in parallel (default 3)
 *
 * Cost: about $0.003 per book (GPT-6 Luna summary + extended summary).
 */

import { config } from 'dotenv';
import fs from 'fs';
import path from 'path';
import chalk from 'chalk';
import { isFiction } from '../src/utils/fiction';
import { CuratedBook, bookKey, buildBookRow, generateSummaries, loadExistingKeys } from './lib/bookImport';

config();

interface Options {
  dryRun: boolean;
  limit?: number;
  category?: string;
  summaries: boolean;
  concurrency: number;
}

function parseArgs(): Options {
  const args = process.argv.slice(2);
  const value = (flag: string) => {
    const i = args.indexOf(flag);
    return i >= 0 ? args[i + 1] : undefined;
  };
  return {
    dryRun: args.includes('--dry-run'),
    limit: value('--limit') ? parseInt(value('--limit')!, 10) : undefined,
    category: value('--category'),
    summaries: !args.includes('--no-summaries'),
    concurrency: Math.max(1, parseInt(value('--concurrency') || '3', 10))
  };
}

async function main() {
  const options = parseArgs();
  const listPath = path.join(__dirname, 'data', 'curated-books.json');
  let books: CuratedBook[] = JSON.parse(fs.readFileSync(listPath, 'utf8'));
  if (options.category) books = books.filter(b => b.category.toLowerCase() === options.category!.toLowerCase());
  if (options.limit) books = books.slice(0, options.limit);

  console.log(chalk.blue(`📚 ${books.length} curated books${options.dryRun ? ' (dry run)' : ''}`));

  // Load the DB clients only for real runs, so a dry run works without Supabase or OpenAI keys.
  let supabase: any = null;
  let openai: any = null;
  let existing = new Set<string>();
  if (!options.dryRun) {
    supabase = (await import('../src/config/supabase')).supabase;
    if (options.summaries) {
      const { OpenAIService } = await import('../src/services/openaiService');
      openai = new OpenAIService();
    }
    existing = await loadExistingKeys(supabase);
    console.log(chalk.gray(`   ${existing.size} existing title/author keys loaded`));
  }

  const stats = { added: 0, skipped: 0, notFound: 0, noCover: 0, summaries: 0, failed: 0 };
  const notFound: string[] = [];
  const queue = [...books];

  async function worker() {
    for (let book = queue.shift(); book; book = queue.shift()) {
      const label = `${book.title} — ${book.author}`;
      try {
        if (existing.has(bookKey(book.title, book.author))) {
          stats.skipped++;
          console.log(chalk.yellow(`  📋 Already in DB: ${label}`));
          continue;
        }

        // The list is hand-picked non-fiction; this catches a novel added by mistake
        if (isFiction({ title: book.title, authors: [book.author], categories: [book.category] })) {
          stats.skipped++;
          console.log(chalk.yellow(`  📕 Fiction, skipped: ${label}`));
          continue;
        }

        const row = await buildBookRow(book);
        if (!row) {
          stats.notFound++;
          notFound.push(label);
          console.log(chalk.red(`  ❓ Not found: ${label}`));
          continue;
        }
        if (!row.cover_url) stats.noCover++;

        if (options.dryRun) {
          stats.added++;
          console.log(
            chalk.green(`  ✅ ${label}`) +
              chalk.gray(` (${row.published_year ?? '?'}, ${row.cover_url ? 'cover' : 'NO COVER'}, ${row.description ? 'description' : 'no description'})`)
          );
          continue;
        }

        const { data: saved, error } = await supabase.from('books').insert(row).select().single();
        if (error) throw new Error(`Book insert failed: ${error.message}`);
        existing.add(bookKey(book.title, book.author));
        stats.added++;
        console.log(chalk.green(`  ✅ Added: ${label}`));

        if (openai) {
          await generateSummaries(supabase, openai, saved);
          stats.summaries++;
          console.log(chalk.green(`    🤖 Summaries generated: ${book.title}`));
        }
      } catch (error) {
        stats.failed++;
        console.error(chalk.red(`  ❌ ${label}: ${error instanceof Error ? error.message : error}`));
      }
    }
  }

  await Promise.all(Array.from({ length: options.concurrency }, worker));

  console.log(chalk.blue('\n📊 Results'));
  console.log(`   ${options.dryRun ? 'Would add' : 'Added'}: ${stats.added}`);
  console.log(`   Already in DB: ${stats.skipped}`);
  console.log(`   Not found: ${stats.notFound}`);
  console.log(`   Without cover: ${stats.noCover}`);
  if (!options.dryRun) console.log(`   Summaries generated: ${stats.summaries}`);
  console.log(`   Failed: ${stats.failed}`);
  if (notFound.length) console.log(chalk.gray(`\nNot found:\n  ${notFound.join('\n  ')}`));
}

main().catch(error => {
  console.error(chalk.red(`💥 ${error instanceof Error ? error.message : error}`));
  process.exit(1);
});
