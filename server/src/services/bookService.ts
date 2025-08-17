import { supabase } from '../config/supabase';
import { GoogleBooksService } from './googleBooksService';
import { Book } from '../models/types';
import NodeCache from 'node-cache';

export class BookService {
  private googleBooks: GoogleBooksService;
  private cache: NodeCache;

  constructor() {
    this.googleBooks = new GoogleBooksService();
    // Cache for 15 minutes
    this.cache = new NodeCache({ stdTTL: 900, checkperiod: 120 });
  }

  async getAllBooks(options: { 
    page?: number; 
    limit?: number; 
    search?: string 
  }) {
    const { page = 1, limit = 20, search } = options;
    const offset = (page - 1) * limit;

    let query = supabase
      .from('books')
      .select('*', { count: 'exact' });

    if (search) {
      const searchTerm = `%${search.trim()}%`;
      query = query.or(`title.ilike.${searchTerm},subtitle.ilike.${searchTerm}`);
    }

    const { data, error, count } = await query
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      throw new Error(`Failed to fetch books: ${error.message}`);
    }

    return {
      books: data || [],
      total: count || 0,
      page,
      limit,
      totalPages: Math.ceil((count || 0) / limit)
    };
  }

  async getFeaturedBooks(options: { 
    page?: number; 
    limit?: number;
    fresh?: boolean;
  } = {}) {
    const { page = 1, limit = 100, fresh = false } = options;
    const offset = (page - 1) * limit;

    // Check cache first (unless fresh fetch is requested)
    const cacheKey = `featured-books:${page}:${limit}`;
    if (!fresh) {
      const cached = this.cache.get(cacheKey);
      if (cached) return cached;
    }

    const { data, error, count } = await supabase
      .from('books')
      .select('*', { count: 'exact' })
      .eq('is_featured', true)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      throw new Error(`Failed to fetch featured books: ${error.message}`);
    }

    const result = {
      books: data || [],
      total: count || 0,
      page,
      limit,
      totalPages: Math.ceil((count || 0) / limit)
    };

    // Cache for 30 minutes since featured books don't change often
    this.cache.set(cacheKey, result, 1800);

    return result;
  }

  async getNYTBestsellerBooks(options: { 
    page?: number; 
    limit?: number;
    fresh?: boolean;
  } = {}) {
    const { page = 1, limit = 100, fresh = false } = options;
    const offset = (page - 1) * limit;

    // Check cache first (unless fresh fetch is requested)
    const cacheKey = `nyt-bestsellers:${page}:${limit}`;
    if (!fresh) {
      const cached = this.cache.get(cacheKey);
      if (cached) return cached;
    }

    const { data, error, count } = await supabase
      .from('books')
      .select('*', { count: 'exact' })
      .eq('is_nyt_bestseller', true)
      .order('nyt_rank', { ascending: true })
      .range(offset, offset + limit - 1);

    if (error) {
      throw new Error(`Failed to fetch NYT bestsellers: ${error.message}`);
    }

    const result = {
      books: data || [],
      total: count || 0,
      page,
      limit,
      totalPages: Math.ceil((count || 0) / limit)
    };

    // Cache for 30 minutes since NYT bestsellers don't change often
    this.cache.set(cacheKey, result, 1800);

    return result;
  }

  async getBookById(id: string): Promise<Book | null> {
    // Check cache first
    const cacheKey = `book:${id}`;
    const cached = this.cache.get<Book>(cacheKey);
    if (cached) return cached;

    const { data, error } = await supabase
      .from('books')
      .select('*')
      .eq('id', id)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return null; // Not found
      }
      throw new Error(`Failed to fetch book: ${error.message}`);
    }

    // Cache the result
    if (data) {
      this.cache.set(cacheKey, data);
    }

    return data;
  }

  async searchBooks(query: string, source: string = 'all'): Promise<Book[]> {
    const results: Book[] = [];

    // Search local database
    if (source === 'all' || source === 'local') {
      const searchTerm = `%${query.trim()}%`;
      const { data: localBooks } = await supabase
        .from('books')
        .select('*')
        .or(`title.ilike.${searchTerm},subtitle.ilike.${searchTerm},description.ilike.${searchTerm}`)
        .limit(10);

      if (localBooks) {
        results.push(...localBooks);
      }
    }

    // Search Google Books
    if (source === 'all' || source === 'google') {
      try {
        const googleResults = await this.googleBooks.searchBooks(query, 10);
        
        // Filter out books we already have
        const existingISBNs = results.map(b => b.isbn13).filter(Boolean);
        const newBooks = googleResults.filter(
          book => !book.isbn13 || !existingISBNs.includes(book.isbn13)
        );

        // Convert partial books to full books for consistency
        const fullBooks = newBooks.map(book => ({
          ...book,
          id: book.google_books_id || '',
          authors: book.authors || [],
          categories: book.categories || []
        } as Book));

        results.push(...fullBooks);
      } catch (error) {
        console.error('Google Books search failed:', error);
      }
    }

    return results;
  }

  async createBook(bookData: Partial<Book>): Promise<Book> {
    const { data, error } = await supabase
      .from('books')
      .insert(bookData)
      .select()
      .single();

    if (error) {
      throw new Error(`Failed to create book: ${error.message}`);
    }

    // Invalidate cache
    this.cache.flushAll();

    return data;
  }

  async updateBook(id: string, bookData: Partial<Book>): Promise<Book | null> {
    const { data, error } = await supabase
      .from('books')
      .update(bookData)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return null;
      }
      throw new Error(`Failed to update book: ${error.message}`);
    }

    // Invalidate cache
    this.cache.del(`book:${id}`);

    return data;
  }

  async deleteBook(id: string): Promise<boolean> {
    const { error } = await supabase
      .from('books')
      .delete()
      .eq('id', id);

    if (error) {
      if (error.code === 'PGRST116') {
        return false;
      }
      throw new Error(`Failed to delete book: ${error.message}`);
    }

    // Invalidate cache
    this.cache.del(`book:${id}`);

    return true;
  }

  async importBookFromISBN(isbn: string): Promise<Book | null> {
    // Check if we already have this book
    const { data: existingBook } = await supabase
      .from('books')
      .select('*')
      .or(`isbn10.eq.${isbn},isbn13.eq.${isbn}`)
      .single();

    if (existingBook) {
      return existingBook;
    }

    // Fetch from Google Books
    const googleBook = await this.googleBooks.getBookByISBN(isbn);
    
    if (!googleBook) {
      return null;
    }

    // Save to database
    const bookToCreate = {
      ...googleBook,
      authors: googleBook.authors || [],
      categories: googleBook.categories || []
    };

    return this.createBook(bookToCreate);
  }

  async importBookFromGoogleId(googleBooksId: string): Promise<Book | null> {
    // Check if we already have this book
    const { data: existingBook } = await supabase
      .from('books')
      .select('*')
      .eq('google_books_id', googleBooksId)
      .single();

    if (existingBook) {
      return existingBook;
    }

    // Fetch from Google Books
    const googleBook = await this.googleBooks.getBookById(googleBooksId);
    
    if (!googleBook) {
      return null;
    }

    // Save to database
    const bookToCreate = {
      ...googleBook,
      authors: googleBook.authors || [],
      categories: googleBook.categories || []
    };

    return this.createBook(bookToCreate);
  }
}