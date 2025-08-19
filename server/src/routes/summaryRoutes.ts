import { Router } from 'express';
import { summaryController } from '../controllers/summaryController';
import { authenticate, requireAdmin } from '../middleware/auth';

const router = Router();

// Public routes
router.get('/book/:bookId', summaryController.getSummaryByBookId);
router.get('/job/:jobId', summaryController.getJobStatus);
router.post('/book/:bookId/generate', summaryController.generateSummary); // Made public for mobile app

// Admin routes
router.get('/', authenticate, requireAdmin, summaryController.getAllSummaries);
router.put('/:id', authenticate, requireAdmin, summaryController.updateSummary);
router.delete('/:id', authenticate, requireAdmin, summaryController.deleteSummary);

export default router;