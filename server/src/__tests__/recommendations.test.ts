import { blend, bookEmbeddingText, normalize } from '../services/embeddingService';
import { pickShelfBooks, rankMatches, RecommendationRequestSchema } from '../services/recommendationService';

describe('blend', () => {
  test('returns null with no usable vectors', () => {
    expect(blend([])).toBeNull();
    expect(blend([{ vector: [1, 0], weight: 0 }])).toBeNull();
  });

  test('weights pull the result toward heavier vectors and the result is unit length', () => {
    const result = blend([
      { vector: [1, 0], weight: 3 },
      { vector: [0, 5], weight: 1 } // normalized first, so its length doesn't count
    ])!;
    expect(result[0]).toBeGreaterThan(result[1]);
    expect(Math.hypot(...result)).toBeCloseTo(1);
  });

  test('normalize leaves a zero vector alone', () => {
    expect(normalize([0, 0])).toEqual([0, 0]);
  });
});

describe('pickShelfBooks', () => {
  const book = (id: string, author: string) => ({ id, title: id, authors: [author] });

  test('keeps order, skips excluded books and caps books per author', () => {
    const ranked = [book('a', 'X'), book('b', 'X'), book('c', 'X'), book('d', 'Y'), book('e', 'Z')];
    const picked = pickShelfBooks(ranked, new Set(['d']), 10).map(b => b.id);
    expect(picked).toEqual(['a', 'b', 'e']);
  });

  test('skips other editions of a picked book', () => {
    const ranked = [
      { id: 'a', title: 'Predictably Irrational', authors: ['Dan Ariely'] },
      { id: 'b', title: 'Predictably Irrational, Revised and Expanded Edition', authors: ['Dan Ariely'] },
      { id: 'c', title: 'The Upside of Irrationality', authors: ['Dan Ariely'] }
    ];
    expect(pickShelfBooks(ranked, new Set(), 10).map(b => b.id)).toEqual(['a', 'c']);
  });

  test('stops at the shelf size', () => {
    const ranked = ['a', 'b', 'c'].map(id => book(id, id));
    expect(pickShelfBooks(ranked, new Set(), 2)).toHaveLength(2);
  });
});

describe('rankMatches', () => {
  test('lifts known books past slightly closer obscure ones, but not past much closer ones', () => {
    const books = new Map([
      ['obscure', { id: 'obscure', title: 'Habit Blueprint' }],
      ['known', { id: 'known', title: 'The Power of Habit', popularity_rank: 27 }],
      ['exact', { id: 'exact', title: 'Habits', is_featured: false }]
    ]);
    const ranked = rankMatches([
      { book_id: 'exact', similarity: 0.9 },
      { book_id: 'obscure', similarity: 0.72 },
      { book_id: 'known', similarity: 0.7 },
      { book_id: 'missing', similarity: 0.95 }
    ], books).map(b => b.id);
    expect(ranked).toEqual(['exact', 'known', 'obscure']);
  });
});

describe('RecommendationRequestSchema', () => {
  test('defaults missing lists and rejects non-uuid book ids', () => {
    expect(RecommendationRequestSchema.parse({})).toEqual({
      likedBookIds: [], recentBookIds: [], goals: [], genres: []
    });
    expect(() => RecommendationRequestSchema.parse({ likedBookIds: ['nope'] })).toThrow();
  });
});

describe('bookEmbeddingText', () => {
  test('includes the summary and skips missing fields', () => {
    const text = bookEmbeddingText({
      title: 'Atomic Habits',
      authors: ['James Clear'],
      summary: { one_sentence_hook: 'Small habits compound.', key_ideas: [{ idea: 'Make it obvious.' }] }
    });
    expect(text).toBe('Atomic Habits\nBy James Clear\nSmall habits compound.\nKey ideas: Make it obvious.');
  });
});
