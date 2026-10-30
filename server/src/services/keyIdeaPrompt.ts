/**
 * What a key idea has to be. Older summaries asked for "the main insight or concept" and often got a
 * heading ("Redefining Courageous Leadership"), which says nothing on a card, in the idea of the day or to Ask.
 */
export const KEY_IDEA_RULES = `Each key idea must make sense on its own to someone who has not read the book:
- Format: a short lead of 2-5 words, a colon, then 1-2 sentences. Example: "Rumble before you decide: when a team avoids a hard conversation, the problem goes underground. Name the tension out loud and ask what each person is afraid of losing."
- State the book's actual claim: what is true, why it matters, or what to do differently. Never a topic, heading or chapter title.
- Be concrete: use the book's own framework, example or term where you know it. Do not invent statistics, quotes or anecdotes.
- 20 to 45 words in total. No "the author argues", no "this book", no "embrace", "unlock" or "harness".`;

export const MIN_AVERAGE_IDEA_WORDS = 10;

export function wordCount(text: string | null | undefined): number {
  return (text ?? '').trim().split(/\s+/).filter(Boolean).length;
}

/** A book's ideas are thin when they average fewer words than a real sentence with a reason in it. */
export function hasThinIdeas(ideas: string[], minWords = MIN_AVERAGE_IDEA_WORDS): boolean {
  if (ideas.length === 0) return false;
  return ideas.reduce((sum, idea) => sum + wordCount(idea), 0) / ideas.length < minWords;
}

export interface KeyIdeaContext {
  title: string;
  authors: string[];
  description: string;
  hook?: string | null;
  extendedSummary?: string | null;
  currentIdeas: string[];
}

export function buildKeyIdeaRewritePrompt(context: KeyIdeaContext): string {
  const lines = [
    'Rewrite the key ideas of this non-fiction book. Keep the same number of ideas and cover the same ground.',
    '',
    KEY_IDEA_RULES,
    '',
    `Title: ${context.title}`,
    `Authors: ${context.authors.join(', ')}`,
    `Description: ${context.description}`
  ];
  if (context.hook) lines.push(`Hook: ${context.hook}`);
  if (context.extendedSummary) lines.push('', 'Summary of the book:', context.extendedSummary);
  lines.push(
    '',
    'Current key ideas:',
    ...context.currentIdeas.map(idea => `- ${idea}`),
    '',
    'Reply with JSON only: {"keyIdeas": ["...", "..."]}, in the same order as the current ideas.'
  );
  return lines.join('\n');
}

/** Problems with a rewrite; empty when it can replace the old ideas. */
export function checkRewrittenIdeas(ideas: unknown, expected: number): string[] {
  if (!Array.isArray(ideas) || ideas.some(idea => typeof idea !== 'string')) return ['not a list of strings'];
  const problems: string[] = [];
  if (ideas.length !== expected) problems.push(`${ideas.length} ideas instead of ${expected}`);
  ideas.forEach((idea: string, i) => {
    const words = wordCount(idea);
    if (words < 15 || words > 60) problems.push(`idea ${i + 1} has ${words} words`);
  });
  return problems;
}
