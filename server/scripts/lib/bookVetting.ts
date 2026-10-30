/**
 * Shared by weekly-books.ts (which new books to add) and clean-catalog.ts (which books to remove):
 * the cheap title check and the model's 1–5 rating of a book's fit for the catalogue.
 */

import OpenAI from 'openai';
import { withRetry } from './bookImport';

export const VET_MODEL = 'gpt-6-luna';

// Genres the app already uses (categories in curated-books.json), so new books join existing shelves.
export const GENRES = [
  'Psychology', 'Self-Help', 'Business', 'Economics', 'Finance', 'History', 'Science', 'Technology',
  'Biography', 'Health', 'Philosophy', 'Society', 'Parenting', 'Relationships', 'Productivity',
  'Leadership', 'Career', 'Marketing', 'Writing', 'Spirituality', 'Mindfulness', 'Travel'
];

// Not books to summarize: companions to other books, journals, textbooks, bundles.
export const JUNK_TITLE =
  /\b(workbook|summary|study guide|analysis of|journal|planner|notebook|colou?ring|box(ed)? set|collection|textbook|for dummies|cookbook|recipes|calendar|activity book|edition|volume|vol\.|book \d|part \d)\b/i;

/** Books rated this or higher belong in the catalogue */
export const KEEP_SCORE = 4;

export interface RatingInput {
  title: string;
  author: string;
  year?: number | null;
  /** Short extra context, e.g. "NYT bestseller" or "48 readers" */
  note?: string;
}

export interface Rating {
  score: number;
  genre?: string;
  reason?: string;
}

const BATCH_SIZE = 30;

function prompt(list: string): string {
  return `BookBite is an app with summaries of non-fiction books: key ideas, how to apply them, and answers to readers' problems drawn from ideas across the catalogue. Rate each book below for the catalogue.

5 = a widely recommended non-fiction book with clear ideas readers can learn from or apply (e.g. Thinking, Fast and Slow; Educated; The Psychology of Money)
4 = a well-reviewed non-fiction book from a known author or publisher, worth a summary
3 = real but minor, niche or dated
2 = not a good fit: textbook, reference work, academic monograph, conference proceedings, anthology, poetry, a companion to another book, a primary religious text, a political tract or a celebrity book without ideas
1 = fiction, a children's book, a summary/workbook of another book, self-published filler, or unknown to you

Rules: rate 1 if you are not sure the book exists as described. Pick the genre from: ${GENRES.join(', ')}.

Books:
${list}

Reply with JSON: {"books": [{"n": 1, "score": 5, "genre": "Psychology", "reason": "max 12 words"}]}, one entry per book.`;
}

/**
 * Rates books in batches. The result lines up with the input; a book the model skipped, or a batch
 * that failed, is undefined (callers treat that as unknown, not as a low score).
 */
export async function rateBooks(
  books: RatingInput[],
  onProgress?: (done: number, total: number) => void
): Promise<(Rating | undefined)[]> {
  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  const ratings: (Rating | undefined)[] = new Array(books.length).fill(undefined);
  for (let i = 0; i < books.length; i += BATCH_SIZE) {
    const batch = books.slice(i, i + BATCH_SIZE);
    const list = batch
      .map((b, n) => `${n + 1}. "${b.title}" by ${b.author}${b.year ? ` (${b.year})` : ''}${b.note ? ` [${b.note}]` : ''}`)
      .join('\n');
    try {
      const response = await withRetry(() =>
        openai.chat.completions.create({
          model: VET_MODEL,
          max_completion_tokens: 8000,
          response_format: { type: 'json_object' },
          messages: [{ role: 'user', content: prompt(list) }]
        })
      );
      const parsed = JSON.parse(response.choices[0].message.content || '{}');
      for (const r of parsed.books || []) {
        const n = Number(r.n) - 1;
        if (n < 0 || n >= batch.length) continue;
        ratings[i + n] = {
          score: Number(r.score) || 0,
          genre: GENRES.includes(r.genre) ? r.genre : undefined,
          reason: typeof r.reason === 'string' ? r.reason : undefined
        };
      }
    } catch (error) {
      console.log(`   Rating batch failed: ${error instanceof Error ? error.message : error}`);
    }
    onProgress?.(Math.min(i + BATCH_SIZE, books.length), books.length);
  }
  return ratings;
}
