import axios from 'axios';
import { Book } from '../models/types';

const GOOGLE_BOOKS_API_BASE = 'https://www.googleapis.com/books/v1';

interface GoogleBookVolume {
  id: string;
  volumeInfo: {
    title: string;
    subtitle?: string;
    authors?: string[];
    publisher?: string;
    publishedDate?: string;
    description?: string;
    industryIdentifiers?: Array<{
      type: string;
      identifier: string;
    }>;
    categories?: string[];
    imageLinks?: {
      thumbnail?: string;
      smallThumbnail?: string;
      medium?: string;
      large?: string;
    };
  };
}

export class GoogleBooksService {
  private apiKey: string;

  constructor() {
    if (!process.env.GOOGLE_BOOKS_API_KEY) {
      throw new Error('Google Books API key not configured');
    }
    this.apiKey = process.env.GOOGLE_BOOKS_API_KEY;
  }

  async searchBooks(query: string, maxResults: number = 10): Promise<GoogleBookVolume[]> {
    try {
      const response = await axios.get(`${GOOGLE_BOOKS_API_BASE}/volumes`, {
        params: {
          q: query,
          maxResults,
          key: this.apiKey
        }
      });

      if (!response.data.items) {
        return [];
      }

      return response.data.items;
    } catch (error) {
      console.error('Error searching Google Books:', error);
      throw new Error('Failed to search books from Google Books API');
    }
  }

  // For compatibility with existing controllers that expect Book objects
  async searchBooksAsBooks(query: string, maxResults: number = 10): Promise<Partial<Book>[]> {
    try {
      const volumes = await this.searchBooks(query, maxResults);
      return volumes.map((item: GoogleBookVolume) => 
        this.transformGoogleBookToBook(item)
      );
    } catch (error) {
      console.error('Error searching Google Books:', error);
      throw new Error('Failed to search books from Google Books API');
    }
  }

  async getBookByISBN(isbn: string): Promise<Partial<Book> | null> {
    try {
      const response = await axios.get(`${GOOGLE_BOOKS_API_BASE}/volumes`, {
        params: {
          q: `isbn:${isbn}`,
          key: this.apiKey
        }
      });

      if (!response.data.items || response.data.items.length === 0) {
        return null;
      }

      return this.transformGoogleBookToBook(response.data.items[0]);
    } catch (error) {
      console.error('Error fetching book by ISBN:', error);
      return null;
    }
  }

  async getBookById(googleBooksId: string): Promise<Partial<Book> | null> {
    try {
      const response = await axios.get(
        `${GOOGLE_BOOKS_API_BASE}/volumes/${googleBooksId}`,
        {
          params: { key: this.apiKey }
        }
      );

      return this.transformGoogleBookToBook(response.data);
    } catch (error) {
      console.error('Error fetching book by ID:', error);
      return null;
    }
  }

  // Alias for backward compatibility
  async searchByISBN(isbn: string): Promise<GoogleBookVolume | null> {
    try {
      const response = await axios.get(`${GOOGLE_BOOKS_API_BASE}/volumes`, {
        params: {
          q: `isbn:${isbn}`,
          key: this.apiKey
        }
      });

      if (!response.data.items || response.data.items.length === 0) {
        return null;
      }

      return response.data.items[0];
    } catch (error) {
      console.error('Error searching book by ISBN:', error);
      return null;
    }
  }

  // Public method to extract book data from Google Books volume
  async extractBookData(googleBook: GoogleBookVolume): Promise<any> {
    const volumeInfo = googleBook.volumeInfo;
    
    // Extract ISBNs
    let isbn10: string | undefined;
    let isbn13: string | undefined;
    
    if (volumeInfo.industryIdentifiers) {
      const isbn10Obj = volumeInfo.industryIdentifiers.find(
        id => id.type === 'ISBN_10'
      );
      const isbn13Obj = volumeInfo.industryIdentifiers.find(
        id => id.type === 'ISBN_13'
      );
      
      isbn10 = isbn10Obj?.identifier;
      isbn13 = isbn13Obj?.identifier;
    }

    // Extract publication year
    let publishedYear: number | undefined;
    if (volumeInfo.publishedDate) {
      const year = parseInt(volumeInfo.publishedDate.substring(0, 4));
      if (!isNaN(year)) {
        publishedYear = year;
      }
    }

    // Get best available cover image
    const coverUrl = volumeInfo.imageLinks?.large ||
                    volumeInfo.imageLinks?.medium ||
                    volumeInfo.imageLinks?.thumbnail ||
                    volumeInfo.imageLinks?.smallThumbnail;

    return {
      title: volumeInfo.title,
      subtitle: volumeInfo.subtitle || null,
      authors: volumeInfo.authors || [],
      isbn10: isbn10 || null,
      isbn13: isbn13 || null,
      published_year: publishedYear || null,
      publisher: volumeInfo.publisher || null,
      categories: volumeInfo.categories || [],
      cover_url: coverUrl || null,
      description: volumeInfo.description || null,
      google_books_id: googleBook.id,
      source_attribution: ['Google Books API']
    };
  }

  private transformGoogleBookToBook(googleBook: GoogleBookVolume): Partial<Book> {
    const volumeInfo = googleBook.volumeInfo;
    
    // Extract ISBNs
    let isbn10: string | undefined;
    let isbn13: string | undefined;
    
    if (volumeInfo.industryIdentifiers) {
      const isbn10Obj = volumeInfo.industryIdentifiers.find(
        id => id.type === 'ISBN_10'
      );
      const isbn13Obj = volumeInfo.industryIdentifiers.find(
        id => id.type === 'ISBN_13'
      );
      
      isbn10 = isbn10Obj?.identifier;
      isbn13 = isbn13Obj?.identifier;
    }

    // Extract publication year
    let publishedYear: number | undefined;
    if (volumeInfo.publishedDate) {
      const year = parseInt(volumeInfo.publishedDate.substring(0, 4));
      if (!isNaN(year)) {
        publishedYear = year;
      }
    }

    // Get best available cover image
    const coverUrl = volumeInfo.imageLinks?.large ||
                    volumeInfo.imageLinks?.medium ||
                    volumeInfo.imageLinks?.thumbnail ||
                    volumeInfo.imageLinks?.smallThumbnail;

    return {
      title: volumeInfo.title,
      subtitle: volumeInfo.subtitle || null,
      authors: volumeInfo.authors || [],
      isbn10: isbn10 || null,
      isbn13: isbn13 || null,
      published_year: publishedYear || null,
      publisher: volumeInfo.publisher || null,
      categories: volumeInfo.categories || [],
      cover_url: coverUrl || null,
      description: volumeInfo.description || null,
      google_books_id: googleBook.id,
      source_attribution: ['Google Books API']
    };
  }
}