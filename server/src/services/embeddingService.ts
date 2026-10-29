import OpenAI from 'openai';
import crypto from 'crypto';

export const EMBEDDING_MODEL = 'text-embedding-3-small';
export const EMBEDDING_DIMENSIONS = 1536;

// Embedding requests take up to 2048 inputs; smaller batches keep a failure cheap to retry
const BATCH_SIZE = 100;
// ~8k tokens is the model limit; descriptions and summaries are far shorter, this is a safety cap
const MAX_TEXT_CHARS = 12000;

export interface EmbeddableBook {
  title: string;
  subtitle?: string | null;
  authors?: string[] | null;
  categories?: string[] | null;
  description?: string | null;
  summary?: {
    one_sentence_hook?: string | null;
    key_ideas?: { idea: string }[] | null;
    who_should_read?: string | null;
  } | null;
}

/** The text a book is embedded from: what it is about, not how it is written. */
export function bookEmbeddingText(book: EmbeddableBook): string {
  const parts = [
    `${book.title}${book.subtitle ? `: ${book.subtitle}` : ''}`,
    book.authors?.length ? `By ${book.authors.join(', ')}` : '',
    book.categories?.length ? `Topics: ${book.categories.join(', ')}` : '',
    book.summary?.one_sentence_hook ?? '',
    book.summary?.key_ideas?.length
      ? `Key ideas: ${book.summary.key_ideas.map(k => k.idea).join(' ')}`
      : '',
    book.summary?.who_should_read ? `For: ${book.summary.who_should_read}` : '',
    book.description ?? ''
  ];
  return parts.filter(Boolean).join('\n').slice(0, MAX_TEXT_CHARS);
}

export function contentHash(text: string): string {
  return crypto.createHash('sha256').update(`${EMBEDDING_MODEL}\n${text}`).digest('hex');
}

/** pgvector columns come back from PostgREST as a string like "[0.1,0.2,...]" */
export function parseVector(value: unknown): number[] {
  if (Array.isArray(value)) return value as number[];
  if (typeof value === 'string') return JSON.parse(value) as number[];
  throw new Error('Unexpected vector format');
}

export function toVectorLiteral(vector: number[]): string {
  return `[${vector.join(',')}]`;
}

export function normalize(vector: number[]): number[] {
  const norm = Math.sqrt(vector.reduce((sum, x) => sum + x * x, 0));
  return norm === 0 ? vector : vector.map(x => x / norm);
}

/** Normalized weighted sum of normalized vectors; null when there is nothing to combine. */
export function blend(parts: { vector: number[]; weight: number }[]): number[] | null {
  const used = parts.filter(p => p.weight > 0 && p.vector.length > 0);
  if (used.length === 0) return null;
  const sum = new Array(used[0].vector.length).fill(0);
  for (const { vector, weight } of used) {
    const unit = normalize(vector);
    for (let i = 0; i < sum.length; i++) sum[i] += unit[i] * weight;
  }
  return normalize(sum);
}

export class EmbeddingService {
  private client: OpenAI;
  // Query texts (goals, topics) are a small fixed set: embed each once per process
  private queryCache = new Map<string, Promise<number[]>>();

  constructor() {
    if (!process.env.OPENAI_API_KEY) {
      throw new Error('OpenAI API key not configured');
    }
    this.client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  }

  async embed(texts: string[]): Promise<number[][]> {
    const vectors: number[][] = [];
    for (let i = 0; i < texts.length; i += BATCH_SIZE) {
      const batch = texts.slice(i, i + BATCH_SIZE).map(t => t.slice(0, MAX_TEXT_CHARS));
      const response = await this.client.embeddings.create({ model: EMBEDDING_MODEL, input: batch });
      // Responses carry an index per input; don't rely on ordering
      const ordered = [...response.data].sort((a, b) => a.index - b.index);
      vectors.push(...ordered.map(d => d.embedding));
    }
    return vectors;
  }

  /** Embeds the texts not cached yet in one request and caches them for `embedQuery` */
  async embedQueries(texts: string[]): Promise<void> {
    const missing = [...new Set(texts)].filter(t => !this.queryCache.has(t));
    if (missing.length === 0) return;
    const pending = this.embed(missing);
    missing.forEach((text, i) => {
      const vector = pending.then(vectors => vectors[i]);
      vector.catch(() => this.queryCache.delete(text));
      this.queryCache.set(text, vector);
    });
    await pending;
  }

  embedQuery(text: string): Promise<number[]> {
    let pending = this.queryCache.get(text);
    if (!pending) {
      pending = this.embed([text]).then(([vector]) => vector);
      // A failed request shouldn't stay cached
      pending.catch(() => this.queryCache.delete(text));
      this.queryCache.set(text, pending);
    }
    return pending;
  }
}
