import { supabase } from '../config/supabase';
import NodeCache from 'node-cache';
import { isNonFiction, CategorizedBook } from '../utils/fiction';

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * Pick the book and key idea for a date. Pure, so every client gets the same pick for a day.
 * Book ids must be sorted. Consecutive days walk through all books before any repeats,
 * and each new round uses the next key idea of each book.
 */
export function pickDailyIdea(sortedBookIds: string[], date: string) {
  if (sortedBookIds.length === 0) return null;
  const dayNumber = Math.floor(Date.parse(`${date}T00:00:00Z`) / MS_PER_DAY);
  const count = sortedBookIds.length;
  const bookIndex = ((dayNumber % count) + count) % count;
  const round = Math.floor(dayNumber / count);
  return { bookId: sortedBookIds[bookIndex], round };
}

export class DailyIdeaService {
  private cache: NodeCache;

  constructor() {
    // One pick per date; refresh the candidate list hourly
    this.cache = new NodeCache({ stdTTL: 3600, checkperiod: 600 });
  }

  /** Ids of non-fiction books that have a summary, featured books first (casual-friendly titles) */
  private async getCandidateBookIds(): Promise<string[]> {
    const cached = this.cache.get<string[]>('daily-idea:candidates');
    if (cached) return cached;

    const featured = await supabase
      .from('summaries')
      .select('book_id, books!inner(is_featured, title, authors, categories)')
      .eq('books.is_featured', true);
    if (featured.error) {
      throw new Error(`Failed to fetch daily idea candidates: ${featured.error.message}`);
    }

    let rows = featured.data || [];
    if (rows.length === 0) {
      const all = await supabase
        .from('summaries')
        .select('book_id, books!inner(title, authors, categories)')
        .limit(1000);
      if (all.error) {
        throw new Error(`Failed to fetch daily idea candidates: ${all.error.message}`);
      }
      rows = (all.data || []) as typeof rows;
    }

    // Fiction has no ideas to apply. Regeneration can leave duplicate summaries per book.
    const nonFiction = (rows as unknown as { book_id: string; books: CategorizedBook | CategorizedBook[] }[])
      .filter(r => (Array.isArray(r.books) ? r.books : [r.books]).every(b => !b || isNonFiction(b)));
    const ids = Array.from(new Set(nonFiction.map(r => r.book_id))).sort();
    this.cache.set('daily-idea:candidates', ids);
    return ids;
  }

  async getDailyIdea(date: string) {
    const cacheKey = `daily-idea:${date}`;
    const cached = this.cache.get(cacheKey);
    if (cached) return cached;

    const pick = pickDailyIdea(await this.getCandidateBookIds(), date);
    if (!pick) return null;

    const dailyIdea = await this.ideaFrom(pick.bookId, keyIdeas => keyIdeas[pick.round % keyIdeas.length], date);
    if (dailyIdea) this.cache.set(cacheKey, dailyIdea);
    return dailyIdea;
  }

  /** A different book and key idea on every call, for the app's Discover card. Not cached. */
  async getRandomIdea(excludeBookId?: string) {
    const ids = await this.getCandidateBookIds();
    const candidates = ids.length > 1 ? ids.filter(id => id !== excludeBookId) : ids;
    // A book can lack key ideas; try a few before giving up
    for (let attempt = 0; attempt < 3 && candidates.length > 0; attempt++) {
      const bookId = candidates[Math.floor(Math.random() * candidates.length)];
      const idea = await this.ideaFrom(
        bookId,
        keyIdeas => keyIdeas[Math.floor(Math.random() * keyIdeas.length)],
        new Date().toISOString().slice(0, 10)
      );
      if (idea) return idea;
    }
    return null;
  }

  private async ideaFrom(bookId: string, chooseIdea: (keyIdeas: unknown[]) => unknown, date: string) {
    const [bookResult, summaryResult] = await Promise.all([
      supabase.from('books').select('*').eq('id', bookId).single(),
      supabase
        .from('summaries')
        .select('one_sentence_hook, key_ideas')
        .eq('book_id', bookId)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()
    ]);

    if (bookResult.error) {
      throw new Error(`Failed to fetch daily idea book: ${bookResult.error.message}`);
    }
    if (summaryResult.error) {
      throw new Error(`Failed to fetch daily idea summary: ${summaryResult.error.message}`);
    }

    const keyIdeas = summaryResult.data?.key_ideas;
    if (!Array.isArray(keyIdeas) || keyIdeas.length === 0) return null;

    return {
      date,
      book: bookResult.data,
      idea: chooseIdea(keyIdeas),
      hook: summaryResult.data?.one_sentence_hook ?? null
    };
  }
}
