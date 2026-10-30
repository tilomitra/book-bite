/**
 * Shared by add-curated-books.ts and weekly-books.ts: look a book up on Open Library (Google Books
 * fills gaps), build its `books` row, check for duplicates and generate its summaries.
 */

export interface CuratedBook {
  title: string;
  author: string;
  category: string;
}

export interface OpenLibraryDoc {
  key: string;
  title: string;
  subtitle?: string;
  author_name?: string[];
  first_publish_year?: number;
  isbn?: string[];
  cover_i?: number;
  publisher?: string[];
  ratings_average?: number;
  ratings_count?: number;
  readinglog_count?: number;
  subject?: string[];
  language?: string[];
}

export const OPEN_LIBRARY = 'https://openlibrary.org';
export async function getJson(url: string, params: Record<string, string | number> = {}): Promise<any> {
  const query = new URLSearchParams(Object.entries(params).map(([k, v]) => [k, String(v)] as [string, string])).toString();
  const response = await fetch(query ? `${url}?${query}` : url, {
    headers: { 'User-Agent': 'BookBite/1.0 (book import script)' },
    signal: AbortSignal.timeout(30000)
  });
  if (!response.ok) throw new Error(`GET ${url} failed with status ${response.status}`);
  return response.json();
}

// Lowercase, drop accents, a leading "The" and the subtitle, so "Deep Work: Rules for..." matches "Deep Work".
export function normalizeTitle(title: string): string {
  return title
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .split(/[:(]|\. /)[0]
    .replace(/&/g, 'and')
    .replace(/[^a-z0-9 ]/g, '')
    .replace(/^the /, '')
    .replace(/\s+/g, ' ')
    .trim();
}

export function lastName(author: string): string {
  const parts = author.replace(/\./g, ' ').trim().split(/\s+/);
  const last = parts[parts.length - 1];
  return /^(jr|sr|ii|iii)$/i.test(last) && parts.length > 1 ? parts[parts.length - 2] : last;
}

export async function withRetry<T>(fn: () => Promise<T>, attempts = 3): Promise<T> {
  for (let i = 1; ; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i >= attempts) throw error;
      await new Promise(resolve => setTimeout(resolve, 2000 * i));
    }
  }
}

// English editions have ISBN-13 prefixes 978-0 and 978-1.
function pickIsbns(isbns: string[] = []): { isbn13: string | null; isbn10: string | null } {
  const isbn13 = isbns.find(i => /^97[89][01]\d{9}$/.test(i)) || isbns.find(i => /^97[89]\d{10}$/.test(i)) || null;
  const isbn10 = isbns.find(i => /^[01]\d{8}[\dX]$/.test(i)) || null;
  return { isbn13, isbn10 };
}

export function normalizeName(name: string): string {
  return name.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
}

export function authorMatches(names: string[] = [], author: string): boolean {
  const wanted = normalizeName(lastName(author));
  return names.some(name => normalizeName(name).includes(wanted));
}

export const OPEN_LIBRARY_FIELDS =
  'key,title,subtitle,author_name,first_publish_year,isbn,cover_i,publisher,ratings_average,ratings_count,readinglog_count,subject,language';

export async function findOnOpenLibrary(book: CuratedBook): Promise<OpenLibraryDoc | null> {
  const wantedTitle = normalizeTitle(book.title);
  // The title/author search is strict, so fall back to a free-text search.
  const searches: Record<string, string>[] = [
    { title: book.title, author: book.author },
    { q: `${book.title.split(':')[0]} ${lastName(book.author)}` }
  ];
  for (const params of searches) {
    const data = await withRetry(() =>
      getJson(`${OPEN_LIBRARY}/search.json`, { ...params, limit: 10, fields: OPEN_LIBRARY_FIELDS })
    );
    const matches = ((data.docs || []) as OpenLibraryDoc[]).filter(
      d => normalizeTitle(d.title) === wantedTitle && authorMatches(d.author_name, book.author)
    );
    // Prefer the work with the most readers (the main work, not an obscure edition or study guide), then a cover.
    matches.sort(
      (a, b) => (b.readinglog_count || 0) - (a.readinglog_count || 0) || Number(!!b.cover_i) - Number(!!a.cover_i)
    );
    if (matches[0]) return matches[0];
  }
  return null;
}

async function openLibraryDescription(workKey: string): Promise<string | null> {
  try {
    const data = await withRetry(() => getJson(`${OPEN_LIBRARY}${workKey}.json`));
    const description = typeof data.description === 'string' ? data.description : data.description?.value;
    // Strip Open Library's trailing source notes and markdown links.
    return description
      ? description.split(/\n-{3,}|\(\[source\]/i)[0].replace(/\[([^\]]+)\]\([^)]+\)/g, '$1').trim()
      : null;
  } catch {
    return null;
  }
}

