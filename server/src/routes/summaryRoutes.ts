import { Router } from 'express';
import { summaryController } from '../controllers/summaryController';
import { authenticate, requireAdmin } from '../middleware/auth';

const router = Router();

// Public routes
router.get('/book/:bookId', summaryController.getSummaryByBookId);
router.get('/job/:jobId', summaryController.getJobStatus);

// Admin routes
router.get('/', authenticate, requireAdmin, summaryController.getAllSummaries);
router.post('/book/:bookId/generate', authenticate, requireAdmin, summaryController.generateSummary);
router.put('/:id', authenticate, requireAdmin, summaryController.updateSummary);
router.delete('/:id', authenticate, requireAdmin, summaryController.deleteSummary);

export default router;