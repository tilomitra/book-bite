import { Router } from 'express';
import { summaryController } from '../controllers/summaryController';
import rateLimit from 'express-rate-limit';
import { authenticate, requireAdmin } from '../middleware/auth';

const router = Router();

// Generation calls OpenAI, so keep a much tighter per-IP budget than the global limiter
const generationLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 20 });

// Public routes
router.get('/book/:bookId', summaryController.getSummaryByBookId);
router.get('/job/:jobId', summaryController.getJobStatus);
router.post('/book/:bookId/generate', generationLimiter, summaryController.generateSummary); // Made public for mobile app

// Admin routes
router.get('/', authenticate, requireAdmin, summaryController.getAllSummaries);
router.put('/:id', authenticate, requireAdmin, summaryController.updateSummary);
router.delete('/:id', authenticate, requireAdmin, summaryController.deleteSummary);

export default router;