async function findOnGoogleBooks(book: CuratedBook): Promise<any | null> {
  if (!process.env.GOOGLE_BOOKS_API_KEY) return null;
  try {
    const data = await getJson('https://www.googleapis.com/books/v1/volumes', {
      q: `intitle:"${book.title.split(':')[0]}" inauthor:${lastName(book.author)}`,
      maxResults: 10,
      key: process.env.GOOGLE_BOOKS_API_KEY
    });
    const matches = (data.items || []).filter(
      (i: any) =>
        normalizeTitle(i.volumeInfo?.title || '') === normalizeTitle(book.title) &&
        authorMatches(i.volumeInfo?.authors, book.author)
    );
    matches.sort(
      (a: any, b: any) =>
        Number(!!b.volumeInfo.description) - Number(!!a.volumeInfo.description) ||
        Number(!!b.volumeInfo.imageLinks) - Number(!!a.volumeInfo.imageLinks) ||
        (b.volumeInfo.ratingsCount || 0) - (a.volumeInfo.ratingsCount || 0)
    );
    return matches[0] || null;
  } catch {
    return null;
  }
}

function googleCoverUrl(volume: any): string | null {
  if (!volume?.volumeInfo?.imageLinks) return null;
  return `https://books.google.com/books/content?id=${volume.id}&printsec=frontcover&img=1&zoom=1&source=gbs_api`;
}

/** `found` skips the Open Library search when the caller already looked the work up (null: not on Open Library). */
export async function buildBookRow(book: CuratedBook, found?: OpenLibraryDoc | null) {
  const doc = found === undefined ? await findOnOpenLibrary(book) : found;
  // Google Books fills gaps: books Open Library does not have, and missing descriptions.
  const description = doc ? await openLibraryDescription(doc.key) : null;
  const google = !doc || !description ? await findOnGoogleBooks(book) : null;
  if (!doc && !google) return null;

  const info = google?.volumeInfo || {};
  const googleIsbn = (type: string) =>
    info.industryIdentifiers?.find((i: any) => i.type === type)?.identifier || null;
  const isbns = doc ? pickIsbns(doc.isbn) : { isbn13: googleIsbn('ISBN_13'), isbn10: googleIsbn('ISBN_10') };
  const averageRating = Math.round((doc?.ratings_average || info.averageRating || 0) * 100) / 100;
  const ratingsCount = doc?.ratings_count || info.ratingsCount || 0;
  const sources = [doc && 'Open Library', google && 'Google Books'].filter(Boolean) as string[];

  return {
    title: book.title,
    subtitle: doc?.subtitle || info.subtitle || null,
    authors: [book.author],
    isbn10: isbns.isbn10,
    isbn13: isbns.isbn13,
    published_year: doc?.first_publish_year || parseInt(info.publishedDate, 10) || null,
    publisher: doc?.publisher?.[0] || info.publisher || null,
    categories: [book.category],
    cover_url: doc?.cover_i ? `https://covers.openlibrary.org/b/id/${doc.cover_i}-L.jpg` : googleCoverUrl(google),
    description: description || info.description || null,
    source_attribution: sources,
    open_library_id: doc ? doc.key.replace('/works/', '') : null,
    google_books_id: google?.id || null,
    average_rating: averageRating,
    ratings_count: ratingsCount,
    // Open Library reader count, the same scale update-reader-counts.ts uses for every book.
    popularity_score: doc?.readinglog_count || 0
  };
}

export function bookKey(title: string, author: string): string {
  return `${normalizeTitle(title)}|${normalizeName(lastName(author))}`;
}

export async function loadExistingKeys(supabase: any): Promise<Set<string>> {
  const keys = new Set<string>();
  const pageSize = 1000;
  for (let from = 0; ; from += pageSize) {
    const { data, error } = await supabase
      .from('books')
      .select('title, authors')
      .range(from, from + pageSize - 1);
    if (error) throw new Error(`Failed to load existing books: ${error.message}`);
    for (const row of data || []) {
      for (const author of row.authors || []) {
        keys.add(bookKey(row.title, author));
      }
    }
    if (!data || data.length < pageSize) break;
  }
  return keys;
}

export async function generateSummaries(supabase: any, openai: any, book: any): Promise<void> {
  const summary = await openai.generateBookSummary(
    book.title,
    book.authors,
    book.description || '',
    book.categories,
    'full'
  );
  const { data: saved, error } = await supabase
    .from('summaries')
    .insert({ book_id: book.id, ...summary })
    .select('id')
    .single();
  if (error) throw new Error(`Summary insert failed: ${error.message}`);

  const extended = await openai.generateExtendedSummary(
    book.title,
    book.authors,
    book.description || '',
    book.categories,
    { subtitle: book.subtitle, hook: summary.one_sentence_hook, keyIdeas: summary.key_ideas?.map((k: any) => k.idea) }
  );
  const { error: extendedError } = await supabase
    .from('summaries')
    .update({ extended_summary: extended })
    .eq('id', saved.id);
  if (extendedError) throw new Error(`Extended summary update failed: ${extendedError.message}`);
}
