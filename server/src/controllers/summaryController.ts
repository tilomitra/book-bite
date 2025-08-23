import { Request, Response, NextFunction } from 'express';
import { SummaryService } from '../services/summaryService';
import { SummarySchema } from '../models/types';
import { z } from 'zod';

const summaryService = new SummaryService();

export class SummaryController {
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
      const job = await summaryService.getJobStatus(jobId);
      
      if (!job) {
        return res.status(404).json({ error: 'Job not found' });
      }
      
      return res.json(job);
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