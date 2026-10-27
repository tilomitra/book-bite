/**
 * BookBite is a non-fiction ideas app: novels, poetry and plays have no "key ideas" to apply, so
 * they stay out of the idea of the day, Discover and recommendations, and importers skip them.
 *
 * Categories are messy. Google Books tags some non-fiction "Fiction / General" (Into Thin Air,
 * Die with Zero) and our genre mapping adds a non-fiction genre to real novels ("Travel" +
 * "Fiction" for Lord Jim). So a book is fiction when a category says fiction and nothing
 * reliable says otherwise. Reliable non-fiction signals are an explicit "Nonfiction" category
 * and detailed BISAC subjects ("Biography & Autobiography / Survival") outside fiction.
 */

// "Fiction", "Juvenile Fiction", "Fiction / Romance / Contemporary", but not "Nonfiction"
const FICTION_WORD = /(^|[^a-z-])fiction\b/i;
const NONFICTION_WORD = /\bnon-?fiction\b/i;
const FICTION_GENRES = new Set(['poetry', 'drama', 'comics & graphic novels']);
// Top levels of detailed BISAC subjects that are fiction (or may be)
const FICTION_BISAC_TOP = /^(fiction|juvenile fiction|young adult fiction|comics & graphic novels|poetry|drama|literary collections)\b/i;

/** Known miscategorized books: normalized "title|author surname" → is fiction */
const OVERRIDES: Record<string, boolean> = {
  'the prince|machiavelli': false, // tagged "Fiction"
  'rising sun|crichton': true, // tagged both "Fiction" and "Nonfiction"
  'siddhartha|hesse': true // tagged only "Philosophy"
};

export interface CategorizedBook {
  title?: string | null;
  authors?: string[] | null;
  categories?: string[] | null;
}

function overrideKey(book: CategorizedBook): string | null {
  const title = book.title?.split(/[:(]/)[0].trim().toLowerCase();
  const author = book.authors?.[0]?.trim().split(/\s+/).pop()?.toLowerCase();
  return title && author ? `${title}|${author}` : null;
}

/** True when the categories mark a book as fiction (novels, children's fiction, poetry, plays) */
export function isFictionCategories(categories: string[] | null | undefined): boolean {
  const cats = (categories ?? []).map(c => c.trim()).filter(Boolean);
  const saysFiction = cats.some(c =>
    (FICTION_WORD.test(c) && !NONFICTION_WORD.test(c)) || FICTION_GENRES.has(c.toLowerCase())
  );
  if (!saysFiction) return false;
  const saysNonfiction = cats.some(c =>
    NONFICTION_WORD.test(c) || (c.includes(' / ') && !FICTION_BISAC_TOP.test(c))
  );
  return !saysNonfiction;
}

/** The shared non-fiction rule: categories plus a few hand-checked exceptions */
export function isFiction(book: CategorizedBook): boolean {
  const key = overrideKey(book);
  if (key && key in OVERRIDES) return OVERRIDES[key];
  return isFictionCategories(book.categories);
}

export function isNonFiction(book: CategorizedBook): boolean {
  return !isFiction(book);
}
