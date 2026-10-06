// Conversate cues and the pending-cue queue (spec §4.4 + "Cue queue rules").
// Port of Android Cue.kt: same priorities, labels and eviction semantics.

export type CueType = 'ANSWER' | 'QUOTE' | 'HEADLINE' | 'BIO' | 'CONCEPT' | 'SUGGESTION' | 'NOTICE';

const META: Record<CueType, { priority: number; label: string }> = {
  ANSWER: { priority: 5, label: 'ANSWER' },
  QUOTE: { priority: 4, label: 'QUOTE' },
  HEADLINE: { priority: 3, label: 'NEWS' },
  BIO: { priority: 2, label: 'BIO' },
  CONCEPT: { priority: 2, label: 'CONCEPT' },
  SUGGESTION: { priority: 1, label: 'IDEA' },
  NOTICE: { priority: 0, label: 'NOTE' },
};

export const CueType = {
  values: Object.keys(META) as CueType[],
  /** Like Kotlin `valueOf`: exact name, throws on unknown. */
  valueOf(name: string): CueType {
    if (!(name in META)) throw new Error(`No CueType ${name}`);
    return name as CueType;
  },
  /** Lenient lookup; null when unknown. */
  parse(name: string): CueType | null {
    return name in META ? (name as CueType) : null;
  },
  priority: (t: CueType) => META[t].priority,
  label: (t: CueType) => META[t].label,
};

export interface Cue {
  id: number;
  type: CueType;
  title: string;
  body: string;
  detail?: string | null;
  entity?: string | null;
  ticker?: string | null;
  createdAtMillis: number;
}

/**
 * Pending cues. Highest priority first, FIFO within a priority. Over
 * [capacity] the oldest lowest-priority non-ANSWER cue is evicted; ANSWERs are
 * never evicted (so the queue may exceed capacity). Cues older than
 * [staleMillis] are dropped on every access.
 */
export class CueQueue {
  private items: Cue[] = [];

  constructor(private readonly capacity = 3, private readonly staleMillis = 90_000) {}

  get size(): number {
    return this.items.length;
  }

  offer(cue: Cue, now: number): void {
    this.prune(now);
    this.items.push(cue);
    while (this.items.length > this.capacity) {
      const candidates = this.items.filter((c) => c.type !== 'ANSWER');
      if (candidates.length === 0) break;
      const victim = candidates.reduce((min, c) =>
        CueType.priority(c.type) < CueType.priority(min.type) ||
        (CueType.priority(c.type) === CueType.priority(min.type) && c.createdAtMillis < min.createdAtMillis)
          ? c
          : min,
      );
      this.items.splice(this.items.indexOf(victim), 1);
    }
  }

  poll(now: number): Cue | null {
    this.prune(now);
    if (this.items.length === 0) return null;
    // Stable sort: equal keys keep insertion order, like Kotlin sortedWith.
    const next = [...this.items].sort(
      (a, b) => CueType.priority(b.type) - CueType.priority(a.type) || a.createdAtMillis - b.createdAtMillis,
    )[0]!;
    this.items.splice(this.items.indexOf(next), 1);
    return next;
  }

  count(now: number): number {
    this.prune(now);
    return this.items.length;
  }

  clear(): void {
    this.items = [];
  }

  private prune(now: number): void {
    this.items = this.items.filter((c) => now - c.createdAtMillis <= this.staleMillis);
  }
}
