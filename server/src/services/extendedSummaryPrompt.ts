/**
 * The extended summary ("Read summary" in the app): a short intro, then titled chapters the iOS
 * reader splits on lines starting with "## ", ending with "## The takeaway". Pure functions so
 * the format rules can be tested without calling OpenAI.
 */

export const CHAPTER_PREFIX = '## ';
export const TAKEAWAY_TITLE = 'The takeaway';
export const MIN_CHAPTERS = 5; // not counting the takeaway
export const MAX_CHAPTERS = 8;

/** Phrases that mark generic AI prose. The prompt forbids them and the validator flags them. */
export const BANNED_PHRASES = [
  "in today's fast-paced",
  'fast-paced world',
  'delve',
  'delves',
  'game-changer',
  'game changer',
  'unlock',
  'journey',
  'tapestry',
  'navigate the complexities',
  'in conclusion',
  'a must-read',
  'thought-provoking',
  'treasure trove',
  'embark',
  'ever-evolving',
  'realm'
];

export interface ExtendedSummaryContext {
  subtitle?: string | null;
  hook?: string | null;
  keyIdeas?: string[];
}

export const EXTENDED_SUMMARY_SYSTEM_PROMPT = `You write book summaries for BookBite, an app of non-fiction book summaries read on a phone. Your summaries read like the best magazine writing: confident, specific and plain. You state the author's ideas directly, as claims about the world, instead of describing the book from the outside.`;

export function buildExtendedSummaryPrompt(
  title: string,
  authors: string[],
  description: string,
  categories: string[],
  context: ExtendedSummaryContext = {}
): string {
  const author = authors.length > 0 ? authors.join(', ') : 'Unknown author';
  const lines = [
    `Title: ${title}${context.subtitle ? `: ${context.subtitle}` : ''}`,
    `Author: ${author}`,
    categories.length > 0 ? `Categories: ${categories.join(', ')}` : null,
    description ? `Publisher description: ${description}` : null,
    context.hook ? `One-line hook we already show: ${context.hook}` : null,
    context.keyIdeas && context.keyIdeas.length > 0
      ? `Key ideas we already show (cover them, in more depth):\n${context.keyIdeas.map(i => `- ${i}`).join('\n')}`
      : null
  ].filter(Boolean).join('\n');

  return `Write the long-form summary of this book.

${lines}

Use what you know about the book itself, not only the description above. Explain the author's actual arguments, frameworks, terms, studies, stories and examples, named as the author names them. If you are not sure about a detail, leave it out rather than invent one.

FORMAT (follow exactly)
- Start with one intro paragraph of 50-90 words: the problem the book tackles and the author's central answer. No heading above it.
- Then ${MIN_CHAPTERS}-${MAX_CHAPTERS} chapters. Each chapter starts with a line "${CHAPTER_PREFIX}<Chapter title>" followed by 120-220 words of prose in 1-3 paragraphs.
- Chapter titles are short (2-7 words), evocative and specific to this book, like "The plateau of latent potential" or "Why willpower is the wrong tool". Never "Chapter 1", "Introduction", "Key idea 2" or "Conclusion".
- Each chapter covers one idea and moves the argument forward: the claim, then the author's evidence or a concrete example (a person, study, company, number or scene from the book), then what it means for the reader.
- End with a final chapter titled exactly "${CHAPTER_PREFIX}${TAKEAWAY_TITLE}": 50-90 words on what to remember and do differently.
- Total length 900-1,500 words.
- Plain text only: no bold, italics, bullet points, numbered lists or quotes formatted as blocks. The only markup is the "${CHAPTER_PREFIX}" heading lines.

VOICE
- Confident and direct. State ideas as the author's claims ("Habits compound like interest", "Clear argues that...") rather than describing the book ("This book explores...").
- Name the author at most once or twice per chapter. Do not start paragraphs with "The book", "This book", "The author" or "In this chapter".
- Concrete over abstract: prefer one vivid example to three general sentences.
- Short and medium sentences. Second person ("you") is fine when it lands an idea.
- Never use these words or phrases: ${BANNED_PHRASES.map(p => `"${p}"`).join(', ')}. No openings about how busy, fast-paced or competitive the modern world is. No rhetorical questions as openers. No praise of the book, no "who should read this", no criticism section.

Return only the summary text.`;
}

