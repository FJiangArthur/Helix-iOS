// Lightweight question detection + LLM answer -> ANSWER cues (spec §5.4: the
// answer pipeline feeds Conversate as ANSWER cues). Android reuses its
// existing QuestionDetector; this is the minimal web equivalent.
import type { SpeakerRole } from '../audio/segments';
import type { Cue } from '../core/cue';
import { BODY_MAX, DETAIL_MAX } from '../core/cueParser';

const OPENERS = /^(what|who|whom|whose|when|where|why|how|which|can|could|would|should|will|do|does|did|is|are|was|were|have|has)\b/i;

/** `?`-terminated, or starts with a wh-word / auxiliary; at least 3 words. */
export function isQuestion(text: string): boolean {
  const t = text.trim();
  if (t.split(/\s+/).filter(Boolean).length < 3) return false;
  return t.endsWith('?') || OPENERS.test(t);
}

export interface AnswerEngineOptions {
  answer: (question: string) => Promise<string>;
  clock: () => number;
  nextId: () => number;
  emit: (cue: Cue) => void;
}

export class AnswerEngine {
  private busy = false;
  private generation = 0;

  constructor(private readonly opts: AnswerEngineOptions) {}

  reset(): void {
    this.generation += 1;
    this.busy = false;
  }

  /** The wearer's own questions ('self') are not answered. One answer at a time. */
  async onFinal(text: string, role: SpeakerRole): Promise<void> {
    if (role === 'self' || this.busy || !isQuestion(text)) return;
    const gen = this.generation;
    this.busy = true;
    let answer: string;
    try {
      answer = (await this.opts.answer(text.trim())).replace(/\s+/g, ' ').trim();
    } catch {
      if (gen === this.generation) this.busy = false;
      return;
    }
    if (gen !== this.generation) return;
    this.busy = false;
    if (answer === '') return;
    this.opts.emit({
      id: this.opts.nextId(),
      type: 'ANSWER',
      title: 'Answer',
      body: answer.slice(0, BODY_MAX),
      detail: answer.length > BODY_MAX ? answer.slice(0, DETAIL_MAX) : null,
      createdAtMillis: this.opts.clock(),
    });
  }
}
