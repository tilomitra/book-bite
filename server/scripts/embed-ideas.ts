#!/usr/bin/env npx tsx

/**
 * Embeds every key idea and "how to apply" action of every summary into `idea_embeddings`, so Ask
 * (POST /api/ask) can find the single idea that answers a question. Needs
 * server/supabase/add-idea-embeddings.sql applied first.
 *
 * Only passages whose text changed are sent to OpenAI, and passages that no longer exist are
 * deleted, so re-run it after generating or regenerating summaries. ~20k short passages are well
 * under a million tokens: a full run costs a couple of cents.
 *
 * Usage:
 *   npx tsx scripts/embed-ideas.ts [--dry-run] [--force] [--limit <n>]
 *
 *   --dry-run  Count what would be embedded and estimate the cost, write nothing
 *   --force    Re-embed passages whose text didn't change
 *   --limit    Embed at most n passages
 */

import dotenv from 'dotenv';
import { supabase } from '../src/config/supabase';
import { EmbeddingService, EMBEDDING_MODEL, contentHash, toVectorLiteral } from '../src/services/embeddingService';
import { Passage, PassageSource, newestSummary, summaryPassages } from '../src/services/askPassages';

dotenv.config();

const PAGE_SIZE = 1000;
const UPSERT_BATCH = 200;
const USD_PER_MILLION_TOKENS = 0.02;

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const force = args.includes('--force');
const limitIndex = args.indexOf('--limit');
const limit = limitIndex >= 0 ? Number(args[limitIndex + 1]) : Infinity;

type SummaryRow = PassageSource & { book_id: string; created_at: string };

async function fetchAll<T>(table: string, select: string, order: string): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0; ; from += PAGE_SIZE) {
    const { data, error } = await supabase.from(table).select(select).order(order).range(from, from + PAGE_SIZE - 1);
    if (error) throw new Error(`Failed to read ${table}: ${error.message}`);
    rows.push(...((data || []) as T[]));
    if (!data || data.length < PAGE_SIZE) return rows;
  }
}

async function main() {
  const summaries = await fetchAll<SummaryRow>('summaries', 'book_id, key_ideas, how_to_apply, created_at', 'id');
  const byBook = new Map<string, SummaryRow[]>();
  summaries.forEach(s => byBook.set(s.book_id, [...(byBook.get(s.book_id) ?? []), s]));

  const passages: (Passage & { hash: string })[] = [];
  for (const [bookId, rows] of byBook) {
    const summary = newestSummary(rows);
    if (!summary) continue;
    summaryPassages(bookId, summary).forEach(p => passages.push({ ...p, hash: contentHash(p.text) }));
  }

  const existing = await fetchAll<{ id: string; content_hash: string }>('idea_embeddings', 'id, content_hash', 'id');
  const existingHash = new Map(existing.map(e => [e.id, e.content_hash]));
  const current = new Set(passages.map(p => p.id));
  const stale = existing.map(e => e.id).filter(id => !current.has(id));
  const pending = passages.filter(p => force || existingHash.get(p.id) !== p.hash).slice(0, limit);

  const estimatedTokens = Math.ceil(pending.reduce((sum, p) => sum + p.text.length, 0) / 4);
  console.log(`${byBook.size} books, ${passages.length} passages, ${existing.length} embedded, ${pending.length} to embed, ${stale.length} to delete`);
  console.log(`~${estimatedTokens.toLocaleString()} tokens, ~$${(estimatedTokens / 1e6 * USD_PER_MILLION_TOKENS).toFixed(4)}`);
  if (dryRun) return;

  for (let i = 0; i < stale.length; i += UPSERT_BATCH) {
    const { error } = await supabase.from('idea_embeddings').delete().in('id', stale.slice(i, i + UPSERT_BATCH));
    if (error) throw new Error(`Failed to delete stale passages: ${error.message}`);
  }

  const embeddings = new EmbeddingService();
  let done = 0;
  for (let i = 0; i < pending.length; i += UPSERT_BATCH) {
    const batch = pending.slice(i, i + UPSERT_BATCH);
    const vectors = await embeddings.embed(batch.map(p => p.text));
    const { error } = await supabase.from('idea_embeddings').upsert(
      batch.map((p, j) => ({
        id: p.id,
        book_id: p.bookId,
        kind: p.kind,
        position: p.position,
        text: p.text,
        embedding: toVectorLiteral(vectors[j]),
        model: EMBEDDING_MODEL,
        content_hash: p.hash,
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
