import { Request, Response, NextFunction } from 'express';
import { SummaryService } from '../services/summaryService';
import { DailyIdeaService } from '../services/dailyIdeaService';
import { HighlightService } from '../services/highlightService';
import { SummarySchema } from '../models/types';
import { z } from 'zod';

const summaryService = new SummaryService();
const dailyIdeaService = new DailyIdeaService();
export const highlightService = new HighlightService();

const DailyIdeaQuerySchema = z.object({
  // The client's local date, so the idea changes at the user's midnight
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(d => !isNaN(Date.parse(d))).optional()
});

const HighlightsQuerySchema = z.object({
  page: z.coerce.number().int().min(1).max(1000).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(20),
  // New for each visit to Discover; mixes the order. Without it the feed is most read first.
  seed: z.coerce.number().int().min(1).max(2147483647).optional()
});

export class SummaryController {
  async getHighlights(req: Request, res: Response, next: NextFunction) {
    try {
      const parsed = HighlightsQuerySchema.safeParse(req.query);
      if (!parsed.success) {
        return res.status(400).json({ error: 'page, limit and seed must be positive integers' });
      }
      const { page, limit, seed } = parsed.data;
      return res.json(await highlightService.getHighlights(page, limit, seed));
    } catch (error) {
      return next(error);
    }
  }


  async getSummaryByBookId(req: Request, res: Response, next: NextFunction) {
    try {
      const { bookId } = req.params;
      const summary = await summaryService.getSummaryByBookId(bookId);
      
      if (!summary) {
        return res.status(404).json({ error: 'Summary not found' });
      }
      
      return res.json(summary);
    } catch (error) {
      return next(error);
    }
  }

  async getDailyIdea(req: Request, res: Response, next: NextFunction) {
    try {
      const parsed = DailyIdeaQuerySchema.safeParse(req.query);
      if (!parsed.success) {
        return res.status(400).json({ error: 'date must be YYYY-MM-DD' });
      }

      const date = parsed.data.date ?? new Date().toISOString().slice(0, 10);
      const dailyIdea = await dailyIdeaService.getDailyIdea(date);

      if (!dailyIdea) {
        return res.status(404).json({ error: 'Daily idea not found' });
      }

      return res.json(dailyIdea);
    } catch (error) {
      return next(error);
    }
  }

  async getRandomIdea(req: Request, res: Response, next: NextFunction) {
    try {
      // The app sends the book it showed last, so two opens in a row show different books
      const exclude = typeof req.query.exclude === 'string' ? req.query.exclude : undefined;
      const idea = await dailyIdeaService.getRandomIdea(exclude);
      if (!idea) {
        return res.status(404).json({ error: 'Idea not found' });
      }
      return res.json(idea);
    } catch (error) {
      return next(error);
    }
  }

  async generateSummary(req: Request, res: Response, next: NextFunction) {
    try {
      const { bookId } = req.params;
      const { style = 'full', regenerate = false } = req.body;
      
      // Check if summary already exists
      if (!regenerate) {
        const existingSummary = await summaryService.getSummaryByBookId(bookId);
        if (existingSummary) {
          // Return a fake "completed" job for existing summaries
          // This maintains consistency with the client's expected job-based flow
          return res.json({
            id: `existing-${bookId}`,
            bookId: bookId,
            status: 'completed',
            message: 'Summary already exists'
          });
        }
      }
      
      // Create a job for async generation
      const job = await summaryService.createSummaryGenerationJob(bookId, style);
      
      return res.json({
        id: job.id,
        bookId: bookId,
        status: job.status,
        message: 'Summary generation started'
      });
    } catch (error) {
      return next(error);
    }
  }

  async updateSummary(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const summaryData = SummarySchema.partial().parse(req.body);
      
      const summary = await summaryService.updateSummary(id, summaryData);
      
      if (!summary) {
        return res.status(404).json({ error: 'Summary not found' });
      }
      
      return res.json(summary);
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({ 
          error: 'Invalid summary data', 
          details: error.errors 
        });
      }
      return next(error);
    }
  }

  async deleteSummary(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const deleted = await summaryService.deleteSummary(id);
      
      if (!deleted) {
        return res.status(404).json({ error: 'Summary not found' });
      }
      
      return res.status(204).send();
    } catch (error) {
      return next(error);
    }
  }

  async getJobStatus(req: Request, res: Response, next: NextFunction) {
    try {
      const { jobId } = req.params;

      // generateSummary hands out `existing-<bookId>` when the summary already exists
      if (jobId.startsWith('existing-')) {
        return res.json({
          id: jobId,
          bookId: jobId.slice('existing-'.length),
          status: 'completed',
          message: 'Summary already exists'
        });
      }

      const job = await summaryService.getJobStatus(jobId);
      
      if (!job) {
        return res.status(404).json({ error: 'Job not found' });
      }
      
      // Match the shape returned by generateSummary (the app decodes camelCase)
      return res.json({
        id: job.id,
        bookId: job.book_id,
        status: job.status,
        message: job.error_message ?? null
      });
    } catch (error) {
      return next(error);
    }
  }

  async getAllSummaries(req: Request, res: Response, next: NextFunction) {
    try {
      const { page = 1, limit = 20 } = req.query;
      
      const summaries = await summaryService.getAllSummaries({
        page: Number(page),
        limit: Number(limit)
      });
      
      return res.json(summaries);
    } catch (error) {
      return next(error);
    }
  }
}

export const summaryController = new SummaryController();