/**
 * Fixed questions for the Ask tab: the question of the day and the Explore topics. They live on
 * the server so the daily pick is the same for everyone and the list can change without an app
 * release.
 */

export const DAILY_QUESTIONS = [
  'How do I stay calm when everything feels urgent?',
  'How do I stop procrastinating on the one task that matters?',
  'How do I say no without feeling guilty?',
  'How do I build a habit that actually sticks?',
  'How do I give hard feedback without wrecking the relationship?',
  'How do I make a big decision when I can’t decide?',
  'How do I stop checking my phone first thing in the morning?',
  'How do I get better at saving money?',
  'How do I recover from burnout?',
  'How do I become more confident speaking up in meetings?',
  'How do I find work that feels meaningful?',
  'How do I get my team to take ownership?',
  'How do I stop overthinking everything?',
  'How do I protect time for deep work?',
  'How do I negotiate a raise?',
  'How do I deal with a difficult coworker?',
  'How do I start investing if I know nothing?',
  'How do I get out of a creative rut?',
  'How do I sleep better?',
  'How do I make friends as an adult?',
  'How do I handle criticism without getting defensive?',
  'How do I stop comparing myself to others?',
  'How do I learn something hard faster?',
  'How do I keep going when motivation runs out?',
  'How do I have a difficult conversation with my partner?',
  'How do I run better meetings?',
  'How do I think more clearly about risk?',
  'How do I start a side project and actually finish it?',
  'How do I worry less about what people think?',
  'How do I make time for what matters to me?'
];

export interface AskTopic {
  id: string;
  name: string;
  /** Starter questions shown when the topic is opened; the first one picks the topic's covers */
  questions: string[];
}

export const ASK_TOPICS: AskTopic[] = [
  {
    id: 'leading',
    name: 'Leading',
    questions: [
      'How do I get my team to take ownership?',
      'How do I give hard feedback without wrecking the relationship?',
      'How do I run better meetings?'
    ]
  },
  {
    id: 'focus',
    name: 'Focus',
    questions: [
      'How do I protect time for deep work?',
      'How do I stop checking my phone first thing in the morning?',
      'How do I stop procrastinating on the one task that matters?'
    ]
  },
  {
    id: 'habits',
    name: 'Habits',
    questions: [
      'How do I build a habit that actually sticks?',
      'How do I keep going when motivation runs out?',
      'How do I break a bad habit?'
    ]
  },
  {
    id: 'money',
    name: 'Money',
    questions: [
      'How do I start investing if I know nothing?',
      'How do I get better at saving money?',
      'How do I think more clearly about risk?'
    ]
  },
  {
    id: 'calm',
    name: 'Calm',
    questions: [
      'How do I stay calm when everything feels urgent?',
      'How do I stop overthinking everything?',
      'How do I recover from burnout?'
    ]
  },
  {
    id: 'people',
    name: 'People',
    questions: [
      'How do I deal with a difficult coworker?',
      'How do I make friends as an adult?',
      'How do I have a difficult conversation with my partner?'
    ]
  }
];

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/** Same question for everyone on a date; walks through the list one day at a time */
export function dailyQuestion(date: string): string {
  const day = Math.floor(Date.parse(`${date}T00:00:00Z`) / MS_PER_DAY);
  const count = DAILY_QUESTIONS.length;
  return DAILY_QUESTIONS[((day % count) + count) % count];
}
