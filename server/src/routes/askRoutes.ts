import express from 'express';
import rateLimit from 'express-rate-limit';
import { AskRequestSchema, AskService, MatchRequestSchema, AskEvent } from '../services/askService';

const router = express.Router();
export const askService = new AskService();

// Each answer is an LLM call; typing previews are one embedding each
const askLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 40 });
const matchLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 300 });

// Question of the day and Explore topics, with covers. ?date=YYYY-MM-DD is the user's local date.
router.get('/home', async (req, res, next) => {
  try {
    const date = typeof req.query.date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(req.query.date)
      ? req.query.date
      : new Date().toISOString().slice(0, 10);
    res.json(await askService.home(date));
  } catch (error) {
    next(error);
  }
});

// Books that look like they answer a half-typed question
router.post('/matches', matchLimiter, async (req, res, next) => {
  try {
    const parsed = MatchRequestSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'A question of 3 to 500 characters is required' });
    return res.json({ books: await askService.matches(parsed.data.question) });
  } catch (error) {
    return next(error);
  }
});

// Answer a question (SSE): `sources` (the cited books, numbered in order), then `delta`s of text, then `done`
router.post('/', askLimiter, async (req, res) => {
  const parsed = AskRequestSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'A question of 3 to 500 characters is required' });
    return;
  }

  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive'
  });
  const send = (event: AskEvent) => res.write(`data: ${JSON.stringify(event)}\n\n`);

  try {
    await askService.ask(parsed.data, send);
  } catch (error) {
    console.error('Error answering question:', error);
    send({ type: 'error', error: 'Couldn’t answer that right now. Please try again.' });
  }
  res.end();
});

export default router;