export interface Chapter {
  title: string;
  body: string;
}

export interface ParsedExtendedSummary {
  intro: string;
  chapters: Chapter[];
}

/** Splits on "## " lines the same way the iOS reader does */
export function parseExtendedSummary(text: string): ParsedExtendedSummary {
  const intro: string[] = [];
  const chapters: Chapter[] = [];
  for (const line of text.split('\n')) {
    if (line.startsWith(CHAPTER_PREFIX)) {
      chapters.push({ title: line.slice(CHAPTER_PREFIX.length).trim(), body: '' });
    } else if (chapters.length > 0) {
      chapters[chapters.length - 1].body += `${line}\n`;
    } else {
      intro.push(line);
    }
  }
  return {
    intro: intro.join('\n').trim(),
    chapters: chapters.map(c => ({ title: c.title, body: c.body.trim() }))
  };
}

/** In the chaptered format (used to skip summaries already rewritten): chapters ending with the takeaway */
export function isChapteredSummary(text: string | null | undefined): boolean {
  if (!text) return false;
  const { chapters } = parseExtendedSummary(text);
  return chapters.length >= 3 && chapters[chapters.length - 1].title.toLowerCase() === TAKEAWAY_TITLE.toLowerCase();
}

export function wordCount(text: string): number {
  return text.split(/\s+/).filter(Boolean).length;
}

/**
 * Tidies model output into the reader's format: "#"/"###" headings and bold-only lines become
 * "## " headings, and leftover bold/italic markers are removed.
 */
export function normalizeExtendedSummary(text: string): string {
  return text
    .replace(/\r\n/g, '\n')
    .split('\n')
    .map(line => {
      const trimmed = line.trim();
      const heading = trimmed.match(/^#{1,6}\s+(.+)$/) ?? trimmed.match(/^\*\*([^*]+)\*\*:?$/);
      if (heading) return `${CHAPTER_PREFIX}${heading[1].replace(/\*+/g, '').replace(/:$/, '').trim()}`;
      return line.replace(/\*\*(.+?)\*\*/g, '$1').replace(/(^|[^*\w])\*([^*\n]+)\*(?=[^*\w]|$)/g, '$1$2');
    })
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/** Problems with a generated summary; empty when it follows the format */
export function checkExtendedSummary(text: string): string[] {
  const problems: string[] = [];
  const { intro, chapters } = parseExtendedSummary(text);
  if (!intro) problems.push('missing intro paragraph');
  const last = chapters[chapters.length - 1];
  if (!last || last.title.toLowerCase() !== TAKEAWAY_TITLE.toLowerCase()) {
    problems.push(`last chapter is not "${TAKEAWAY_TITLE}"`);
  }
  const body = chapters.filter(c => c.title.toLowerCase() !== TAKEAWAY_TITLE.toLowerCase());
  if (body.length < MIN_CHAPTERS || body.length > MAX_CHAPTERS) {
    problems.push(`${body.length} chapters before the takeaway (want ${MIN_CHAPTERS}-${MAX_CHAPTERS})`);
  }
  for (const c of chapters) {
    if (!c.body) problems.push(`chapter "${c.title}" is empty`);
    if (/^(chapter|part|section|key idea)\s*\d+/i.test(c.title)) problems.push(`generic chapter title "${c.title}"`);
  }
  if (/^\s*([-*•]|\d+\.)\s/m.test(text)) problems.push('contains a list');
  if (/\*\*|__/.test(text)) problems.push('contains bold markup');
  const lower = text.toLowerCase();
  const banned = BANNED_PHRASES.filter(p => new RegExp(`\\b${p.replace(/[-']/g, '[-\' ]?')}`, 'i').test(lower));
  if (banned.length > 0) problems.push(`banned phrases: ${banned.join(', ')}`);
  return problems;
}
