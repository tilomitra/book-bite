import { Request, Response, NextFunction } from 'express';
import { GoogleBooksService } from '../services/googleBooksService';
import { BookService } from '../services/bookService';
import { OpenAIService } from '../services/openaiService';
import { supabase } from '../config/supabase';
import { z } from 'zod';

// Validation schemas
const SearchRequestSchema = z.object({
  q: z.string().min(1, 'Search query is required')
});

const BookRequestSchema = z.object({
  googleBooksId: z.string().min(1, 'Google Books ID is required')
});

export class SearchController {
  private googleBooksService: GoogleBooksService;
  private bookService: BookService;
  private openaiService: OpenAIService;

  constructor() {
    this.googleBooksService = new GoogleBooksService();
    this.bookService = new BookService();
    this.openaiService = new OpenAIService();
  }

  /**
   * GET /api/books/search?q={query}
   * Search Google Books API and return formatted results
   */
  async searchGoogleBooks(req: Request, res: Response, next: NextFunction) {
    try {
      const { q } = req.query;
      
      // Validate query parameter
      const validation = SearchRequestSchema.safeParse({ q });
      if (!validation.success) {
        return res.status(400).json({ 
          error: 'Invalid search query',
          details: validation.error.errors
        });
      }

      const query = validation.data.q;
      
      // Search Google Books API
      const searchResults = await this.googleBooksService.searchBooksAsBooks(query, 20);
      
      // Format results for frontend consumption
      const formattedResults = searchResults.map(book => ({
        googleBooksId: book.google_books_id,
        title: book.title,
        subtitle: book.subtitle,
        authors: book.authors || [],
        description: book.description,
        categories: book.categories || [],
        publisher: book.publisher,
        publishedYear: book.published_year,
        isbn10: book.isbn10,
        isbn13: book.isbn13,
        coverUrl: book.cover_url,
        // Include a flag to indicate if this book is already in our database
        inDatabase: false // We'll check this below
      }));

      // Check which books are already in our database
      const existingBookPromises = formattedResults.map(async (result) => {
        if (result.googleBooksId) {
          const { data: existingBooks } = await supabase
            .from('books')
            .select('id, google_books_id')
            .eq('google_books_id', result.googleBooksId);
          
          result.inDatabase = Boolean(existingBooks && existingBooks.length > 0);
        }
        return result;
      });

      const resultsWithStatus = await Promise.all(existingBookPromises);

      return res.json({
        query,
        total: resultsWithStatus.length,
        results: resultsWithStatus
      });
    } catch (error) {
      console.error('Error searching Google Books:', error);
      return next(error);
    }
  }

  /**
   * GET /api/search/book/{googleBooksId}
   * Get existing book from database by Google Books ID
   */
  async getExistingBook(req: Request, res: Response, next: NextFunction) {
    try {
      const { googleBooksId } = req.params;
      
      if (!googleBooksId) {
        return res.status(400).json({
          error: 'Google Books ID is required'
        });
      }

      // Get book with summary from database
      const { data: book, error: bookError } = await supabase
        .from('books')
        .select('*')
        .eq('google_books_id', googleBooksId)
        .single();

      if (bookError || !book) {
        return res.status(404).json({
          error: 'Book not found in database'
        });
      }

      // Get summary for this book
      const { data: summary } = await supabase
        .from('summaries')
        .select('*')
        .eq('book_id', book.id)
        .single();

      const completeBook = {
        ...book,
        summary: summary || null
      };

      return res.json({
        book: completeBook
      });
    } catch (error) {
      console.error('Error getting existing book:', error);
      return next(error);
    }
  }

  /**
   * POST /api/search/request
   * Process a selected book from Google Books and add to database with AI processing
   */
  async requestBook(req: Request, res: Response, next: NextFunction) {
    try {
      // Validate request body
      const validation = BookRequestSchema.safeParse(req.body);
      if (!validation.success) {
        return res.status(400).json({
          error: 'Invalid request data',
          details: validation.error.errors
        });
      }

      const { googleBooksId } = validation.data;

      // Check if book already exists in database
      const { data: existingBooks } = await supabase
        .from('books')
        .select('*')
        .eq('google_books_id', googleBooksId)
        .single();
      
      const existingBook = existingBooks;

      if (existingBook) {
        return res.status(409).json({
          error: 'Book already exists in database',
          book: existingBook
        });
      }

      // Fetch full book data from Google Books
      const googleBook = await this.googleBooksService.getBookById(googleBooksId);
      
      if (!googleBook) {
        return res.status(404).json({
          error: 'Book not found in Google Books API'
        });
      }

      // Prepare book data for database
      const bookToCreate = {
        ...googleBook,
        authors: googleBook.authors || [],
        categories: googleBook.categories || [],
        source_attribution: ['Google Books API', 'User Request']
      };

      // Save book to database
      const savedBook = await this.bookService.createBook(bookToCreate);

      // Generate AI summaries asynchronously
      try {
        // Generate regular summary
        const summaryData = await this.openaiService.generateBookSummary(
          savedBook.title,
          savedBook.authors,
          savedBook.description || '',
          savedBook.categories,
          'full'
        );

        // Generate extended summary
        const extendedSummaryData = await this.openaiService.generateExtendedSummary(
          savedBook.title,
          savedBook.authors,
          savedBook.description || '',
          savedBook.categories
        );

        // Save regular summary to database
        const { data: summary, error: summaryError } = await supabase
          .from('summaries')
          .insert({
            book_id: savedBook.id,
            ...summaryData
          })
          .select()
          .single();

        // Save extended summary to database
        const { data: extendedSummary, error: extendedSummaryError } = await supabase
          .from('extended_summaries')
          .insert({
            book_id: savedBook.id,
            content: extendedSummaryData
          })
          .select()
          .single();

        if (summaryError) {
          console.error('Error saving regular summary:', summaryError);
        }
        
        if (extendedSummaryError) {
          console.error('Error saving extended summary:', extendedSummaryError);
        }

        // Return the complete book with summary if available
        const completeBook = {
          ...savedBook,
          summary: summary || null,
          extended_summary: extendedSummary || null
        };

        return res.status(201).json({
          message: 'Book successfully added to database',
          book: completeBook
        });
      } catch (summaryError) {
        console.error('Error generating summaries:', summaryError);
        
        // Return the book even if summary generation fails
        return res.status(201).json({
          message: 'Book added to database, but summary generation failed',
          book: savedBook,
          warning: 'Summaries could not be generated at this time'
        });
      }
    } catch (error) {
      console.error('Error processing book request:', error);
      return next(error);
    }
  }
}

export const searchController = new SearchController();