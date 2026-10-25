import { Request, Response, NextFunction } from 'express';
import { BookService } from '../services/bookService';
import { BookSchema } from '../models/types';
import { z } from 'zod';

const bookService = new BookService();

// Clamp ?page= / ?limit= to sane integers (NaN/0 break the range math; PostgREST caps responses at 1000 rows)
function parsePagination(page: unknown, limit: unknown, defaultLimit: number) {
  const p = Math.max(1, Math.floor(Number(page)) || 1);
  const l = Math.min(1000, Math.max(1, Math.floor(Number(limit)) || defaultLimit));
  return { page: p, limit: l };
}

export class BookController {
  async getAllBooks(req: Request, res: Response, next: NextFunction) {
    try {
      const { page, limit, search } = req.query;
      
      const books = await bookService.getAllBooks({
        ...parsePagination(page, limit, 20),
        search: search as string
      });
      
      res.json(books);
    } catch (error) {
      next(error);
    }
  }

  async getFeaturedBooks(req: Request, res: Response, next: NextFunction) {
    try {
      const { page, limit, fresh = false } = req.query;
      
      const books = await bookService.getFeaturedBooks({
        ...parsePagination(page, limit, 100),
        fresh: fresh === 'true'
      });
      
      res.json(books);
    } catch (error) {
      next(error);
    }
  }

  async getNYTBestsellerBooks(req: Request, res: Response, next: NextFunction) {
    try {
      const { page, limit, fresh = false } = req.query;
      
      const books = await bookService.getNYTBestsellerBooks({
        ...parsePagination(page, limit, 100),
        fresh: fresh === 'true'
      });
      
      res.json(books);
    } catch (error) {
      next(error);
    }
  }

  async getBookById(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { id } = req.params;
      const book = await bookService.getBookById(id);
      
      if (!book) {
        res.status(404).json({ error: 'Book not found' });
        return;
      }
      
      res.json(book);
    } catch (error) {
      next(error);
    }
  }

  async searchBooks(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { q, source = 'all' } = req.query;
      const { page, limit } = parsePagination(req.query.page, req.query.limit, 20);
      
      // If no search query provided, return all books with pagination
      if (!q || (q as string).trim() === '') {
        const result = await bookService.getAllBooks({ page, limit });
        res.json({
          results: result.books,
          pagination: {
            page: result.page,
            limit: result.limit,
            total: result.total,
            totalPages: result.totalPages,
            hasMore: result.page < result.totalPages
          }
        });
        return;
      }
      
      const result = await bookService.searchBooks(
        q as string, 
        source as string,
        { page, limit }
      );
      
      res.json({
        results: result.books,
        pagination: {
          page: result.page,
          limit: result.limit,
          total: result.total,
          totalPages: result.totalPages,
          hasMore: result.page < result.totalPages
        }
      });
    } catch (error) {
      next(error);
    }
  }

  async createBook(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const bookData = BookSchema.parse(req.body);
      const book = await bookService.createBook(bookData);
      res.status(201).json(book);
    } catch (error) {
      if (error instanceof z.ZodError) {
        res.status(400).json({ 
          error: 'Invalid book data', 
          details: error.errors 
        });
        return;
      }
      next(error);
    }
  }

  async updateBook(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { id } = req.params;
      const bookData = BookSchema.partial().parse(req.body);
      
      const book = await bookService.updateBook(id, bookData);
      
      if (!book) {
        res.status(404).json({ error: 'Book not found' });
        return;
      }
      
      res.json(book);
    } catch (error) {
      if (error instanceof z.ZodError) {
        res.status(400).json({ 
          error: 'Invalid book data', 
          details: error.errors 
        });
        return;
      }
      next(error);
    }
  }

  async deleteBook(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { id } = req.params;
      const deleted = await bookService.deleteBook(id);
      
      if (!deleted) {
        res.status(404).json({ error: 'Book not found' });
        return;
      }
      
      res.status(204).send();
    } catch (error) {
      next(error);
    }
  }

  async getBookCover(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { id } = req.params;
      const book = await bookService.getBookById(id);
      
      if (!book || !book.cover_url) {
        res.status(404).json({ error: 'Cover not found' });
        return;
      }
      
      // Redirect to the cover URL or serve from cache
      res.redirect(book.cover_url);
    } catch (error) {
      next(error);
    }
  }

  async importFromISBN(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { isbn } = req.body;
      
      if (!isbn) {
        res.status(400).json({ error: 'ISBN is required' });
        return;
      }
      
      const book = await bookService.importBookFromISBN(isbn);
      
      if (!book) {
        res.status(404).json({ error: 'Book not found with this ISBN' });
        return;
      }
      
      res.status(201).json(book);
    } catch (error) {
      next(error);
    }
  }

  async getCategories(_req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const categories = await bookService.getCategories();
      res.json(categories);
    } catch (error) {
      next(error);
    }
  }

  async getBooksByCategory(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { category } = req.params;
      const { page, limit } = parsePagination(req.query.page, req.query.limit, 20);
      
      if (!category) {
        res.status(400).json({ error: 'Category is required' });
        return;
      }
      
      const books = await bookService.getBooksByCategory(
        category,
        page,
        limit
      );
      
      res.json(books);
    } catch (error) {
      next(error);
    }
  }
}

export const bookController = new BookController();