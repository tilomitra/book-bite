import { supabase } from '../config/supabase';
import NodeCache from 'node-cache';
import { isFiction } from '../utils/fiction';
import { jitterByRank, seededRandom } from '../utils/shuffle';
import { StaleCache } from '../utils/staleCache';

/** Stable per book (and seed), so a book shows the same key idea on every page of one feed */
function ideaIndex(key: string, count: number) {
  let hash = 0;
  for (const char of key) hash = (hash * 31 + char.charCodeAt(0)) & 0xffff;
  return hash % count;
}

type Candidate = { book: any; hook: string | null; keyIdeas: any[] };

/** PostgREST embeds one object or a list (regeneration can leave several); use the newest */
function newestSummary(summaries: any) {
  return (Array.isArray(summaries) ? [...summaries] : [summaries])
    .sort((a, b) => String(b?.created_at).localeCompare(String(a?.created_at)))[0];
}

function toCandidate({ summaries, ...book }: any): Candidate | null {
  if (isFiction(book)) return null;
  const summary = newestSummary(summaries);
  const keyIdeas = summary?.key_ideas;
  if (!Array.isArray(keyIdeas) || keyIdeas.length === 0) return null;
  return { book, hook: summary.one_sentence_hook ?? null, keyIdeas };
}

/**
 * Discover's endless feed: non-fiction books with a summary, most read first, each with its hook and one key idea.
 * Paged so the app can keep loading as the reader scrolls. With a seed (new for each visit) the order and the
 * idea per book are mixed, so the feed is different every time but stays the same while one visit pages through it.
 */
export class HighlightService {
  // useClones off: cloning the whole candidate list on every read took over a second on Render
  private cache = new NodeCache({ stdTTL: 1800, checkperiod: 300, useClones: false });
  private candidates = new StaleCache(() => this.loadCandidates(), 30 * 60 * 1000);

  /** Loads the candidates at startup, so the first reader doesn't wait for the full scan */
  warm() {
    return this.candidates.get();
  }

  async getHighlights(page: number, limit: number, seed?: number) {
    return seed === undefined ? this.getRankedPage(page, limit) : this.getMixedPage(page, limit, seed);
  }

  private async getRankedPage(page: number, limit: number) {
    const cacheKey = `highlights:${page}:${limit}`;
    const cached = this.cache.get(cacheKey);
    if (cached) return cached;

    const offset = (page - 1) * limit;
    // One extra row tells us whether there is another page
    const { data, error } = await supabase
      .from('books')
      .select('*, summaries!inner(one_sentence_hook, key_ideas, created_at)')
      .order('popularity_score', { ascending: false, nullsFirst: false })
      .order('id')
      .range(offset, offset + limit);

    if (error) {
      throw new Error(`Failed to fetch highlights: ${error.message}`);
    }

    const rows = data || [];
    // Filtered here rather than in SQL, so a page can come back a little short
    const items = rows.slice(0, limit).flatMap(row => {
      const candidate = toCandidate(row);
      if (!candidate) return [];
      return [{ book: candidate.book, hook: candidate.hook, idea: candidate.keyIdeas[ideaIndex(candidate.book.id, candidate.keyIdeas.length)] }];
    });

    const result = { items, page, hasMore: rows.length > limit };
    this.cache.set(cacheKey, result);
    return result;
  }

  private async getMixedPage(page: number, limit: number, seed: number) {
    const ordered = jitterByRank(await this.candidates.get(), seededRandom(seed));
    const offset = (page - 1) * limit;
    const items = ordered.slice(offset, offset + limit).map(({ book, hook, keyIdeas }) => ({
      book,
      hook,
      idea: keyIdeas[ideaIndex(`${book.id}:${seed}`, keyIdeas.length)]
    }));
    return { items, page, hasMore: offset + limit < ordered.length };
  }

  /** Every non-fiction book with a summary, most read first; each seed reorders the same list */
  private async loadCandidates(): Promise<Candidate[]> {
    // PostgREST returns at most 1000 rows per request
    const pageSize = 1000;
    const candidates: Candidate[] = [];
    for (let from = 0; ; from += pageSize) {
      const { data, error } = await supabase
        .from('books')
        .select('*, summaries!inner(one_sentence_hook, key_ideas, created_at)')
        .order('popularity_score', { ascending: false, nullsFirst: false })
        .order('id')
        .range(from, from + pageSize - 1);

      if (error) {
        throw new Error(`Failed to fetch highlights: ${error.message}`);
      }
      const rows = data || [];
      for (const row of rows) {
        const candidate = toCandidate(row);
        if (candidate) candidates.push(candidate);
      }
      if (rows.length < pageSize) break;
    }

    return candidates;
  }
}
