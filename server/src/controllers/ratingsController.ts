import { Request, Response } from 'express';
import { OpenLibraryService } from '../services/openLibraryService';
import { BookRatingSchema } from '../models/types';
import { supabase } from '../config/supabase';

const openLibraryService = new OpenLibraryService();

export const getRatingsByBookId = async (req: Request, res: Response): Promise<void> => {
  try {
    const { bookId } = req.params;
    
    if (!bookId) {
      res.status(400).json({
        error: 'Book ID is required'
      });
      return;
    }

    // Fetch the book to get its ISBN
    const { data: book, error } = await supabase
      .from('books')
      .select('isbn10, isbn13, google_books_id')
      .eq('id', bookId)
      .single();

    if (error || !book) {
      res.status(404).json({
        error: 'Book not found'
      });
      return;
    }

    let rating = null;

    // Try ISBN13 first, then ISBN10, then Google Books ID
    if (book.isbn13) {
      rating = await openLibraryService.getRatingsByISBN(book.isbn13);
    }
    
    if (!rating && book.isbn10) {
      rating = await openLibraryService.getRatingsByISBN(book.isbn10);
    }
    
    if (!rating && book.google_books_id) {
      rating = await openLibraryService.getRatingsByGoogleBooksId(book.google_books_id);
    }

    if (!rating) {
      res.status(404).json({
        error: 'No ratings found for this book'
      });
      return;
    }

    // Validate the response
    const validatedRating = BookRatingSchema.parse(rating);

    res.json({
      book_id: bookId,
      rating: validatedRating
    });

  } catch (error) {
    console.error('Error fetching book ratings:', error);
    res.status(500).json({
      error: 'Internal server error while fetching ratings'
    });
  }
};

export const getRatingsByISBN = async (req: Request, res: Response): Promise<void> => {
  try {
    const { isbn } = req.params;
    
    if (!isbn) {
      res.status(400).json({
        error: 'ISBN is required'
      });
      return;
    }

    const rating = await openLibraryService.getRatingsByISBN(isbn);

    if (!rating) {
      res.status(404).json({
        error: 'No ratings found for this ISBN'
      });
      return;
    }

    // Validate the response
    const validatedRating = BookRatingSchema.parse(rating);

    res.json({
      isbn,
      rating: validatedRating
    });

  } catch (error) {
    console.error('Error fetching ratings by ISBN:', error);
    res.status(500).json({
      error: 'Internal server error while fetching ratings'
    });
  }
};