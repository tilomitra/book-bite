import { Request, Response, NextFunction } from 'express';
import { BookService } from '../services/bookService';
import { BookSchema } from '../models/types';
import { z } from 'zod';

const bookService = new BookService();

export class BookController {
  async getAllBooks(req: Request, res: Response, next: NextFunction) {
    try {
      const { page = 1, limit = 20, search } = req.query;
      
      const books = await bookService.getAllBooks({
        page: Number(page),
        limit: Number(limit),
        search: search as string
      });
      
      res.json(books);
    } catch (error) {
      next(error);
    }
  }

  async getBookById(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const book = await bookService.getBookById(id);
      
      if (!book) {
        return res.status(404).json({ error: 'Book not found' });
      }
      
      res.json(book);
    } catch (error) {
      next(error);
    }
  }

  async searchBooks(req: Request, res: Response, next: NextFunction) {
    try {
      const { q, source = 'all' } = req.query;
      
      if (!q) {
        return res.status(400).json({ error: 'Search query is required' });
      }
      
      const books = await bookService.searchBooks(q as string, source as string);
      res.json(books);
    } catch (error) {
      next(error);
    }
  }

  async createBook(req: Request, res: Response, next: NextFunction) {
    try {
      const bookData = BookSchema.parse(req.body);
      const book = await bookService.createBook(bookData);
      res.status(201).json(book);
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ 
          error: 'Invalid book data', 
          details: error.errors 
        });
      }
      next(error);
    }
  }

  async updateBook(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const bookData = BookSchema.partial().parse(req.body);
      
      const book = await bookService.updateBook(id, bookData);
      
      if (!book) {
        return res.status(404).json({ error: 'Book not found' });
      }
      
      res.json(book);
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ 
          error: 'Invalid book data', 
          details: error.errors 
        });
      }
      next(error);
    }
  }

  async deleteBook(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const deleted = await bookService.deleteBook(id);
      
      if (!deleted) {
        return res.status(404).json({ error: 'Book not found' });
      }
      
      res.status(204).send();
    } catch (error) {
      next(error);
    }
  }

  async getBookCover(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const book = await bookService.getBookById(id);
      
      if (!book || !book.cover_url) {
        return res.status(404).json({ error: 'Cover not found' });
      }
      
      // Redirect to the cover URL or serve from cache
      res.redirect(book.cover_url);
    } catch (error) {
      next(error);
    }
  }

  async importFromISBN(req: Request, res: Response, next: NextFunction) {
    try {
      const { isbn } = req.body;
      
      if (!isbn) {
        return res.status(400).json({ error: 'ISBN is required' });
      }
      
      const book = await bookService.importBookFromISBN(isbn);
      
      if (!book) {
        return res.status(404).json({ error: 'Book not found with this ISBN' });
      }
      
      res.status(201).json(book);
    } catch (error) {
      next(error);
    }
  }
}

export const bookController = new BookController();