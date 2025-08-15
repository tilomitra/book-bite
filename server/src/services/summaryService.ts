import { supabase } from '../config/supabase';
import { OpenAIService } from './openaiService';
import { BookService } from './bookService';
import { Summary, SummaryJob, JobStatus } from '../models/types';
import NodeCache from 'node-cache';
import Bull from 'bull';

export class SummaryService {
  private openai: OpenAIService;
  private bookService: BookService;
  private cache: NodeCache;
  private summaryQueue: Bull.Queue;

  constructor() {
    this.openai = new OpenAIService();
    this.bookService = new BookService();
    this.cache = new NodeCache({ stdTTL: 1800, checkperiod: 300 }); // 30 min cache
    
    // Initialize Bull queue for background processing
    this.summaryQueue = new Bull('summary-generation', {
      redis: process.env.REDIS_URL || 'redis://localhost:6379'
    });
    
    // Process summary generation jobs
    this.setupQueueProcessor();
  }

  private setupQueueProcessor() {
    this.summaryQueue.process(async (job) => {
      const { bookId, style } = job.data;
      
      try {
        // Update job status to processing
        await this.updateJobStatus(job.id as string, 'processing');
        
        // Generate the summary
        await this.generateAndSaveSummary(bookId, style);
        
        // Update job status to completed
        await this.updateJobStatus(job.id as string, 'completed');
      } catch (error) {
        // Update job status to failed
        await this.updateJobStatus(
          job.id as string, 
          'failed', 
          error instanceof Error ? error.message : 'Unknown error'
        );
        throw error;
      }
    });
  }

  async getSummaryByBookId(bookId: string): Promise<Summary | null> {
    // Check cache first
    const cacheKey = `summary:book:${bookId}`;
    const cached = this.cache.get<Summary>(cacheKey);
    if (cached) return cached;

    const { data, error } = await supabase
      .from('summaries')
      .select('*')
      .eq('book_id', bookId)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return null;
      }
      throw new Error(`Failed to fetch summary: ${error.message}`);
    }

    // Cache the result
    if (data) {
      this.cache.set(cacheKey, data);
    }

    return data;
  }

  async createSummaryGenerationJob(
    bookId: string, 
    style: 'brief' | 'full' = 'full'
  ): Promise<SummaryJob> {
    // Create job record in database
    const { data: job, error } = await supabase
      .from('summary_generation_jobs')
      .insert({
        book_id: bookId,
        status: 'pending'
      })
      .select()
      .single();

    if (error) {
      throw new Error(`Failed to create job: ${error.message}`);
    }

    // Add to Bull queue for processing
    await this.summaryQueue.add({
      jobId: job.id,
      bookId,
      style
    });

    return job;
  }

  private async generateAndSaveSummary(
    bookId: string, 
    style: 'brief' | 'full'
  ): Promise<Summary> {
    // Fetch book details
    const book = await this.bookService.getBookById(bookId);
    
    if (!book) {
      throw new Error('Book not found');
    }

    // Generate summary using OpenAI
    const summaryData = await this.openai.generateBookSummary(
      book.title,
      book.authors,
      book.description || '',
      book.categories,
      style
    );

    // Save to database
    const { data: summary, error } = await supabase
      .from('summaries')
      .insert({
        book_id: bookId,
        ...summaryData
      })
      .select()
      .single();

    if (error) {
      throw new Error(`Failed to save summary: ${error.message}`);
    }

    // Invalidate cache
    this.cache.del(`summary:book:${bookId}`);

    return summary;
  }

  async updateSummary(id: string, summaryData: Partial<Summary>): Promise<Summary | null> {
    const { data, error } = await supabase
      .from('summaries')
      .update(summaryData)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return null;
      }
      throw new Error(`Failed to update summary: ${error.message}`);
    }

    // Invalidate cache
    if (data) {
      this.cache.del(`summary:book:${data.book_id}`);
    }

    return data;
  }

  async deleteSummary(id: string): Promise<boolean> {
    // Get summary to find book_id for cache invalidation
    const { data: summary } = await supabase
      .from('summaries')
      .select('book_id')
      .eq('id', id)
      .single();

    const { error } = await supabase
      .from('summaries')
      .delete()
      .eq('id', id);

    if (error) {
      if (error.code === 'PGRST116') {
        return false;
      }
      throw new Error(`Failed to delete summary: ${error.message}`);
    }

    // Invalidate cache
    if (summary) {
      this.cache.del(`summary:book:${summary.book_id}`);
    }

    return true;
  }

  async getJobStatus(jobId: string): Promise<SummaryJob | null> {
    const { data, error } = await supabase
      .from('summary_generation_jobs')
      .select('*')
      .eq('id', jobId)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return null;
      }
      throw new Error(`Failed to fetch job: ${error.message}`);
    }

    return data;
  }

  private async updateJobStatus(
    jobId: string, 
    status: JobStatus, 
    errorMessage?: string
  ): Promise<void> {
    const updateData: any = { status };
    
    if (errorMessage) {
      updateData.error_message = errorMessage;
    }
    
    if (status === 'failed') {
      // Increment retry count
      const { data: job } = await supabase
        .from('summary_generation_jobs')
        .select('retry_count')
        .eq('id', jobId)
        .single();
      
      if (job) {
        updateData.retry_count = (job.retry_count || 0) + 1;
      }
    }

    await supabase
      .from('summary_generation_jobs')
      .update(updateData)
      .eq('id', jobId);
  }

  async getAllSummaries(options: { page?: number; limit?: number }) {
    const { page = 1, limit = 20 } = options;
    const offset = (page - 1) * limit;

    const { data, error, count } = await supabase
      .from('summaries')
      .select('*, books!inner(title, authors)', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      throw new Error(`Failed to fetch summaries: ${error.message}`);
    }

    return {
      summaries: data || [],
      total: count || 0,
      page,
      limit,
      totalPages: Math.ceil((count || 0) / limit)
    };
  }
}