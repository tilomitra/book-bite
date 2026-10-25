import axios, { AxiosInstance } from 'axios';
import { ElevenLabsVoice } from '../models/types';

export interface AudioGenerationOptions {
  voiceId?: string;
  modelId?: string;
  stability?: number;
  similarityBoost?: number;
  style?: number;
  useSpeakerBoost?: boolean;
}

const DEFAULT_VOICE_ID = 'ZF6FPAbjXT4488VcRRnw'; // Custom voice selected for book summaries
const DEFAULT_MODEL_ID = 'eleven_turbo_v2_5'; // Turbo v2.5 - best for long-form

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
   * Generate audio from text using ElevenLabs TTS
   * @param text The text to convert to speech
   * @param options Audio generation options
   * @returns Buffer containing MP3 audio data
   */
  async generateAudio(
    text: string,
    options: AudioGenerationOptions = {}
  ): Promise<Buffer> {
    const {
      voiceId = DEFAULT_VOICE_ID,
      modelId = DEFAULT_MODEL_ID,
      stability = 0.5,
      similarityBoost = 0.75,
      style = 0.3,
      useSpeakerBoost = true
    } = options;

    const client = this.ensureConfigured();
    try {
      const response = await client.post(
        `/text-to-speech/${voiceId}`,
        {
          text,
          model_id: modelId,
          voice_settings: {
            stability,
            similarity_boost: similarityBoost,
            style,
            use_speaker_boost: useSpeakerBoost
          }
        },
        {
          responseType: 'arraybuffer',
          timeout: 300000 // 5 minute timeout for long audio
        }
      );

      return Buffer.from(response.data);
    } catch (error) {
      if (axios.isAxiosError(error)) {
        const message = error.response?.data
          ? Buffer.from(error.response.data).toString()
          : error.message;
        console.error('ElevenLabs API error:', message);
        throw new Error(`ElevenLabs TTS failed: ${message}`);
      }
      throw error;
    }
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
   * @returns Estimated cost in USD
   */
  estimateCost(characterCount: number): number {
    // ElevenLabs pricing: ~$0.30 per 1000 characters for Professional tier
    // Turbo v2.5 is slightly cheaper at ~$0.18 per 1000 characters
    const costPer1000Chars = 0.18;
    return (characterCount / 1000) * costPer1000Chars;
  }

  /**
   * Get the default voice ID
   */
  getDefaultVoiceId(): string {
    return DEFAULT_VOICE_ID;
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
