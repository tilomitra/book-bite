import OpenAI from 'openai';
import { supabase } from '../config/supabase';
import { ElevenLabsService, AudioGenerationOptions } from './elevenLabsService';
import { SPOKEN_WRITING_RULES, cleanAudioScript, stripAudioTags } from './audioScript';
import { Book, Summary, AudioGenerationJob } from '../models/types';

const AUDIO_BUCKET = 'audio-summaries';

export interface AudioScriptGenerationResult {
  script: string;
  wordCount: number;
  estimatedDurationMinutes: number;
}

export interface AudioGenerationResult {
  audioUrl: string;
  durationSeconds: number;
  fileSizeBytes: number;
  script: string;
  voiceId: string;
}

export class AudioSummaryService {
  private openai: OpenAI;
  private elevenLabs: ElevenLabsService;
  // Same model as the written summaries. A reasoning model: max_completion_tokens counts
  // reasoning tokens and only the default temperature is allowed.
  private model = 'gpt-6-luna';

  constructor() {
    if (!process.env.OPENAI_API_KEY) {
      throw new Error('OpenAI API key not configured');
    }

    this.openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY
    });

    this.elevenLabs = new ElevenLabsService();
  }

  /**
   * Generate an audio-optimized script for a book summary
   * Target: ~1500 words (~10 minutes at 150 wpm)
   */
  async generateAudioScript(
    book: Book,
    summary: Summary
  ): Promise<AudioScriptGenerationResult> {
    const prompt = this.buildAudioScriptPrompt(book, summary);

    try {
      const response = await this.openai.chat.completions.create({
        model: this.model,
        max_completion_tokens: 12000,
        messages: [
          {
            role: 'system',
            content: `You write audio summaries of non-fiction books that a narrator reads aloud.
Write the way a thoughtful person talks when they explain a book they love to a curious friend: warm, clear and specific.
It must sound spoken, not read: natural rhythm, contractions, the odd question to the listener, no written-style constructions.`
          },
          {
            role: 'user',
            content: prompt
          }
        ]
      });

      const raw = response.choices[0].message.content;
      if (!raw) {
        throw new Error('No script generated from OpenAI');
      }

      const script = cleanAudioScript(raw);
      const wordCount = stripAudioTags(script).split(/\s+/).length;
      const estimatedDurationMinutes = wordCount / 150; // Average speaking rate

      return {
        script,
        wordCount,
        estimatedDurationMinutes
      };
    } catch (error) {
      console.error('Error generating audio script:', error);
      throw new Error('Failed to generate audio script');
    }
  }

  private buildAudioScriptPrompt(book: Book, summary: Summary): string {
    const keyIdeasText = summary.key_ideas
      .map((idea, i) => `${i + 1}. ${idea.idea}`)
      .join('\n');

    const applicationText = summary.how_to_apply
      .map((point, i) => `${i + 1}. ${point.action}`)
      .join('\n');

    return `Create an audio summary script for "${book.title}" by ${book.authors.join(', ')}.

SOURCE MATERIAL:
- Hook: ${summary.one_sentence_hook}
- Key Ideas:
${keyIdeasText}
- How to Apply:
${applicationText}
- Extended Summary: ${summary.extended_summary || 'Not available'}

TARGET LENGTH: Approximately 1500 words (about 10 minutes of audio)

CRITICAL PRIORITY: Focus 90% of the script on the ACTUAL IDEAS and PRACTICAL APPLICATIONS from the book. Do NOT spend time on:
- The author's background, credentials, or personal story
- How popular or successful the book is
- Publishing history or sales figures
- Generic statements about why the topic matters
- Lengthy introductions or context-setting

STRUCTURE (in this order, with no headings or labels in the script):

1. Opening (about 50 words). Jump straight into the most compelling idea from the book: a provocative question or a counterintuitive premise.

2. Core ideas (about 1100 words). The heart of the summary. For each major idea:
   - State it clearly in one or two sentences.
   - Show HOW it works with a specific example or analogy.
   - Share any memorable framework, model or research finding the author presents.
   - Move to the next idea with a natural spoken transition.

3. Putting it to work (about 300 words). Specific steps the listener can take, starting today, and the common mistakes to avoid. Concrete, not vague.

4. Close (about 50 words). The single most important takeaway, brief and memorable.

${SPOKEN_WRITING_RULES}

AVOID:
- Filler like "let's dive in", "here's the thing" or "in this summary"
- Meta-commentary about the book or the summary itself
- Every sentence must add value

OUTPUT: Only the script, ready to be read aloud: paragraphs separated by blank lines, with delivery tags as allowed above.`;
  }

  /**
   * Generate audio from script using ElevenLabs
   */
  async generateAudio(
    script: string,
    options: AudioGenerationOptions = {}
  ): Promise<Buffer> {
    return this.elevenLabs.generateAudio(script, options);
  }

  /**
   * Upload audio file to Supabase Storage
   */
  async uploadAudio(
    bookId: string,
    audioBuffer: Buffer
  ): Promise<{ url: string; fileSizeBytes: number }> {
    const fileName = `${bookId}.mp3`;
    const fileSizeBytes = audioBuffer.length;

    // First, try to delete existing file if any
    try {
      await supabase.storage.from(AUDIO_BUCKET).remove([fileName]);
    } catch {
      // Ignore if file doesn't exist
    }

    const { error } = await supabase.storage
      .from(AUDIO_BUCKET)
      .upload(fileName, audioBuffer, {
        contentType: 'audio/mpeg',
        cacheControl: '31536000', // 1 year cache
        upsert: true
      });

    if (error) {
      console.error('Error uploading audio to Supabase:', error);
      throw new Error(`Failed to upload audio: ${error.message}`);
    }

    // Get public URL
    const { data: urlData } = supabase.storage
      .from(AUDIO_BUCKET)
      .getPublicUrl(fileName);

    return {
      url: urlData.publicUrl,
      fileSizeBytes
    };
  }

  /**
   * Update summary with audio information
   */
  async updateSummaryWithAudio(
    bookId: string,
    audioUrl: string,
    durationSeconds: number,
    fileSizeBytes: number,
    script: string,
    voiceId: string
  ): Promise<void> {
    const { error } = await supabase
      .from('summaries')
      .update({
        audio_url: audioUrl,
        audio_duration_seconds: durationSeconds,
        audio_file_size_bytes: fileSizeBytes,
        audio_script: script,
        audio_voice_id: voiceId,
        audio_generated_at: new Date().toISOString()
      })
      .eq('book_id', bookId);

    if (error) {
      console.error('Error updating summary with audio:', error);
      throw new Error(`Failed to update summary: ${error.message}`);
    }
  }

  /**
   * Create an audio generation job
   */
  async createAudioGenerationJob(bookId: string): Promise<AudioGenerationJob> {
    const { data, error } = await supabase
      .from('audio_generation_jobs')
      .insert({
        book_id: bookId,
        status: 'pending'
      })
      .select()
      .single();

    if (error) {
      console.error('Error creating audio generation job:', error);
      throw new Error(`Failed to create job: ${error.message}`);
    }

    return data as AudioGenerationJob;
  }

  /**
   * Update audio generation job status
   */
  async updateJobStatus(
    jobId: string,
    status: AudioGenerationJob['status'],
    script?: string,
    errorMessage?: string
  ): Promise<void> {
    const updateData: any = { status };
    if (script) updateData.script = script;
    if (errorMessage) updateData.error_message = errorMessage;

    const { error } = await supabase
      .from('audio_generation_jobs')
      .update(updateData)
      .eq('id', jobId);

    if (error) {
      console.error('Error updating job status:', error);
      throw new Error(`Failed to update job: ${error.message}`);
    }
  }

  /**
   * Get audio generation job by ID
   */
  async getJob(jobId: string): Promise<AudioGenerationJob | null> {
    const { data, error } = await supabase
      .from('audio_generation_jobs')
      .select('*')
      .eq('id', jobId)
      .single();

    if (error) {
      if (error.code === 'PGRST116') return null;
      throw new Error(`Failed to fetch job: ${error.message}`);
    }

    return data as AudioGenerationJob;
  }

  /**
   * Full pipeline: Generate script, create audio, upload, and update summary
   */
  async processAudioGeneration(
    book: Book,
    summary: Summary,
    options: AudioGenerationOptions = {},
    jobId?: string,
    onProgress?: (status: string, message: string) => void
  ): Promise<AudioGenerationResult> {
    const voiceId = options.voiceId || this.elevenLabs.getDefaultVoiceId();
    const log = onProgress || ((status: string, msg: string) => console.log(`[${status}] ${msg}`));

    try {
      // Step 1: Generate audio script
      log('script_generating', 'Generating audio-optimized script...');
      if (jobId) await this.updateJobStatus(jobId, 'script_generating');

      const { script, wordCount, estimatedDurationMinutes } = await this.generateAudioScript(book, summary);
      log('script_generating', `Script generated: ${wordCount} words (~${estimatedDurationMinutes.toFixed(1)} minutes)`);

      if (jobId) await this.updateJobStatus(jobId, 'script_generating', script);

      // Step 2: Generate audio with ElevenLabs
      log('audio_generating', 'Generating audio with ElevenLabs...');
      if (jobId) await this.updateJobStatus(jobId, 'audio_generating', script);

      const audioBuffer = await this.generateAudio(script, { ...options, voiceId });
      const estimatedDuration = Math.round(estimatedDurationMinutes * 60);
      log('audio_generating', `Audio generated: ${(audioBuffer.length / 1024 / 1024).toFixed(2)} MB`);

      // Step 3: Upload to Supabase Storage
      log('uploading', 'Uploading to storage...');
      if (jobId) await this.updateJobStatus(jobId, 'uploading', script);

      const { url, fileSizeBytes } = await this.uploadAudio(book.id!, audioBuffer);
      log('uploading', `Uploaded to: ${url}`);

      // Step 4: Update summary record
      log('completed', 'Updating summary record...');
      await this.updateSummaryWithAudio(
        book.id!,
        url,
        estimatedDuration,
        fileSizeBytes,
        script,
        voiceId
      );

      if (jobId) await this.updateJobStatus(jobId, 'completed', script);
      log('completed', 'Audio generation complete!');

      return {
        audioUrl: url,
        durationSeconds: estimatedDuration,
        fileSizeBytes,
        script,
        voiceId
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      if (jobId) await this.updateJobStatus(jobId, 'failed', undefined, errorMessage);
      throw error;
    }
  }

  /**
   * Check if a book has audio
   */
  async hasAudio(bookId: string): Promise<boolean> {
    const { data, error } = await supabase
      .from('summaries')
      .select('audio_url')
      .eq('book_id', bookId)
      .single();

    if (error) return false;
    return !!data?.audio_url;
  }

  /**
   * Get audio info for a book
   */
  async getAudioInfo(bookId: string): Promise<{
    audioUrl: string | null;
    durationSeconds: number | null;
    fileSizeBytes: number | null;
  } | null> {
    const { data, error } = await supabase
      .from('summaries')
      .select('audio_url, audio_duration_seconds, audio_file_size_bytes')
      .eq('book_id', bookId)
      .single();

    if (error || !data) return null;

    return {
      audioUrl: data.audio_url,
      durationSeconds: data.audio_duration_seconds,
      fileSizeBytes: data.audio_file_size_bytes
    };
  }

  /**
   * Get books without audio (for batch processing reference)
   */
  async getBooksWithoutAudio(limit: number = 100): Promise<Array<{ id: string; title: string; authors: string[] }>> {
    const { data, error } = await supabase
      .from('summaries')
      .select(`
        book_id,
        books!inner (
          id,
          title,
          authors
        )
      `)
      .is('audio_url', null)
      .not('extended_summary', 'is', null)
      .limit(limit);

    if (error) {
      console.error('Error fetching books without audio:', error);
      throw new Error(`Failed to fetch books: ${error.message}`);
    }

    return (data || []).map((item: any) => ({
      id: item.books.id,
      title: item.books.title,
      authors: item.books.authors
    }));
  }

  /**
   * Estimate cost for generating audio for a script
   */
  estimateCost(
    script: string,
    modelId: string = this.elevenLabs.getDefaultModelId()
  ): { characterCount: number; estimatedCost: number } {
    const characterCount = script.length;
    const estimatedCost = this.elevenLabs.estimateCost(characterCount, modelId);
    return { characterCount, estimatedCost };
  }

  /**
   * Get ElevenLabs subscription info
   */
  async getQuotaInfo(): Promise<{
    characterLimit: number;
    characterCount: number;
    characterRemaining: number;
  }> {
    return this.elevenLabs.getSubscriptionInfo();
  }
}
