import { Book } from '../models/types';

// "Get the full book" links. The app always opens /api/books/:id/buy?store=…, and the server
// redirects to the store, so affiliate ids can be added (or stores swapped) without an app update.
// Without an id set, the links are plain store links.
//   AMAZON_ASSOCIATE_TAG    Amazon Associates tracking id, e.g. bookbite-20
//   BOOKSHOP_AFFILIATE_ID   Bookshop.org affiliate id (numeric)

export const PURCHASE_STORES = ['amazon', 'bookshop'] as const;
export type PurchaseStore = (typeof PURCHASE_STORES)[number];

export function isPurchaseStore(value: unknown): value is PurchaseStore {
  return typeof value === 'string' && (PURCHASE_STORES as readonly string[]).includes(value);
}

type BookIdentity = Pick<Book, 'title' | 'authors' | 'isbn10' | 'isbn13'>;

interface AffiliateIds {
  amazonTag?: string;
  bookshopId?: string;
}

function affiliateIdsFromEnv(): AffiliateIds {
  return {
    amazonTag: process.env.AMAZON_ASSOCIATE_TAG?.trim() || undefined,
    bookshopId: process.env.BOOKSHOP_AFFILIATE_ID?.trim() || undefined,
  };
}

function cleanIsbn(isbn: string | null | undefined): string | undefined {
  const digits = isbn?.replace(/[^0-9Xx]/g, '').toUpperCase();
  return digits && (digits.length === 10 || digits.length === 13) ? digits : undefined;
}

/** ISBN-13 (978 prefix only) → ISBN-10, which Amazon uses as the product id for print books */
export function isbn13To10(isbn13: string): string | undefined {
  if (!/^978\d{10}$/.test(isbn13)) return undefined;
  const core = isbn13.slice(3, 12);
  const sum = core.split('').reduce((acc, d, i) => acc + Number(d) * (10 - i), 0);
  const check = (11 - (sum % 11)) % 11;
  return core + (check === 10 ? 'X' : String(check));
}

function searchQuery(book: BookIdentity): string {
  const author = book.authors?.[0];
  return author ? `${book.title} ${author}` : book.title;
}

export function purchaseUrl(
  book: BookIdentity,
  store: PurchaseStore,
  ids: AffiliateIds = affiliateIdsFromEnv()
): string {
  const isbn13 = cleanIsbn(book.isbn13);
  const isbn10 = cleanIsbn(book.isbn10) ?? (isbn13 ? isbn13To10(isbn13) : undefined);

  switch (store) {
    case 'amazon': {
      const url = isbn10
        ? new URL(`https://www.amazon.com/dp/${isbn10}`)
        : new URL('https://www.amazon.com/s');
      if (!isbn10) {
        url.searchParams.set('k', searchQuery(book));
        url.searchParams.set('i', 'stripbooks');
      }
      if (ids.amazonTag) url.searchParams.set('tag', ids.amazonTag);
      return url.toString();
    }
    case 'bookshop': {
      if (isbn13) {
        return ids.bookshopId
          ? `https://bookshop.org/a/${encodeURIComponent(ids.bookshopId)}/${isbn13}`
          : `https://bookshop.org/book/${isbn13}`;
      }
      const url = new URL('https://bookshop.org/search');
      url.searchParams.set('keywords', searchQuery(book));
      if (ids.bookshopId) url.searchParams.set('aid', ids.bookshopId);
      return url.toString();
    }
  }
}
