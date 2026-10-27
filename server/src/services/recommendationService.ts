import { z } from 'zod';
import { supabase } from '../config/supabase';
import { EmbeddingService, blend, parseVector, toVectorLiteral } from './embeddingService';
import { isFiction } from '../utils/fiction';

/**
 * Reading goals offered in onboarding. The app sends ids; only the server knows the text that
 * gets embedded, so clients can't make us embed arbitrary input.
 */
export const READING_GOALS: Record<string, { shelfTitle: string; text: string }> = {
  money: { shelfTitle: 'Better with money', text: 'Personal finance, investing, building wealth and making smart decisions about money' },
  habits: { shelfTitle: 'Better habits', text: 'Habits, productivity, discipline, focus and getting important things done' },
  work: { shelfTitle: 'Leading at work', text: 'Leadership, management, careers, negotiation and doing great work with other people' },
  mind: { shelfTitle: 'How people think', text: 'Psychology, human behavior, decision making and cognitive biases' },
  health: { shelfTitle: 'Healthier living', text: 'Health, fitness, sleep, nutrition, longevity and feeling good in your body' },
  relationships: { shelfTitle: 'Better relationships', text: 'Relationships, communication, empathy, love, parenting and friendship' },
  meaning: { shelfTitle: 'Calm and meaning', text: 'Mindfulness, stoicism, philosophy, happiness and finding meaning in life' },
  world: { shelfTitle: 'How the world works', text: 'History, science, society, economics and politics: how the world works and how it got here' },
  creativity: { shelfTitle: 'Creative work', text: 'Creativity, art, writing, design and making creative work' },
  startup: { shelfTitle: 'Starting something', text: 'Entrepreneurship, startups, innovation and building a business or product' }
};

/** Discover shelf names the app sends as topics (`OnboardingPreferences.topics`) */
export const TOPIC_GENRES = [
  'Business', 'Psychology', 'Self-Help', 'Health', 'History', 'Personal Development', 'Biography',
  'Philosophy', 'Economics', 'Technology', 'Politics', 'Education', 'Arts & Culture', 'Nature & Environment'
];

export const RecommendationRequestSchema = z.object({
  /** Books the user said they read or loved during onboarding */
  likedBookIds: z.array(z.string().uuid()).max(30).default([]),
  /** Books the user opened, newest first */
  recentBookIds: z.array(z.string().uuid()).max(30).default([]),
  goals: z.array(z.string()).max(10).default([]),
  genres: z.array(z.string()).max(20).default([])
});

export type RecommendationRequest = z.infer<typeof RecommendationRequestSchema>;

// How much each signal pulls the taste vector. What someone did beats what they said, and a
// liked book says more than a topic name.
const WEIGHT_LIKED = 1.0;
const WEIGHT_RECENT = 0.7;
const RECENT_DECAY = 0.85; // per position in the recent list
const WEIGHT_GOAL = 0.8;
const WEIGHT_GENRE = 0.4;

const SCORE_COUNT = 400; // books returned with a similarity score, used to reorder genre shelves
const SHELF_SIZE = 16;
const SHELF_PREVIEW = 12; // books visible on a Discover shelf; later shelves avoid repeating these
const MAX_PER_AUTHOR = 2;
const MAX_SEED_SHELVES = 2;
// Added to similarity on shelves for books with any sign of being known (featured, NYT, a
// popularity rank, or at least KNOWN_BOOK_READERS Open Library readers in popularity_score). The catalog has many obscure self-published titles that match a
// topic closely; ~0.05 moves a known book from about the 48th closest to about the 16th.
const KNOWN_BOOK_BOOST = 0.05;
const KNOWN_BOOK_READERS = 100;
const MAX_GOAL_SHELVES = 2;

export interface Match { book_id: string; similarity: number }
interface BookRow {
  id: string;
  title: string;
  authors?: string[] | null;
  is_featured?: boolean | null;
  is_nyt_bestseller?: boolean | null;
  popularity_score?: number | null;
  popularity_rank?: number | null;
  [key: string]: unknown;
}

