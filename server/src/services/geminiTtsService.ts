import axios from 'axios';
import { splitIntoChunks, stripAudioTags } from './audioScript';

/**
 * Gemini TTS, used only by `generate-audio --compare` to A/B against ElevenLabs.
 * Needs GEMINI_API_KEY (Google AI Studio). Returns one WAV (24 kHz, mono, 16-bit PCM).
 */

export const GEMINI_TTS_MODEL = 'gemini-3.8-flash-tts';
export const GEMINI_DEFAULT_VOICE = 'Charon'; // "Informative"; Sulafat (warm) and Algieba (smooth) also suit narration
const GEMINI_STYLE = 'warm, calm and conversational, like a thoughtful narrator explaining a book to a friend';
const CHUNK_CHARS = 2500;
const SAMPLE_RATE = 24000;

/** Returns the PCM samples of a WAV file (the "data" chunk). */
export function wavPcm(wav: Buffer): Buffer {
  if (wav.toString('ascii', 0, 4) !== 'RIFF') return wav; // already raw PCM
  let offset = 12;
  while (offset + 8 <= wav.length) {
    const id = wav.toString('ascii', offset, offset + 4);
    const size = wav.readUInt32LE(offset + 4);
    if (id === 'data') return wav.subarray(offset + 8, Math.min(wav.length, offset + 8 + size));
    offset += 8 + size + (size % 2);
  }
  throw new Error('WAV has no data chunk');
}

/** Wraps 16-bit mono PCM in a WAV header. */
export function pcmToWav(pcm: Buffer, sampleRate: number = SAMPLE_RATE): Buffer {
  const header = Buffer.alloc(44);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(36 + pcm.length, 4);
  header.write('WAVE', 8, 'ascii');
  header.write('fmt ', 12, 'ascii');
  header.writeUInt32LE(16, 16); // fmt chunk size
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(sampleRate * 2, 28); // byte rate
  header.writeUInt16LE(2, 32); // block align
  header.writeUInt16LE(16, 34); // bits per sample
  header.write('data', 36, 'ascii');
  header.writeUInt32LE(pcm.length, 40);
  return Buffer.concat([header, pcm]);
}

export async function generateGeminiAudio(text: string, voice: string = GEMINI_DEFAULT_VOICE): Promise<Buffer> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error('GEMINI_API_KEY is not set');

  // Gemini reads the text as a verbatim transcript, so ElevenLabs tags are removed.
  const chunks = splitIntoChunks(stripAudioTags(text), CHUNK_CHARS);
  const parts: Buffer[] = [];
  for (let i = 0; i < chunks.length; i++) {
    try {
      const response = await axios.post(
        'https://generativelanguage.googleapis.com/v1beta/interactions',
        {
          model: GEMINI_TTS_MODEL,
          input: [
            {
              type: 'user_input',
              content: [
                {
                  type: 'text',
                  text: chunks[i],
                  annotations: [{ type: 'speech_metadata', style: GEMINI_STYLE }]
                }
              ]
            }
          ],
          response_format: { type: 'audio' },
          generation_config: { speech_config: [{ voice }] }
        },
        { headers: { 'x-goog-api-key': apiKey, 'Content-Type': 'application/json' }, timeout: 300000 }
      );

      const audio = (response.data.steps || [])
        .filter((step: any) => step.type === 'model_output')
        .flatMap((step: any) => step.content || [])
        .find((item: any) => item.type === 'audio');
      if (!audio?.data) throw new Error('No audio in the response');
      parts.push(wavPcm(Buffer.from(audio.data, 'base64')));
    } catch (error) {
      const message = axios.isAxiosError(error)
        ? JSON.stringify(error.response?.data ?? error.message)
        : (error as Error).message;
      throw new Error(`Gemini TTS failed on part ${i + 1} of ${chunks.length}: ${message}`);
    }
  }
  return pcmToWav(Buffer.concat(parts));
}
