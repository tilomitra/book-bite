import axios from 'axios';
import { BookRating } from '../models/types';

const OPEN_LIBRARY_BASE = 'https://openlibrary.org';

interface OpenLibraryRatingResponse {
  summary: {
    average: number;
    count: number;
  };
  counts: {
    '1': number;
    '2': number;
    '3': number;
    '4': number;
    '5': number;
  };
}

interface OpenLibraryWorkResponse {
  key: string;
  title: string;
  authors?: Array<{ key: string }>;
}

interface OpenLibrarySearchResponse {
  docs: Array<{
    key: string;
    isbn?: string[];
    title: string;
  }>;
}

export class OpenLibraryService {
  private cache = new Map<string, { data: BookRating; timestamp: number }>();
  private readonly CACHE_TTL = 1000 * 60 * 60; // 1 hour

  async getRatingsByISBN(isbn: string): Promise<BookRating | null> {
    try {
      // Check cache first
      const cached = this.cache.get(isbn);
      if (cached && Date.now() - cached.timestamp < this.CACHE_TTL) {
        return cached.data;
      }

      // Find work ID by ISBN
      const workId = await this.findWorkIdByISBN(isbn);
      if (!workId) {
        return null;
      }

      // Get ratings for the work
      const rating = await this.getRatingsByWorkId(workId);
      
      // Cache the result
      if (rating) {
        this.cache.set(isbn, { data: rating, timestamp: Date.now() });
      }

      return rating;
    } catch (error) {
      console.error('Error fetching Open Library ratings:', error);
      return null;
    }
  }

  async getRatingsByWorkId(workId: string): Promise<BookRating | null> {
    try {
      const cleanWorkId = workId.replace('/works/', '');
      const response = await axios.get(`${OPEN_LIBRARY_BASE}/works/${cleanWorkId}/ratings.json`, {
        timeout: 5000,
        headers: {
          'User-Agent': 'BookBite-App/1.0 (contact@bookbite.app)'
        }
      });

      const data = response.data as OpenLibraryRatingResponse;
      
      if (!data.summary || data.summary.count === 0) {
        return null;
      }

      return {
        average: Math.round(data.summary.average * 10) / 10, // Round to 1 decimal
        count: data.summary.count,
        distribution: {
          '1': data.counts?.['1'] || 0,
          '2': data.counts?.['2'] || 0,
          '3': data.counts?.['3'] || 0,
          '4': data.counts?.['4'] || 0,
          '5': data.counts?.['5'] || 0
        },
        source: 'Open Library'
      };
    } catch (error) {
      if (axios.isAxiosError(error) && error.response?.status === 404) {
        // No ratings available for this work
        return null;
      }
      console.error('Error fetching ratings from Open Library:', error);
      return null;
    }
  }

  private async findWorkIdByISBN(isbn: string): Promise<string | null> {
    try {
      // Search for the book by ISBN
      const response = await axios.get(`${OPEN_LIBRARY_BASE}/search.json`, {
        params: {
          isbn: isbn,
          limit: 1
        },
        timeout: 5000,
        headers: {
          'User-Agent': 'BookBite-App/1.0 (contact@bookbite.app)'
        }
      });

      const data = response.data as OpenLibrarySearchResponse;
      
      if (data.docs && data.docs.length > 0) {
        const book = data.docs[0];
        // Convert edition key to work key if needed
        if (book.key.startsWith('/works/')) {
          return book.key;
        }
        
        // If we have an edition key, we need to get the work ID
        if (book.key.startsWith('/books/')) {
          const editionResponse = await axios.get(`${OPEN_LIBRARY_BASE}${book.key}.json`, {
            timeout: 5000,
            headers: {
              'User-Agent': 'BookBite-App/1.0 (contact@bookbite.app)'
            }
          });
          
          const edition = editionResponse.data;
          if (edition.works && edition.works.length > 0) {
            return edition.works[0].key;
          }
        }
      }

      return null;
    } catch (error) {
      console.error('Error finding work ID by ISBN:', error);
      return null;
    }
  }

  // Method to get ratings by Google Books ID (if available)
  async getRatingsByGoogleBooksId(googleBooksId: string): Promise<BookRating | null> {
    try {
      // Search by Google Books ID in Open Library
      const response = await axios.get(`${OPEN_LIBRARY_BASE}/search.json`, {
        params: {
          q: `source_records:google:${googleBooksId}`,
          limit: 1
        },
        timeout: 5000,
        headers: {
          'User-Agent': 'BookBite-App/1.0 (contact@bookbite.app)'
        }
      });

      const data = response.data as OpenLibrarySearchResponse;
      
      if (data.docs && data.docs.length > 0) {
        const workKey = data.docs[0].key;
        if (workKey) {
          return await this.getRatingsByWorkId(workKey);
        }
      }

      return null;
    } catch (error) {
      console.error('Error fetching ratings by Google Books ID:', error);
      return null;
    }
  }

  // Clear cache (useful for testing)
  clearCache(): void {
    this.cache.clear();
  }
}