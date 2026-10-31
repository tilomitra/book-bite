import axios, { AxiosInstance } from 'axios';
import { ElevenLabsVoice } from '../models/types';
import { splitIntoChunks, stripAudioTags } from './audioScript';

export interface AudioGenerationOptions {
  voiceId?: string;
  modelId?: string;
  stability?: number;
  similarityBoost?: number;
  /** Ignored by Eleven v4 (no Style slider). */
  style?: number;
  /** Ignored by Eleven v4. */
  useSpeakerBoost?: boolean;
}

const DEFAULT_VOICE_ID = 'ZF6FPAbjXT4488VcRRnw'; // Custom voice selected for book summaries
// Eleven v4: ElevenLabs' model for audiobooks and narration, top of the blind-listening
// leaderboards (2026-10). The old default, eleven_turbo_v2_5, is a deprecated low-latency model.
export const DEFAULT_MODEL_ID = 'eleven_v4';

// Script parts per request. Paragraph-sized parts with request stitching keep the tone
// steady across a 10-minute script and stay well under every model's per-request limit.
const CHUNK_CHARS = 2500;

// Price per 1,000 characters, same on every plan (elevenlabs.io/pricing/api, 2026-10).
const COST_PER_1000_CHARS: Record<string, number> = {
  eleven_v4: 0.08,
  eleven_v4_turbo: 0.04,
  eleven_v3: 0.08,
  eleven_v3_conversational: 0.04,
  eleven_multilingual_v2: 0.08,
  eleven_flash_v2_5: 0.04,
  eleven_flash_v2: 0.04,
  eleven_turbo_v2_5: 0.04,
  eleven_turbo_v2: 0.04
};

/** Models that read [tags] as delivery direction; the others would read them aloud. */
export function supportsAudioTags(modelId: string): boolean {
  return modelId.startsWith('eleven_v4') || modelId.startsWith('eleven_v3');
}

/** eleven_v3 doesn't support request stitching (previous_request_ids). */
function supportsStitching(modelId: string): boolean {
  return !modelId.startsWith('eleven_v3');
}

function voiceSettings(modelId: string, options: AudioGenerationOptions): Record<string, unknown> {
  const { stability = 0.5, similarityBoost = 0.75, style = 0.3, useSpeakerBoost = true } = options;
  // Eleven v4 has only Stability and Similarity (lower stability = more expressive).
  if (modelId.startsWith('eleven_v4')) {
    return { stability, similarity_boost: similarityBoost };
  }
  return { stability, similarity_boost: similarityBoost, style, use_speaker_boost: useSpeakerBoost };
}

export class ElevenLabsService {
  private client: AxiosInstance | null = null;
  private apiKey: string | null = null;

  constructor() {
    // Lazy initialization - don't throw on construction
    this.apiKey = process.env.ELEVENLABS_API_KEY || null;
    if (this.apiKey) {
      this.client = axios.create({
        baseURL: 'https://api.elevenlabs.io/v1',
        headers: {
          'xi-api-key': this.apiKey,
          'Content-Type': 'application/json'
        }
      });
    }
  }

  /**
   * Check if the service is configured and ready to use
   */
  isConfigured(): boolean {
    return this.client !== null && this.apiKey !== null;
  }

  private ensureConfigured(): AxiosInstance {
    if (!this.client || !this.apiKey) {
      throw new Error('ElevenLabs API key not configured. Set ELEVENLABS_API_KEY environment variable.');
    }
    return this.client;
  }

