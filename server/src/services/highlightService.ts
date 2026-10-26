import { supabase } from '../config/supabase';
import NodeCache from 'node-cache';

/** Stable per book, so a book shows the same key idea on every visit */
function ideaIndex(bookId: string, count: number) {
  let hash = 0;
  for (const char of bookId) hash = (hash * 31 + char.charCodeAt(0)) & 0xffff;
  return hash % count;
}

/**
 * Discover's endless feed: books with a summary, most read first, each with its hook and one key idea.
 * Paged so the app can keep loading as the reader scrolls.
 */
export class HighlightService {
  private cache = new NodeCache({ stdTTL: 1800, checkperiod: 300 });

  async getHighlights(page: number, limit: number) {
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
    const items = rows.slice(0, limit).flatMap(({ summaries, ...book }) => {
      // PostgREST embeds one object or a list (regeneration can leave several); use the newest
      const summary = (Array.isArray(summaries) ? [...summaries] : [summaries]).sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)))[0];
      const keyIdeas = summary?.key_ideas;
      if (!Array.isArray(keyIdeas) || keyIdeas.length === 0) return [];
      return [{
        book,
        hook: summary.one_sentence_hook ?? null,
        idea: keyIdeas[ideaIndex(book.id, keyIdeas.length)]
      }];
    });

    const result = { items, page, hasMore: rows.length > limit };
    this.cache.set(cacheKey, result);
    return result;
  }
}
