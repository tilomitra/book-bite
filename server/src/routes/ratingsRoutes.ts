import { Router } from 'express';
import { getRatingsByBookId, getRatingsByISBN } from '../controllers/ratingsController';

const router = Router();

// Get ratings for a specific book by book ID
router.get('/books/:bookId/ratings', getRatingsByBookId);

// Get ratings by ISBN (useful for testing or external integrations)
router.get('/isbn/:isbn/ratings', getRatingsByISBN);

export default router;