  /**
   * Generate audio from text using ElevenLabs TTS.
   * The text is sent in paragraph-sized parts; each part passes the ids of the parts before
   * it (request stitching), so the voice keeps one tone across the joins. Tags are removed
   * for models that don't read them as direction.
   * @returns Buffer containing MP3 audio data (the parts' MP3 frames, joined)
   */
  async generateAudio(
    text: string,
    options: AudioGenerationOptions = {}
  ): Promise<Buffer> {
    const { voiceId = DEFAULT_VOICE_ID, modelId = DEFAULT_MODEL_ID } = options;
    const client = this.ensureConfigured();

    const spoken = supportsAudioTags(modelId) ? text : stripAudioTags(text);
    const chunks = splitIntoChunks(spoken, CHUNK_CHARS);
    const stitch = supportsStitching(modelId);
    const settings = voiceSettings(modelId, options);

    const buffers: Buffer[] = [];
    const requestIds: string[] = [];
    for (let i = 0; i < chunks.length; i++) {
      const body: Record<string, unknown> = {
        text: chunks[i],
        model_id: modelId,
        voice_settings: settings
      };
      if (stitch) {
        if (requestIds.length > 0) body.previous_request_ids = requestIds.slice(-3);
        // Next text helps the end of a part sound like it continues; ignored when no ids follow.
        if (i + 1 < chunks.length) body.next_text = chunks[i + 1].slice(0, 500);
      }

      try {
        const response = await client.post(`/text-to-speech/${voiceId}`, body, {
          responseType: 'arraybuffer',
          timeout: 300000 // 5 minute timeout per part
        });
        buffers.push(Buffer.from(response.data));
        const requestId = response.headers['request-id'];
        if (typeof requestId === 'string' && requestId) requestIds.push(requestId);
      } catch (error) {
        if (axios.isAxiosError(error)) {
          const message = error.response?.data
            ? Buffer.from(error.response.data).toString()
            : error.message;
          console.error('ElevenLabs API error:', message);
          throw new Error(`ElevenLabs TTS failed on part ${i + 1} of ${chunks.length}: ${message}`);
        }
        throw error;
      }
    }

    return Buffer.concat(buffers);
  }

  /**
   * Get available voices from ElevenLabs
   * @returns List of available voices
   */
  async getVoices(): Promise<ElevenLabsVoice[]> {
    const client = this.ensureConfigured();
    try {
      const response = await client.get('/voices');
      return response.data.voices.map((voice: any) => ({
        voice_id: voice.voice_id,
        name: voice.name,
        category: voice.category,
        description: voice.description,
        preview_url: voice.preview_url
      }));
    } catch (error) {
      if (axios.isAxiosError(error)) {
        console.error('ElevenLabs API error:', error.response?.data || error.message);
        throw new Error('Failed to fetch voices from ElevenLabs');
      }
      throw error;
    }
  }

  /**
   * Get subscription/usage info
   * @returns Subscription info including character limits
   */
  async getSubscriptionInfo(): Promise<{
    characterLimit: number;
    characterCount: number;
    characterRemaining: number;
  }> {
    const client = this.ensureConfigured();
    try {
      const response = await client.get('/user/subscription');
      const { character_limit, character_count } = response.data;
      return {
        characterLimit: character_limit,
        characterCount: character_count,
        characterRemaining: character_limit - character_count
      };
    } catch (error) {
      if (axios.isAxiosError(error)) {
        console.error('ElevenLabs API error:', error.response?.data || error.message);
        throw new Error('Failed to fetch subscription info from ElevenLabs');
      }
      throw error;
    }
  }

  /**
   * Estimate cost for generating audio
   * @param characterCount Number of characters in the text
   * @param modelId Model the text is sent to
   * @returns Estimated cost in USD
   */
  estimateCost(characterCount: number, modelId: string = DEFAULT_MODEL_ID): number {
    const costPer1000Chars = COST_PER_1000_CHARS[modelId] ?? 0.08;
    return (characterCount / 1000) * costPer1000Chars;
  }

  /**
   * Get the default voice ID
   */
  getDefaultVoiceId(): string {
    return DEFAULT_VOICE_ID;
  }

  /**
   * Get the default model ID
   */
  getDefaultModelId(): string {
    return DEFAULT_MODEL_ID;
  }

  /**
   * Get recommended voices for book summaries
   */
  getRecommendedVoices(): { voiceId: string; name: string; description: string }[] {
    return [
      {
        voiceId: 'pNInz6obpgDQGcFmaJgB',
        name: 'Adam',
        description: 'Warm, conversational male voice - great for non-fiction'
      },
      {
        voiceId: 'EXAVITQu4vr4xnSDxMaL',
        name: 'Bella',
        description: 'Warm, friendly female voice - engaging and approachable'
      },
      {
        voiceId: '21m00Tcm4TlvDq8ikWAM',
        name: 'Rachel',
        description: 'Calm, clear female voice - professional and articulate'
      },
      {
        voiceId: 'ErXwobaYiN019PkySvjV',
        name: 'Antoni',
        description: 'Well-rounded male voice - natural and expressive'
      }
    ];
  }
}
