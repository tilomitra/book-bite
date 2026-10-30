import { jitterByRank, seededRandom } from '../utils/shuffle';

describe('jitterByRank', () => {
  const ranked = Array.from({ length: 500 }, (_, i) => i);

  test('the same seed gives the same order, so paging through one feed is stable', () => {
    expect(jitterByRank(ranked, seededRandom(42))).toEqual(jitterByRank(ranked, seededRandom(42)));
  });

  test('different seeds give different orders with the same items', () => {
    const a = jitterByRank(ranked, seededRandom(1));
    const b = jitterByRank(ranked, seededRandom(2));
    expect(a).not.toEqual(b);
    expect([...a].sort((x, y) => x - y)).toEqual(ranked);
  });

  test('top-ranked items still come first on average', () => {
    const mean = (items: number[]) => items.reduce((sum, x) => sum + x, 0) / items.length;
    for (const seed of [3, 4, 5]) {
      const firstPage = jitterByRank(ranked, seededRandom(seed)).slice(0, 24);
      expect(mean(firstPage)).toBeLessThan(100);
    }
  });

  test('seededRandom stays in [0, 1)', () => {
    const random = seededRandom(7);
    for (let i = 0; i < 1000; i++) {
      const x = random();
      expect(x).toBeGreaterThanOrEqual(0);
      expect(x).toBeLessThan(1);
    }
  });
});
