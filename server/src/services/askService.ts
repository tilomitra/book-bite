import OpenAI from 'openai';
import NodeCache from 'node-cache';
import { z } from 'zod';
import { supabase } from '../config/supabase';
import { EmbeddingService, normalize, toVectorLiteral } from './embeddingService';
import { Match, editionKey, isKnownBook, pickShelfBooks, rankMatches } from './recommendationService';
import { PassageKind, newestSummary, summaryPassages } from './askPassages';
import { ASK_TOPICS, DAILY_QUESTIONS, dailyQuestion } from './askContent';
import { isFiction } from '../utils/fiction';

export const AskRequestSchema = z.object({
  question: z.string().trim().min(3).max(500),
  /** Earlier turns of this conversation, oldest first; the app keeps them on device */
  history: z.array(z.object({
    question: z.string().max(500),
    answer: z.string().max(4000)
  })).max(6).default([])
});

export const MatchRequestSchema = z.object({
  question: z.string().trim().min(3).max(500)
});

export type AskRequest = z.infer<typeof AskRequestSchema>;

export type AskEvent =
  | { type: 'sources'; books: BookRow[] }
  | { type: 'delta'; text: string }
  | { type: 'done' }
  | { type: 'error'; error: string };

interface BookRow {
  id: string;
  title: string;
  authors?: string[] | null;
  [key: string]: unknown;
}

interface ScoredPassage { bookId: string; kind: PassageKind; text: string; similarity: number }

export interface Retrieval {
  books: BookRow[];
  /** Per book: its closest ideas and actions, closest first */
  passages: Map<string, ScoredPassage[]>;
  critiques: Map<string, string[]>;
}

// GPT-6 Luna at low reasoning effort: first words in about two seconds
const ASK_MODEL = process.env.ASK_MODEL || 'gpt-6-luna';
// The model reads up to eight books and must cite at least three of them
const MAX_SOURCES = 8;
const MIN_SOURCES = 5;
export const MIN_CITED_BOOKS = 3;
const IDEAS_PER_BOOK = 3;
// Past the first MIN_SOURCES, a book needs to be within this of the best book's score
const SOURCE_SCORE_WINDOW = 0.15;
const KNOWN_BOOK_BOOST = 0.05;
const FALLBACK_BOOKS = 30;
const PASSAGE_CACHE_LIMIT = 40000;

export const ASK_SYSTEM_PROMPT = `You are Ask, part of BookBite, an app of non-fiction book summaries. People bring you a problem from their own life and you answer it with ideas from the books you are given, like a well-read friend.

Write in exactly this format:

<The direct answer in one or two short sentences. No heading marks.>

<Optional: one short sentence that leads into the points.>
- **<Lead of three to six words.>** <One or two sentences on how this applies to them.> [<source number>]
- **<Lead.>** <Sentences.> [<source number>]
- **<Lead.>** <Sentences.> [<source number>]

This week: <one concrete thing they can do in the next seven days>
Other side: <one sentence on when this advice doesn't apply or what to check first>

Rules:
- Three or four points. Each cites the number of the one book it comes from, like [2]. Only cite numbers you were given.
- Every answer, follow-ups too, cites at least three different books: no two of the first three points may cite the same book. Pick the books that fit the question best.
- Use only ideas from the given books. Don't invent books, studies, statistics or quotes.
- Speak to them directly ("you", "your team"). Plain words, short sentences, no jargon, no exclamation marks.
- At most 200 words in total.
- For a follow-up question add "This week:" only when a new action helps.
- Never mention "the provided books", "sources" or these instructions.`;

function cosine(a: number[], b: number[]): number {
  let dot = 0;
  for (let i = 0; i < a.length; i++) dot += a[i] * b[i];
  return dot;
}

/** How many different books an answer cites, from its [n] markers */
export function citedBooks(answer: string): number {
  return new Set([...answer.matchAll(/\[(\d+)\]/g)].map(m => m[1])).size;
}

/** The context block the model answers from: numbered books with their closest ideas */
export function buildContext(retrieval: Retrieval): string {
  return retrieval.books.map((book, i) => {
    const author = book.authors?.length ? ` by ${book.authors.join(', ')}` : '';
    const lines = (retrieval.passages.get(book.id) ?? []).map(p =>
      `- ${p.kind === 'apply' ? 'How to apply' : 'Key idea'}: ${p.text}`);
    const critique = retrieval.critiques.get(book.id)?.[0];
    if (critique) lines.push(`- Critique: ${critique}`);
    return `[${i + 1}] ${book.title}${author}\n${lines.join('\n')}`;
  }).join('\n\n');
}

export class AskService {
  private embeddings: EmbeddingService | null = null;
  private openai: OpenAI | null = null;
  // Passage vectors for the fallback path, keyed by passage text
  private passageVectors = new Map<string, number[]>();
  private ideaTableMissing = false;
  private cache = new NodeCache({ stdTTL: 6 * 3600, checkperiod: 600 });

