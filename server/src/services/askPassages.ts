/**
 * The pieces of a summary that Ask retrieves: each key idea and each "how to apply" action.
 * Shared by the embed-ideas script (which stores their embeddings) and AskService (which ranks
 * them in memory when the idea_embeddings table isn't there).
 */

export type PassageKind = 'idea' | 'apply';

export interface Passage {
  /** "<bookId>:<kind>:<position>" */
  id: string;
  bookId: string;
  kind: PassageKind;
  position: number;
  text: string;
}

export interface PassageSource {
  key_ideas?: ({ idea?: string | null } | null)[] | null;
  how_to_apply?: ({ action?: string | null } | null)[] | null;
}

export function summaryPassages(bookId: string, summary: PassageSource): Passage[] {
  const make = (kind: PassageKind, texts: (string | null | undefined)[]) =>
    texts
      .map(t => t?.trim() ?? '')
      .map((text, position) => ({ id: `${bookId}:${kind}:${position}`, bookId, kind, position, text }))
      .filter(p => p.text.length > 0);
  return [
    ...make('idea', (summary.key_ideas ?? []).map(k => k?.idea)),
    ...make('apply', (summary.how_to_apply ?? []).map(a => a?.action))
  ];
}

/** Regeneration can leave several summaries per book; the newest wins, as in the API */
export function newestSummary<T extends { created_at: string }>(rows: T | T[] | null | undefined): T | null {
  const list = Array.isArray(rows) ? rows : rows ? [rows] : [];
  return [...list].sort((a, b) => b.created_at.localeCompare(a.created_at))[0] ?? null;
}
