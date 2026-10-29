import { isbn13To10, purchaseUrl, isPurchaseStore } from '../services/purchaseLinks';

const atomicHabits = { title: 'Atomic Habits', authors: ['James Clear'], isbn10: null, isbn13: '9780735211292' };
const noIsbn = { title: 'Some Book', authors: ['A. Writer'], isbn10: null, isbn13: null };

describe('purchase links', () => {
  it('converts 978 ISBN-13 to ISBN-10', () => {
    expect(isbn13To10('9780735211292')).toBe('0735211299');
    expect(isbn13To10('9780306406157')).toBe('0306406152');
    expect(isbn13To10('9791234567896')).toBeUndefined();
  });

  it('builds Amazon product links with the associate tag', () => {
    expect(purchaseUrl(atomicHabits, 'amazon', { amazonTag: 'bookbite-20' }))
      .toBe('https://www.amazon.com/dp/0735211299?tag=bookbite-20');
    expect(purchaseUrl(atomicHabits, 'amazon', {})).toBe('https://www.amazon.com/dp/0735211299');
  });

  it('falls back to a book search without an ISBN', () => {
    const url = new URL(purchaseUrl(noIsbn, 'amazon', { amazonTag: 'bookbite-20' }));
    expect(url.pathname).toBe('/s');
    expect(url.searchParams.get('k')).toBe('Some Book A. Writer');
    expect(url.searchParams.get('i')).toBe('stripbooks');
    expect(url.searchParams.get('tag')).toBe('bookbite-20');
  });

  it('builds Bookshop.org affiliate links', () => {
    expect(purchaseUrl(atomicHabits, 'bookshop', { bookshopId: '123' })).toBe('https://bookshop.org/a/123/9780735211292');
    expect(purchaseUrl(atomicHabits, 'bookshop', {})).toBe('https://bookshop.org/book/9780735211292');
  });

  it('validates stores', () => {
    expect(isPurchaseStore('amazon')).toBe(true);
    expect(isPurchaseStore('ebay')).toBe(false);
  });
});
