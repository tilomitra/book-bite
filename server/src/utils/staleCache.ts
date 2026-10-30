/**
 * One expensive value (a full table scan, a batch of embeddings) kept in memory. Once it has loaded,
 * readers never wait: after `ttlMs` they still get the old value at once while one refresh runs behind it.
 */
export class StaleCache<T> {
  private value: T | undefined;
  private loadedAt = 0;
  private loading: Promise<T> | undefined;

  constructor(private load: () => Promise<T>, private ttlMs: number) {}

  async get(): Promise<T> {
    if (this.value === undefined) return this.refresh();
    if (Date.now() - this.loadedAt > this.ttlMs) {
      this.refresh().catch(error => console.error('Cache refresh failed:', error));
    }
    return this.value;
  }

  /** The next read refreshes, without making anyone wait */
  invalidate() {
    this.loadedAt = 0;
  }

  private refresh(): Promise<T> {
    this.loading ??= this.load()
      .then(value => {
        this.value = value;
        this.loadedAt = Date.now();
        return value;
      })
      .finally(() => {
        this.loading = undefined;
      });
    return this.loading;
  }
}
