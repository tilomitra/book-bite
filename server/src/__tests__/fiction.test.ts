import { isFiction, isFictionCategories, isNonFiction } from '../utils/fiction';

describe('isFictionCategories', () => {
  test.each([
    [['Fiction']],
    [['Juvenile Fiction']],
    [['Fiction / General', 'Fiction / Romance / Contemporary']],
    [['Travel', 'Fiction']], // genre mapping added a non-fiction genre to a novel
    [['Health', 'Juvenile Fiction']],
    [['Religion', 'Drama']],
    [['Science Fiction']]
  ])('%j is fiction', categories => {
    expect(isFictionCategories(categories)).toBe(true);
  });

  test.each([
    [['Nonfiction', 'Psychology']],
    [['Juvenile Nonfiction']],
    [['Young Adult Non-fiction']],
    [['Literary Criticism']],
    [['Self-Help', 'Personal Development']],
    [[]],
    [null],
    // Google tags some non-fiction "Fiction / General"; a detailed non-fiction subject wins
    [['Biography & Autobiography / Survival', 'Fiction / General']],
    [['Business & Economics / Personal Finance / General', 'Fiction / General']],
    // An explicit "Nonfiction" category wins over a stray fiction-like genre
    [['Comics & Graphic Novels', 'Nonfiction', 'Psychology']]
  ])('%j is non-fiction', categories => {
    expect(isFictionCategories(categories)).toBe(false);
  });
});

describe('isFiction', () => {
  test('hand-checked exceptions beat categories', () => {
    expect(isFiction({ title: 'The Prince', authors: ['Niccolo Machiavelli'], categories: ['Fiction'] })).toBe(false);
    expect(isFiction({ title: 'Rising Sun', authors: ['Michael Crichton'], categories: ['Fiction', 'Nonfiction'] })).toBe(true);
    expect(isFiction({ title: 'Siddhartha', authors: ['Hermann Hesse'], categories: ['Philosophy'] })).toBe(true);
  });

  test('uses categories otherwise', () => {
    expect(isFiction({ title: 'The Hobbit, Or, There and Back Again', authors: ['J. R. R. Tolkien'], categories: ['Juvenile Fiction'] })).toBe(true);
    expect(isNonFiction({ title: 'Atomic Habits', authors: ['James Clear'], categories: ['Self-Help'] })).toBe(true);
    expect(isNonFiction({ title: 'Untitled' })).toBe(true);
  });
});