export function isKnownBook(book: BookRow): boolean {
  return Boolean(book.is_featured || book.is_nyt_bestseller)
    || (book.popularity_score ?? 0) >= KNOWN_BOOK_READERS
    || book.popularity_rank != null;
}

/** Matches as books (non-fiction only), closest first after the boost for known books. */
export function rankMatches(matches: Match[], books: Map<string, BookRow>): BookRow[] {
  return matches
    .map(m => ({ book: books.get(m.book_id), score: m.similarity }))
    .filter((r): r is { book: BookRow; score: number } => Boolean(r.book) && !isFiction(r.book!))
    .map(r => ({ ...r, score: r.score + (isKnownBook(r.book) ? KNOWN_BOOK_BOOST : 0) }))
    .sort((a, b) => b.score - a.score)
    .map(r => r.book);
}

export interface Shelf {
  id: string;
  kind: 'for-you' | 'more-like' | 'goal';
  title: string;
  books: BookRow[];
}

/** Same main title and first author: other editions of one book share it */
export function editionKey(book: BookRow): string {
  const author = book.authors?.[0]?.toLowerCase() ?? '';
  return `${book.title.split(/[:(,]/)[0].trim().toLowerCase()}|${author}`;
}

/**
 * Keeps order, skips books in `exclude` (ids or edition keys), other editions of a picked book (same main title and
 * author, e.g. "Predictably Irrational, Revised and Expanded Edition"), and limits how many
 * books one author gets.
 */
export function pickShelfBooks(ranked: BookRow[], exclude: Set<string>, size = SHELF_SIZE): BookRow[] {
  const perAuthor = new Map<string, number>();
  const editions = new Set<string>();
  const picked: BookRow[] = [];
  for (const book of ranked) {
    if (picked.length >= size) break;
    const author = book.authors?.[0]?.toLowerCase() ?? '';
    const edition = editionKey(book);
    if (exclude.has(book.id) || exclude.has(edition) || editions.has(edition)) continue;
    const count = perAuthor.get(author) ?? 0;
    if (author && count >= MAX_PER_AUTHOR) continue;
    perAuthor.set(author, count + 1);
    editions.add(edition);
    picked.push(book);
  }
  return picked;
}

export class RecommendationService {
  private embeddings: EmbeddingService | null = null;

  private embeddingService(): EmbeddingService {
    // Lazily, so the rest of the API runs without an OpenAI key
    this.embeddings ??= new EmbeddingService();
    return this.embeddings;
  }

