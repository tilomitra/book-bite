import { Router } from 'express';
import { bookController } from '../controllers/bookController';
import { authenticate, requireAdmin } from '../middleware/auth';

const router = Router();

// Public routes
router.get('/', bookController.getAllBooks);
router.get('/featured', bookController.getFeaturedBooks);
router.get('/nyt-bestsellers', bookController.getNYTBestsellerBooks);
router.get('/search', bookController.searchBooks);
router.get('/:id', bookController.getBookById);
router.get('/:id/cover', bookController.getBookCover);

// Admin routes
router.post('/', authenticate, requireAdmin, bookController.createBook);
router.post('/import', authenticate, requireAdmin, bookController.importFromISBN);
router.put('/:id', authenticate, requireAdmin, bookController.updateBook);
router.delete('/:id', authenticate, requireAdmin, bookController.deleteBook);

export default router;