import express from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { authenticate } from '../middleware/auth';
import { ReadingPassService, RedeemFailure } from '../services/readingPass';

const router = express.Router();
const readingPass = new ReadingPassService();

// Guessing codes: 31^6 codes, but keep brute force slow anyway
const redeemLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 10 });

const unlockSchema = z.object({
  bookIds: z.array(z.string().uuid()).min(1).max(50)
});

/** Books left, books unlocked, and the user's invite code (made on first request) */
router.get('/', authenticate, async (req, res, next) => {
  try {
    res.json(await readingPass.status(req.user));
  } catch (error) {
    next(error);
  }
});

/**
 * Opens books in full while books are left. A book that was unlocked before stays free.
 * The app also sends books it opened as a guest, after sign-in. Books over the limit are left out of
 * `unlockedBookIds`; the app checks for its book there.
 */
router.post('/unlock', authenticate, async (req, res, next) => {
  try {
    const parsed = unlockSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'bookIds must be 1 to 50 book ids' });
    return res.json(await readingPass.unlock(req.user, parsed.data.bookIds));
  } catch (error) {
    return next(error);
  }
});

/** Joins with a friend's code: both accounts get 5 more books. Errors carry a `code` and a message to show. */
router.post('/redeem', redeemLimiter, authenticate, async (req, res, next) => {
  try {
    return res.json(await readingPass.redeem(req.user, req.body?.code));
  } catch (error) {
    if (error instanceof RedeemFailure) {
      return res.status(error.code === 'invalid_code' ? 404 : 409).json({ error: error.message, code: error.code });
    }
    return next(error);
  }
});

export default router;