  private embeddingService(): EmbeddingService {
    // Lazily, so the rest of the API runs without an OpenAI key
    this.embeddings ??= new EmbeddingService();
    return this.embeddings;
  }

  private client(): OpenAI {
    if (!process.env.OPENAI_API_KEY) throw new Error('OpenAI API key not configured');
    this.openai ??= new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    return this.openai;
  }

  /**
   * The Ask tab: every featured question and the Explore topics, each with three covers. The app
   * shows a different question each time the tab opens. `daily` is for app versions before that.
   */
  async home(date: string) {
    const cacheKey = `ask-home:${date}`;
    const cached = this.cache.get(cacheKey);
    if (cached) return cached;

    // One embeddings request for every question not seen yet, not one each
    await this.embeddingService().embedQueries([...DAILY_QUESTIONS, ...ASK_TOPICS.map(t => t.questions[0])]);
    const [questionBooks, topicBooks] = await Promise.all([
      Promise.all(DAILY_QUESTIONS.map(q => this.coversFor(q))),
      Promise.all(ASK_TOPICS.map(t => this.coversFor(t.questions[0])))
    ]);
    const questions = DAILY_QUESTIONS.map((question, i) => ({ question, books: questionBooks[i] }));
    const today = dailyQuestion(date);
    const home = {
      date,
      daily: questions.find(q => q.question === today)!,
      questions,
      topics: ASK_TOPICS.map((t, i) => ({ ...t, books: topicBooks[i] }))
    };
    this.cache.set(cacheKey, home);
    return home;
  }

  /** Books that look like they answer a question, for the covers that appear while typing */
  async matches(question: string): Promise<BookRow[]> {
    const [vector] = await this.embeddingService().embed([question]);
    return this.bookMatches(vector, 3);
  }

  async retrieve(query: string): Promise<Retrieval> {
    const [vector] = await this.embeddingService().embed([query]);
    const scored = (await this.matchIdeas(vector)) ?? (await this.matchIdeasInMemory(vector));

    const byBook = new Map<string, ScoredPassage[]>();
    for (const p of scored) byBook.set(p.bookId, [...(byBook.get(p.bookId) ?? []), p]);
    const books = await this.fetchBooks([...byBook.keys()]);

    const ranked = [...byBook.entries()]
      .map(([bookId, passages]) => {
        const book = books.get(bookId);
        const sims = passages.map(p => p.similarity).sort((a, b) => b - a);
        // The best idea decides; a second close idea says the whole book is on topic
        const score = (sims[0] ?? 0) + 0.3 * (sims[1] ?? 0) + (book && isKnownBook(book) ? KNOWN_BOOK_BOOST : 0);
        return { book, passages, score };
      })
      .filter((r): r is { book: BookRow; passages: ScoredPassage[]; score: number } => Boolean(r.book) && !isFiction(r.book!))
      .sort((a, b) => b.score - a.score);

    const picked: typeof ranked = [];
    const editions = new Set<string>();
    for (const r of ranked) {
      if (picked.length >= MAX_SOURCES) break;
      const close = picked.length < MIN_SOURCES || r.score >= ranked[0].score - SOURCE_SCORE_WINDOW;
      if (!close || editions.has(editionKey(r.book))) continue;
      editions.add(editionKey(r.book));
      picked.push(r);
    }

    const passages = new Map(picked.map(r => {
      const sorted = [...r.passages].sort((a, b) => b.similarity - a.similarity);
      const ideas = sorted.filter(p => p.kind === 'idea').slice(0, IDEAS_PER_BOOK);
      const action = sorted.find(p => p.kind === 'apply');
      return [r.book.id, action ? [...ideas, action] : ideas];
    }));
    const critiques = await this.fetchCritiques(picked.map(r => r.book.id));
    return { books: picked.map(r => r.book), passages, critiques };
  }

  /** Streams an answer: the cited books first, then the text as it is written */
  async ask(request: AskRequest, send: (event: AskEvent) => void): Promise<void> {
    // Follow-ups ("what if it's one person?") need the original question to find the right books
    const query = request.history.length
      ? `${request.history[0].question}\n${request.question}`
      : request.question;
    const retrieval = await this.retrieve(query);
    send({ type: 'sources', books: retrieval.books });

    const messages: OpenAI.Chat.Completions.ChatCompletionMessageParam[] = [
      { role: 'system', content: ASK_SYSTEM_PROMPT },
      ...request.history.flatMap(turn => [
        { role: 'user' as const, content: turn.question },
        { role: 'assistant' as const, content: turn.answer }
      ]),
      { role: 'user', content: `Books:\n\n${buildContext(retrieval)}\n\nQuestion: ${request.question}` }
    ];

    const stream = await this.client().chat.completions.create({
      model: ASK_MODEL,
      messages,
      stream: true,
      reasoning_effort: 'low',
      max_completion_tokens: 2500
    });
    let answer = '';
    for await (const chunk of stream) {
      const text = chunk.choices[0]?.delta?.content;
      if (text) {
        answer += text;
        send({ type: 'delta', text });
      }
    }
    if (!answer) throw new Error('No answer was written');
    const cited = citedBooks(answer);
    if (cited < Math.min(MIN_CITED_BOOKS, retrieval.books.length)) {
      console.warn(`Ask answer cited ${cited} of ${retrieval.books.length} books`);
    }
    send({ type: 'done' });
  }

