import { Router } from 'express';
import { audioController } from '../controllers/audioController';
import { authenticate, requireAdmin } from '../middleware/auth';

const router = Router();

// UUID validation regex
const uuidRegex = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';

// Public routes
// Get audio summary for a book
router.get(`/audio/book/:bookId(${uuidRegex})`, audioController.getAudioByBookId);

// Get audio generation job status
router.get(`/audio/job/:jobId(${uuidRegex})`, audioController.getJobStatus);

// Admin routes (paid ElevenLabs/OpenAI calls; scripts call the services directly)
// Generate audio for a book
router.post(`/audio/book/:bookId(${uuidRegex})/generate`, authenticate, requireAdmin, audioController.generateAudio);

// List books without audio
router.get('/audio/missing', authenticate, requireAdmin, audioController.listBooksWithoutAudio);

// Get ElevenLabs quota info
router.get('/audio/quota', authenticate, requireAdmin, audioController.getQuotaInfo);

export default router;
