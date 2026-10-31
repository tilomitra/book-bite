import { cleanAudioScript, countAudioTags, splitIntoChunks, stripAudioTags } from '../services/audioScript';
import { pcmToWav, wavPcm } from '../services/geminiTtsService';
import { supportsAudioTags } from '../services/elevenLabsService';

describe('cleanAudioScript', () => {
  it('drops headings, section labels, markdown and list markers', () => {
    const raw = [
      '[HOOK - ~50 words]',
      'What if **willpower** is the *wrong* tool?',
      '',
      '## Core ideas',
      '- Habits run on cues.',
      '1. Rewards close the loop.',
      '',
      '**Closing**',
      'Start small.'
    ].join('\n');
    expect(cleanAudioScript(raw)).toBe(
      'What if willpower is the wrong tool?\n\nHabits run on cues. Rewards close the loop.\n\nStart small.'
    );
  });

  it('keeps one allowed tag per paragraph and removes unknown ones', () => {
    const raw = '[Thoughtful] Here is the turn. [laughs] [curious] Why?\n\n[door slams] Next idea.';
    const clean = cleanAudioScript(raw);
    expect(clean).toBe('[thoughtful] Here is the turn. Why?\n\nNext idea.');
    expect(countAudioTags(clean)).toBe(1);
  });

  it('drops paragraphs that are only tags', () => {
    expect(cleanAudioScript('[warmly]\n\nHello.')).toBe('Hello.');
  });
});

describe('stripAudioTags', () => {
  it('removes every bracketed tag', () => {
    expect(stripAudioTags('[warmly] Hello there. [softly] Bye.')).toBe('Hello there. Bye.');
  });
});

describe('splitIntoChunks', () => {
  it('joins paragraphs up to the limit and never splits one that fits', () => {
    const paragraphs = ['a'.repeat(40), 'b'.repeat(40), 'c'.repeat(40)];
    const chunks = splitIntoChunks(paragraphs.join('\n\n'), 90);
    expect(chunks).toEqual([`${paragraphs[0]}\n\n${paragraphs[1]}`, paragraphs[2]]);
  });

  it('splits a long paragraph on sentence ends, then on spaces', () => {
    const text = 'One two three. Four five six. ' + 'word '.repeat(20).trim() + '.';
    const chunks = splitIntoChunks(text, 30);
    expect(chunks.every(c => c.length <= 30)).toBe(true);
    expect(chunks[0]).toBe('One two three. Four five six.');
    expect(chunks.join(' ').replace(/\s+/g, ' ')).toBe(text);
  });

  it('keeps all the text', () => {
    const text = Array.from({ length: 30 }, (_, i) => `Sentence number ${i} is here.`).join(' ');
    expect(splitIntoChunks(text, 100).join(' ')).toBe(text);
  });
});

describe('WAV helpers', () => {
  it('round-trips PCM through a WAV header', () => {
    const pcm = Buffer.from([1, 2, 3, 4, 5, 6]);
    const wav = pcmToWav(pcm);
    expect(wav.length).toBe(44 + pcm.length);
    expect(wavPcm(wav)).toEqual(pcm);
  });
});

describe('supportsAudioTags', () => {
  it('is true for v3/v4 only', () => {
    expect(supportsAudioTags('eleven_v4')).toBe(true);
    expect(supportsAudioTags('eleven_v3')).toBe(true);
    expect(supportsAudioTags('eleven_turbo_v2_5')).toBe(false);
    expect(supportsAudioTags('eleven_multilingual_v2')).toBe(false);
  });
});
