/** Small seeded PRNG (mulberry32): the same seed gives the same numbers, in [0, 1) */
export function seededRandom(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * Mixes a ranked list (best first) so it is different for each seed but still leans toward the top:
 * each item's key is log(rank + 10) plus up to `spread` of noise. With spread 1.5 the first book
 * competes with roughly the first 45, and book 100 with books up to about 500.
 */
export function jitterByRank<T>(items: T[], random: () => number, spread = 1.5): T[] {
  return items
    .map((item, rank) => ({ item, key: Math.log(rank + 10) + random() * spread }))
    .sort((a, b) => a.key - b.key)
    .map(entry => entry.item);
}
