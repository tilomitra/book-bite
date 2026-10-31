/**
 * Helpers for the spoken audio summary script: the writing rules the script model gets,
 * cleanup of its output, and splitting into parts for request stitching.
 *
 * Eleven v4 reads bracketed delivery tags ("[thoughtful]") as direction. Only the tags
 * below are kept, at most one per paragraph, so a stray "[HOOK]" label is never read aloud.
 */

export const AUDIO_TAGS = [
  'thoughtful',
  'curious',
  'warmly',
  'amused',
  'serious',
  'emphatic',
  'softly',
  'reflective',
  'matter-of-fact',
  'chuckles'
] as const;

const ALLOWED_TAGS = new Set<string>(AUDIO_TAGS);

/** Rules for the script model: write for the ear, not the page. */
export const SPOKEN_WRITING_RULES = `WRITE FOR THE EAR:
- Mostly short sentences, one idea each. Mix in a longer one now and then so the rhythm doesn't go flat.
- Paragraphs of 2 to 4 sentences, with a blank line between them. Each paragraph is one breath of thought.
- Use an ellipsis (...) for a real pause before a turn or a reveal, at most once or twice per section. Use a dash for a quick aside.
- Say things the way a person would say them out loud: "percent", not "%"; "for example", not "e.g."; short numbers as words.
- Use contractions. Ask the listener a question now and then, and answer it.
- No headings, section labels, lists, bullet points, markdown or stage directions.

DELIVERY TAGS:
- You may start a paragraph with one delivery tag in square brackets, where the tone really changes. Use at most 6 in the whole script.
- Allowed tags, exactly as written: ${AUDIO_TAGS.map(tag => `[${tag}]`).join(', ')}.
- Never invent other tags and never use sound effects.`;

/** Removes every bracketed tag (for models that would read them aloud). */
export function stripAudioTags(text: string): string {
  return text
    .replace(/\[[^\]\n]*\]\s*/g, '')
    .replace(/[ \t]{2,}/g, ' ')
    .replace(/ +\n/g, '\n')
    .trim();
}

/** Counts the delivery tags in a script. */
export function countAudioTags(text: string): number {
  return (text.match(/\[[^\]\n]*\]/g) || []).length;
}

/**
 * Turns model output into a clean spoken script: no markdown, headings, section labels or
 * unknown tags, at most one allowed tag per paragraph, paragraphs split by one blank line.
 */
export function cleanAudioScript(raw: string): string {
  const paragraphs = raw
    .replace(/\r\n/g, '\n')
    .split(/\n\s*\n/)
    .map(paragraph =>
      paragraph
        .split('\n')
        .map(line => line.trim())
        // Headings ("## Hook") and lines that are only a label ("[HOOK - ~50 words]", "**Closing**").
        .filter(line => line && !/^#{1,6}\s/.test(line) && !/^\[[^\]]*\]$/.test(line) && !/^\*\*[^*]+\*\*:?$/.test(line))
        .map(line => line.replace(/^([-*•]|\d+[.)])\s+/, ''))
        .join(' ')
    )
    .map(paragraph => {
      let keptTag = false;
      return paragraph
        .replace(/\*\*([^*]+)\*\*/g, '$1')
        .replace(/(^|\s)[*_]([^*_]+)[*_](?=[\s.,!?;:]|$)/g, '$1$2')
        .replace(/\[([^\]\n]*)\]\s*/g, (_match, tag: string) => {
          const name = tag.trim().toLowerCase();
          if (keptTag || !ALLOWED_TAGS.has(name)) return '';
          keptTag = true;
          return `[${name}] `;
        })
        .replace(/\s{2,}/g, ' ')
        .trim();
    })
    .filter(paragraph => stripAudioTags(paragraph).length > 0);

  return paragraphs.join('\n\n');
}

function splitLong(text: string, maxChars: number, pattern: RegExp, next: (piece: string) => string[]): string[] {
  const pieces = text.split(pattern).filter(Boolean);
  const chunks: string[] = [];
  let current = '';
  for (const piece of pieces) {
    if (piece.length > maxChars) {
      if (current) chunks.push(current);
      current = '';
      chunks.push(...next(piece));
      continue;
    }
    const joined = current ? `${current} ${piece}` : piece;
    if (joined.length > maxChars) {
      chunks.push(current);
      current = piece;
    } else {
      current = joined;
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

function splitWords(text: string, maxChars: number): string[] {
  return splitLong(text, maxChars, /\s+/, piece => {
    const parts: string[] = [];
    for (let i = 0; i < piece.length; i += maxChars) parts.push(piece.slice(i, i + maxChars));
    return parts;
  });
}

function splitSentences(text: string, maxChars: number): string[] {
  return splitLong(text, maxChars, /(?<=[.!?…])\s+/, piece => splitWords(piece, maxChars));
}

/**
 * Splits a script into parts of at most `maxChars`, on paragraph breaks where it can,
 * then on sentence ends, then on spaces. Parts are sent one by one and stitched.
 */
export function splitIntoChunks(text: string, maxChars: number): string[] {
  const paragraphs = text.split(/\n\s*\n/).map(p => p.trim()).filter(Boolean);
  const chunks: string[] = [];
  let current = '';
  for (const paragraph of paragraphs) {
    if (paragraph.length > maxChars) {
      if (current) chunks.push(current);
      current = '';
      chunks.push(...splitSentences(paragraph, maxChars));
      continue;
    }
    const joined = current ? `${current}\n\n${paragraph}` : paragraph;
    if (joined.length > maxChars) {
      chunks.push(current);
      current = paragraph;
    } else {
      current = joined;
    }
  }
  if (current) chunks.push(current);
  return chunks;
}
