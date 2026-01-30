import { Request, Response, NextFunction } from 'express';
import { AudioSummaryService } from '../services/audioSummaryService';
import { BookService } from '../services/bookService';
import { SummaryService } from '../services/summaryService';

const audioSummaryService = new AudioSummaryService();
const bookService = new BookService();
const summaryService = new SummaryService();

class AudioController {
  /**
   * Get audio information for a book
   * GET /api/audio/book/:bookId
   */
  async getAudioByBookId(req: Request, res: Response, next: NextFunction) {
    try {
      const { bookId } = req.params;

      const audioInfo = await audioSummaryService.getAudioInfo(bookId);
      if (!audioInfo || !audioInfo.audioUrl) {
        return res.status(404).json({
          error: 'Audio not found',
          message: 'No audio summary exists for this book'
        });
      }

      return res.json({
        bookId,
        audioUrl: audioInfo.audioUrl,
        durationSeconds: audioInfo.durationSeconds,
        fileSizeBytes: audioInfo.fileSizeBytes,
        durationFormatted: audioInfo.durationSeconds
          ? formatDuration(audioInfo.durationSeconds)
          : null
      });
    } catch (error) {
      return next(error);
    }
  }

  /**
   * Generate audio for a book (admin only)
   * POST /api/audio/book/:bookId/generate
   */
  async generateAudio(req: Request, res: Response, next: NextFunction) {
    try {
      const { bookId } = req.params;
      const { voiceId, dryRun } = req.body;

      // Fetch book
      const book = await bookService.getBookById(bookId);
      if (!book) {
        return res.status(404).json({
          error: 'Book not found',
          message: `No book found with ID: ${bookId}`
        });
      }

      // Fetch summary
      const summary = await summaryService.getSummaryByBookId(bookId);
      if (!summary) {
        return res.status(404).json({
          error: 'Summary not found',
          message: 'Book must have a summary before generating audio'
        });
      }

      // Check if audio already exists
      const hasAudio = await audioSummaryService.hasAudio(bookId);
      if (hasAudio && !req.body.force) {
        return res.status(409).json({
          error: 'Audio already exists',
          message: 'Audio summary already exists for this book. Use force=true to regenerate.'
        });
      }

      if (dryRun) {
        // Generate script only for cost estimation
        const { script, wordCount, estimatedDurationMinutes } =
          await audioSummaryService.generateAudioScript(book, summary);
        const { characterCount, estimatedCost } = audioSummaryService.estimateCost(script);

        return res.json({
          dryRun: true,
          bookId,
          bookTitle: book.title,
          script,
          wordCount,
          characterCount,
          estimatedDurationMinutes,
          estimatedCost: `$${estimatedCost.toFixed(2)}`
        });
      }

      // Create job for tracking
      const job = await audioSummaryService.createAudioGenerationJob(bookId);

      // Start generation (async, but we return job ID immediately)
      // For CLI usage, this will run synchronously
      const result = await audioSummaryService.processAudioGeneration(
        book,
        summary,
        { voiceId },
        job.id
      );

      return res.status(201).json({
        success: true,
        bookId,
        bookTitle: book.title,
        jobId: job.id,
        audioUrl: result.audioUrl,
        durationSeconds: result.durationSeconds,
        durationFormatted: formatDuration(result.durationSeconds),
        fileSizeBytes: result.fileSizeBytes,
        fileSizeFormatted: formatFileSize(result.fileSizeBytes),
        voiceId: result.voiceId
      });
    } catch (error) {
      return next(error);
    }
  }

  /**
   * Get audio generation job status
   * GET /api/audio/job/:jobId
   */
  async getJobStatus(req: Request, res: Response, next: NextFunction) {
    try {
      const { jobId } = req.params;

      const job = await audioSummaryService.getJob(jobId);
      if (!job) {
        return res.status(404).json({
          error: 'Job not found',
          message: `No job found with ID: ${jobId}`
        });
      }

      return res.json(job);
    } catch (error) {
      return next(error);
    }
  }

  /**
   * List books without audio
   * GET /api/audio/missing
   */
  async listBooksWithoutAudio(req: Request, res: Response, next: NextFunction) {
    try {
      const limit = parseInt(req.query.limit as string) || 50;
      const books = await audioSummaryService.getBooksWithoutAudio(limit);

      return res.json({
        count: books.length,
        books
      });
    } catch (error) {
      return next(error);
    }
  }

  /**
   * Get quota/usage info
   * GET /api/audio/quota
   */
  async getQuotaInfo(_req: Request, res: Response, next: NextFunction) {
    try {
      const quota = await audioSummaryService.getQuotaInfo();

      return res.json({
        characterLimit: quota.characterLimit,
        characterCount: quota.characterCount,
        characterRemaining: quota.characterRemaining,
        percentageUsed: ((quota.characterCount / quota.characterLimit) * 100).toFixed(1) + '%'
      });
    } catch (error) {
      return next(error);
    }
  }
}

// Helper functions
function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
}

function formatFileSize(bytes: number): string {
  const mb = bytes / (1024 * 1024);
  return `${mb.toFixed(2)} MB`;
}

export const audioController = new AudioController();
