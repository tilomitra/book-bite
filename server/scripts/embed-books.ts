#!/usr/bin/env npx tsx

/**
 * Embeds every book (title, authors, categories, description, summary hook, key ideas)
 * into `book_embeddings` for the personalized Discover shelves (POST /api/books/for-you).
 * Needs server/supabase/add-book-embeddings.sql applied first.
 *
 * Only books whose embedded text changed since the last run are sent to OpenAI, so re-run it
 * after adding books or generating summaries. text-embedding-3-small costs $0.02 per 1M tokens:
 * a full run over ~2,000 books is a few cents.
 *
 * Usage:
 *   npx tsx scripts/embed-books.ts [--dry-run] [--force] [--limit <n>]
 *
 *   --dry-run  Count what would be embedded and estimate the cost, write nothing
 *   --force    Re-embed books whose text didn't change
 *   --limit    Embed at most n books
 */

import dotenv from 'dotenv';
import { supabase } from '../src/config/supabase';
import {
  EmbeddingService,
  EMBEDDING_MODEL,
  bookEmbeddingText,
  contentHash,
  toVectorLiteral
} from '../src/services/embeddingService';

dotenv.config();

const PAGE_SIZE = 1000;
const UPSERT_BATCH = 100;
const USD_PER_MILLION_TOKENS = 0.02;

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const force = args.includes('--force');
const limitIndex = args.indexOf('--limit');
const limit = limitIndex >= 0 ? Number(args[limitIndex + 1]) : Infinity;

interface BookRow {
  id: string;
  title: string;
  subtitle: string | null;
  authors: string[] | null;
  categories: string[] | null;
  description: string | null;
  // PostgREST embeds a to-one relation as an object, a to-many relation as an array
  summaries: SummaryRow | SummaryRow[] | null;
}

interface SummaryRow {
  one_sentence_hook: string | null;
  key_ideas: { idea: string }[] | null;
  who_should_read: string | null;
  created_at: string;
}

async function fetchAll<T>(table: string, select: string): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0; ; from += PAGE_SIZE) {
    const { data, error } = await supabase
      .from(table)
      .select(select)
      .order(table === 'books' ? 'id' : 'book_id')
      .range(from, from + PAGE_SIZE - 1);
    if (error) throw new Error(`Failed to read ${table}: ${error.message}`);
    rows.push(...((data || []) as T[]));
    if (!data || data.length < PAGE_SIZE) return rows;
  }
}

async function main() {
  const books = await fetchAll<BookRow>(
    'books',
    'id, title, subtitle, authors, categories, description, summaries(one_sentence_hook, key_ideas, who_should_read, created_at)'
  );
  const existing = await fetchAll<{ book_id: string; content_hash: string }>(
    'book_embeddings',
    'book_id, content_hash'
  );
  const existingHash = new Map(existing.map(e => [e.book_id, e.content_hash]));

  const pending = books
    .map(book => {
      // Regeneration can leave several summaries per book; the newest wins, as in the API
      const summaries = Array.isArray(book.summaries) ? book.summaries : book.summaries ? [book.summaries] : [];
      const summary = [...summaries]
        .sort((a, b) => b.created_at.localeCompare(a.created_at))[0] ?? null;
      const text = bookEmbeddingText({ ...book, summary });
      return { id: book.id, title: book.title, text, hash: contentHash(text) };
    })
    .filter(b => force || existingHash.get(b.id) !== b.hash)
    .slice(0, limit);

  const chars = pending.reduce((sum, b) => sum + b.text.length, 0);
  const estimatedTokens = Math.ceil(chars / 4);
  console.log(`${books.length} books, ${existing.length} already embedded, ${pending.length} to embed`);
  console.log(`~${estimatedTokens.toLocaleString()} tokens, ~$${(estimatedTokens / 1e6 * USD_PER_MILLION_TOKENS).toFixed(4)}`);

  if (dryRun || pending.length === 0) return;

  const embeddings = new EmbeddingService();
  let done = 0;
  for (let i = 0; i < pending.length; i += UPSERT_BATCH) {
    const batch = pending.slice(i, i + UPSERT_BATCH);
    const vectors = await embeddings.embed(batch.map(b => b.text));
    const { error } = await supabase.from('book_embeddings').upsert(
      batch.map((b, j) => ({
        book_id: b.id,
        embedding: toVectorLiteral(vectors[j]),
        model: EMBEDDING_MODEL,
        content_hash: b.hash,
        updated_at: new Date().toISOString()
      }))
    );
    if (error) throw new Error(`Failed to save embeddings: ${error.message}`);
    done += batch.length;
    console.log(`Embedded ${done}/${pending.length}`);
  }
}

main().catch(error => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
