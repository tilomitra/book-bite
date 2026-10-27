import {
  BANNED_PHRASES,
  buildExtendedSummaryPrompt,
  checkExtendedSummary,
  isChapteredSummary,
  normalizeExtendedSummary,
  parseExtendedSummary
} from '../services/extendedSummaryPrompt';

const paragraph = (words: number) => Array.from({ length: words }, (_, i) => `word${i}`).join(' ') + '.';

function summary(chapterTitles: string[], intro = paragraph(60)) {
  return [intro, ...chapterTitles.map(t => `## ${t}\n\n${paragraph(150)}`)].join('\n\n');
}

const GOOD = summary([
  'The plateau of latent potential',
  'Build systems, then identity',
  'The four laws of behavior',
  'Make the cue obvious',
  'Make it easy to begin',
  'The takeaway'
]);

describe('buildExtendedSummaryPrompt', () => {
  const prompt = buildExtendedSummaryPrompt('Atomic Habits', ['James Clear'], 'A guide to habits.', ['Self-Help'], {
    subtitle: 'An Easy & Proven Way to Build Good Habits',
    hook: 'Tiny changes compound.',
    keyIdeas: ['Habits compound like interest', 'Systems beat goals']
  });

  test('includes the book and the ideas we already show', () => {
    expect(prompt).toContain('Atomic Habits: An Easy & Proven Way to Build Good Habits');
    expect(prompt).toContain('James Clear');
    expect(prompt).toContain('- Systems beat goals');
    expect(prompt).toContain('Tiny changes compound.');
  });

  test('asks for the chaptered format the iOS reader splits on', () => {
    expect(prompt).toContain('"## <Chapter title>"');
    expect(prompt).toContain('"## The takeaway"');
    expect(prompt).toMatch(/5-8 chapters/);
    expect(prompt).toMatch(/120-220 words/);
    expect(prompt).toMatch(/no bold/i);
  });

  test('forbids the clichés', () => {
    for (const phrase of BANNED_PHRASES) expect(prompt).toContain(`"${phrase}"`);
  });

  test('leaves out missing context', () => {
    const bare = buildExtendedSummaryPrompt('Drive', [], '', []);
    expect(bare).toContain('Author: Unknown author');
    expect(bare).not.toContain('Categories:');
    expect(bare).not.toContain('Key ideas we already show');
  });
});

describe('parseExtendedSummary', () => {
  test('splits intro and chapters on "## " lines', () => {
    const parsed = parseExtendedSummary(GOOD);
    expect(parsed.intro).toMatch(/^word0/);
    expect(parsed.chapters.map(c => c.title)).toEqual([
      'The plateau of latent potential',
      'Build systems, then identity',
      'The four laws of behavior',
      'Make the cue obvious',
      'Make it easy to begin',
      'The takeaway'
    ]);
    expect(parsed.chapters[0].body).toMatch(/^word0/);
  });
});

describe('checkExtendedSummary', () => {
  test('accepts a well-formed summary', () => {
    expect(checkExtendedSummary(GOOD)).toEqual([]);
    expect(isChapteredSummary(GOOD)).toBe(true);
  });

  test('flags the old unstructured prose', () => {
    const old = "In today's fast-paced and competitive business world, this book delves into leadership.";
    const problems = checkExtendedSummary(old);
    expect(problems.join(' ')).toMatch(/takeaway/);
    expect(problems.join(' ')).toMatch(/0 chapters/);
    expect(problems.join(' ')).toMatch(/fast-paced/);
    expect(problems.join(' ')).toMatch(/delve/);
    expect(isChapteredSummary(old)).toBe(false);
  });

  test('flags too few chapters, generic titles, lists and a missing intro', () => {
    const text = summary(['Chapter 1', 'Two', 'The takeaway'], '');
    const problems = checkExtendedSummary(text + '\n- a bullet');
    expect(problems).toContain('missing intro paragraph');
    expect(problems.join(' ')).toMatch(/2 chapters before the takeaway/);
    expect(problems.join(' ')).toMatch(/generic chapter title "Chapter 1"/);
    expect(problems).toContain('contains a list');
  });
});

describe('normalizeExtendedSummary', () => {
  test('turns other heading styles into "## " and strips emphasis', () => {
    const raw = 'Intro with **bold** and *italic* words.\n\n# First idea\n\nBody.\n\n**Second idea:**\n\nMore.\n\n\n\n### The takeaway\nEnd.';
    expect(normalizeExtendedSummary(raw)).toBe(
      'Intro with bold and italic words.\n\n## First idea\n\nBody.\n\n## Second idea\n\nMore.\n\n## The takeaway\nEnd.'
    );
  });
});
