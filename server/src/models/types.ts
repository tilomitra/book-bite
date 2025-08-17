import { z } from 'zod';

// Confidence enum
export const ConfidenceSchema = z.enum(['high', 'medium', 'low']);
export type Confidence = z.infer<typeof ConfidenceSchema>;

// Book schema
export const BookSchema = z.object({
  id: z.string().uuid().optional(),
  title: z.string(),
  subtitle: z.string().nullable().optional(),
  authors: z.array(z.string()),
  isbn10: z.string().length(10).nullable().optional(),
  isbn13: z.string().length(13).nullable().optional(),
  published_year: z.number().int().nullable().optional(),
  publisher: z.string().nullable().optional(),
  categories: z.array(z.string()).default([]),
  cover_url: z.string().url().nullable().optional(),
  description: z.string().nullable().optional(),
  source_attribution: z.array(z.string()).default([]),
  google_books_id: z.string().nullable().optional(),
  open_library_id: z.string().nullable().optional(),
  popularity_rank: z.number().int().nullable().optional(),
  is_featured: z.boolean().default(false),
  is_nyt_bestseller: z.boolean().default(false).optional(),
  nyt_rank: z.number().int().nullable().optional(),
  nyt_weeks_on_list: z.number().int().nullable().optional(),
  nyt_list: z.string().nullable().optional(),
  nyt_last_updated: z.date().nullable().optional(),
  created_at: z.date().optional(),
  updated_at: z.date().optional()
});

export type Book = z.infer<typeof BookSchema>;

// Key Idea schema
export const KeyIdeaSchema = z.object({
  id: z.string(),
  idea: z.string(),
  tags: z.array(z.string()),
  confidence: ConfidenceSchema,
  sources: z.array(z.string())
});

export type KeyIdea = z.infer<typeof KeyIdeaSchema>;

// Application Point schema
export const ApplicationPointSchema = z.object({
  id: z.string(),
  action: z.string(),
  tags: z.array(z.string())
});

export type ApplicationPoint = z.infer<typeof ApplicationPointSchema>;

// Citation schema
export const CitationSchema = z.object({
  source: z.string(),
  url: z.string().url().nullable().optional()
});

export type Citation = z.infer<typeof CitationSchema>;

// Summary Style enum
export const SummaryStyleSchema = z.enum(['brief', 'full']);
export type SummaryStyle = z.infer<typeof SummaryStyleSchema>;

// Summary schema
export const SummarySchema = z.object({
  id: z.string().uuid().optional(),
  book_id: z.string().uuid(),
  one_sentence_hook: z.string(),
  key_ideas: z.array(KeyIdeaSchema),
  how_to_apply: z.array(ApplicationPointSchema),
  common_pitfalls: z.array(z.string()),
  critiques: z.array(z.string()),
  who_should_read: z.string(),
  limitations: z.string(),
  citations: z.array(CitationSchema),
  read_time_minutes: z.number().int(),
  style: SummaryStyleSchema,
  extended_summary: z.string().nullable().optional(),
  llm_model: z.string().optional(),
  llm_version: z.string().optional(),
  generation_date: z.date().optional(),
  created_at: z.date().optional(),
  updated_at: z.date().optional()
});

export type Summary = z.infer<typeof SummarySchema>;

// Job Status enum
export const JobStatusSchema = z.enum(['pending', 'processing', 'completed', 'failed']);
export type JobStatus = z.infer<typeof JobStatusSchema>;

// Summary Generation Job schema
export const SummaryJobSchema = z.object({
  id: z.string().uuid().optional(),
  book_id: z.string().uuid(),
  status: JobStatusSchema,
  error_message: z.string().nullable().optional(),
  retry_count: z.number().int().default(0),
  created_at: z.date().optional(),
  updated_at: z.date().optional()
});

export type SummaryJob = z.infer<typeof SummaryJobSchema>;

// Chat Message Role enum
export const MessageRoleSchema = z.enum(['user', 'assistant']);
export type MessageRole = z.infer<typeof MessageRoleSchema>;

// Chat Conversation schema
export const ChatConversationSchema = z.object({
  id: z.string().uuid().optional(),
  book_id: z.string().uuid(),
  title: z.string().nullable().optional(),
  created_at: z.date().optional(),
  updated_at: z.date().optional()
});

export type ChatConversation = z.infer<typeof ChatConversationSchema>;

// Chat Message schema
export const ChatMessageSchema = z.object({
  id: z.string().uuid().optional(),
  conversation_id: z.string().uuid(),
  role: MessageRoleSchema,
  content: z.string(),
  created_at: z.date().optional()
});

export type ChatMessage = z.infer<typeof ChatMessageSchema>;