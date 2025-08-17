import { Router } from 'express';
import { searchController } from '../controllers/searchController';

const router = Router();

// GET /api/search/books?q={query} - Search Google Books API
router.get('/books', searchController.searchGoogleBooks.bind(searchController));

// GET /api/search/book/{googleBooksId} - Get existing book by Google Books ID
router.get('/book/:googleBooksId', searchController.getExistingBook.bind(searchController));

// POST /api/search/request - Process a selected book and add to database
router.post('/request', searchController.requestBook.bind(searchController));

export default router;