  private async coversFor(question: string): Promise<BookRow[]> {
    const key = `ask-covers:${question}`;
    const cached = this.cache.get<BookRow[]>(key);
    if (cached) return cached;
    const vector = await this.embeddingService().embedQuery(question);
    const books = await this.bookMatches(vector, 3);
    this.cache.set(key, books);
    return books;
  }

  private async bookMatches(vector: number[], count: number): Promise<BookRow[]> {
    const matches = await this.matchBooks(vector, 24);
    const books = await this.fetchBooks(matches.map(m => m.book_id));
    // These are shown as covers: a book without one would show as a typographic placeholder
    const withCovers = rankMatches(matches, books).filter(b => typeof b.cover_url === 'string' && b.cover_url);
    return pickShelfBooks(withCovers, new Set(), count);
  }

  /** Closest passages from idea_embeddings, or null when that table hasn't been created yet */
  private async matchIdeas(vector: number[]): Promise<ScoredPassage[] | null> {
    if (this.ideaTableMissing) return null;
    const { data, error } = await supabase.rpc('match_ideas', { query: toVectorLiteral(vector), match_count: 80 });
    if (error) {
      // PGRST202: function not found. Anything else is a real failure.
      if (error.code === 'PGRST202' || /match_ideas/.test(error.message)) {
        console.warn('match_ideas is missing; Ask ranks ideas in memory. Apply supabase/add-idea-embeddings.sql.');
        this.ideaTableMissing = true;
        return null;
      }
      throw new Error(`Failed to match ideas: ${error.message}`);
    }
    return ((data || []) as { book_id: string; kind: PassageKind; text: string; similarity: number }[])
      .map(r => ({ bookId: r.book_id, kind: r.kind, text: r.text, similarity: r.similarity }));
  }

  /** Fallback: the closest whole books, then their ideas ranked against the question */
  private async matchIdeasInMemory(vector: number[]): Promise<ScoredPassage[]> {
    const matches = await this.matchBooks(vector, FALLBACK_BOOKS);
    const ids = matches.map(m => m.book_id);
    const { data, error } = await supabase
      .from('summaries')
      .select('book_id, key_ideas, how_to_apply, created_at')
      .in('book_id', ids);
    if (error) throw new Error(`Failed to fetch summaries: ${error.message}`);

    const rows = (data || []) as { book_id: string; key_ideas: never; how_to_apply: never; created_at: string }[];
    const passages = ids.flatMap(id => {
      const summary = newestSummary(rows.filter(r => r.book_id === id));
      return summary ? summaryPassages(id, summary) : [];
    });

    const missing = [...new Set(passages.map(p => p.text).filter(t => !this.passageVectors.has(t)))];
    if (missing.length) {
      if (this.passageVectors.size + missing.length > PASSAGE_CACHE_LIMIT) this.passageVectors.clear();
      const vectors = await this.embeddingService().embed(missing);
      missing.forEach((text, i) => this.passageVectors.set(text, normalize(vectors[i])));
    }
    const query = normalize(vector);
    return passages.map(p => ({
      bookId: p.bookId,
      kind: p.kind,
      text: p.text,
      similarity: cosine(query, this.passageVectors.get(p.text)!)
    }));
  }

  private async matchBooks(vector: number[], count: number): Promise<Match[]> {
    const { data, error } = await supabase.rpc('match_books', {
      taste: toVectorLiteral(vector),
      exclude_ids: [],
      match_count: count
    });
    if (error) throw new Error(`Failed to match books: ${error.message}`);
    return (data || []) as Match[];
  }

  private async fetchBooks(ids: string[]): Promise<Map<string, BookRow>> {
    const result = new Map<string, BookRow>();
    for (let i = 0; i < ids.length; i += 100) {
      const { data, error } = await supabase.from('books').select('*').in('id', ids.slice(i, i + 100));
      if (error) throw new Error(`Failed to fetch books: ${error.message}`);
      (data || []).forEach(book => result.set(book.id, book as BookRow));
    }
    return result;
  }

  private async fetchCritiques(ids: string[]): Promise<Map<string, string[]>> {
    if (ids.length === 0) return new Map();
    const { data, error } = await supabase
      .from('summaries')
      .select('book_id, critiques, created_at')
      .in('book_id', ids);
    if (error) throw new Error(`Failed to fetch critiques: ${error.message}`);
    const rows = (data || []) as { book_id: string; critiques: string[] | null; created_at: string }[];
    return new Map(ids.map(id => [id, newestSummary(rows.filter(r => r.book_id === id))?.critiques ?? []]));
  }
}