  async getRecommendations(request: RecommendationRequest) {
    const goals = [...new Set(request.goals)].filter(id => READING_GOALS[id]);
    const genres = [...new Set(request.genres)].filter(g => TOPIC_GENRES.includes(g));
    const liked = [...new Set(request.likedBookIds)];
    const recent = [...new Set(request.recentBookIds)].filter(id => !liked.includes(id));

    const [seedVectors, goalVectors, genreVectors] = await Promise.all([
      this.fetchBookVectors([...liked, ...recent]),
      Promise.all(goals.map(id => this.embeddingService().embedQuery(READING_GOALS[id].text))),
      Promise.all(genres.map(g => this.embeddingService().embedQuery(`Non-fiction books about ${g}`)))
    ]);

    const taste = blend([
      ...liked.map(id => ({ vector: seedVectors.get(id) ?? [], weight: WEIGHT_LIKED })),
      ...recent.map((id, i) => ({ vector: seedVectors.get(id) ?? [], weight: WEIGHT_RECENT * RECENT_DECAY ** i })),
      ...goalVectors.map(vector => ({ vector, weight: WEIGHT_GOAL })),
      ...genreVectors.map(vector => ({ vector, weight: WEIGHT_GENRE }))
    ]);
    if (!taste) return { shelves: [] as Shelf[], scores: {} as Record<string, number> };

    // Books they already know aren't recommendations
    const known = [...liked, ...recent];

    // Seeds for "More like …": the newest opened books, then liked ones, that have an embedding
    const seeds = [...recent, ...liked].filter(id => seedVectors.has(id)).slice(0, MAX_SEED_SHELVES);
    const goalQueries = goals.slice(0, MAX_GOAL_SHELVES).map((id, i) => ({
      id,
      // Mostly the goal, a little of the person's taste so two people with the same goal differ
      vector: blend([{ vector: goalVectors[i], weight: 1 }, { vector: taste, weight: 0.3 }])!
    }));

    const [tasteMatches, seedMatches, goalMatches] = await Promise.all([
      this.match(taste, known, SCORE_COUNT),
      Promise.all(seeds.map(id => this.match(seedVectors.get(id)!, known, SHELF_SIZE * 3))),
      Promise.all(goalQueries.map(q => this.match(q.vector, known, SHELF_SIZE * 3)))
    ]);

    const neededIds = new Set<string>([
      ...tasteMatches.slice(0, SHELF_SIZE * 3).map(m => m.book_id),
      ...seedMatches.flat().map(m => m.book_id),
      ...goalMatches.flat().map(m => m.book_id),
      ...seeds
    ]);
    const books = await this.fetchBooks([...neededIds]);
    const ranked = (matches: Match[]) => rankMatches(matches, books);

    const shelves: Shelf[] = [];
    const shown = new Set<string>();
    const addShelf = (shelf: Shelf) => {
      if (shelf.books.length < 4) return;
      shelves.push(shelf);
      shelf.books.slice(0, SHELF_PREVIEW).forEach(b => shown.add(b.id).add(editionKey(b)));
    };

    addShelf({ id: 'for-you', kind: 'for-you', title: 'For you', books: pickShelfBooks(ranked(tasteMatches), shown) });
    seeds.forEach((seedId, i) => {
      const seed = books.get(seedId);
      if (!seed) return;
      addShelf({
        id: `more-like-${seedId}`,
        kind: 'more-like',
        // Main title only: subtitles make shelf headers wrap
        title: `More like ${seed.title.split(/[:(]| - /)[0].trim()}`,
        books: pickShelfBooks(ranked(seedMatches[i]), shown)
      });
    });
    goalQueries.forEach((goal, i) => {
      addShelf({
        id: `goal-${goal.id}`,
        kind: 'goal',
        title: READING_GOALS[goal.id].shelfTitle,
        books: pickShelfBooks(ranked(goalMatches[i]), shown)
      });
    });

    const scores = Object.fromEntries(tasteMatches.map(m => [m.book_id, Number(m.similarity.toFixed(4))]));
    return { shelves, scores };
  }

  private async fetchBookVectors(ids: string[]): Promise<Map<string, number[]>> {
    if (ids.length === 0) return new Map();
    const { data, error } = await supabase
      .from('book_embeddings')
      .select('book_id, embedding')
      .in('book_id', ids);
    if (error) throw new Error(`Failed to fetch book embeddings: ${error.message}`);
    return new Map((data || []).map(row => [row.book_id as string, parseVector(row.embedding)]));
  }

  private async match(vector: number[], excludeIds: string[], count: number): Promise<Match[]> {
    const { data, error } = await supabase.rpc('match_books', {
      taste: toVectorLiteral(vector),
      exclude_ids: excludeIds,
      match_count: count
    });
    if (error) throw new Error(`Failed to match books: ${error.message}`);
    return (data || []) as Match[];
  }

  private async fetchBooks(ids: string[]): Promise<Map<string, BookRow>> {
    const result = new Map<string, BookRow>();
    // Long `in` filters go in the URL; keep each request well under URL limits
    for (let i = 0; i < ids.length; i += 100) {
      const { data, error } = await supabase.from('books').select('*').in('id', ids.slice(i, i + 100));
      if (error) throw new Error(`Failed to fetch books: ${error.message}`);
      (data || []).forEach(book => result.set(book.id, book as BookRow));
    }
    return result;
  }
}
