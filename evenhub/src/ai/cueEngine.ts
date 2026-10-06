// Transcript -> Conversate cues (spec §5.4). Port of Android CueEngine.kt:
// debounce finals 1.5 s, one LLM call over the last 60 s + Prep Note, at most
// one new cue per 8 s, never the same entity twice per session. An LLM call
// already in flight is not cancelled by new finals; reset() discards it.
import type { Cue } from '../core/cue';
import { parseCues, type ParsedCue } from '../core/cueParser';
import type { CuePrompt } from '../core/cuePrompt';

export interface CueEngineOptions {
  classify: (prompt: string, maxTokens: number) => Promise<string>;
  prompt: CuePrompt;
  clock: () => number;
  emit: (cue: Cue) => void;
  nextId?: () => number;
  debounceMillis?: number;
  minGapMillis?: number;
  windowMillis?: number;
}

export class CueEngine {
  private window: Array<{ text: string; at: number }> = [];
  private shownKeys = new Set<string>();
  private shownTitles: string[] = [];
  private prepNote = '';
  private lastEmitAt = Number.MIN_SAFE_INTEGER / 2;
  private debounce: ReturnType<typeof setTimeout> | null = null;
  private inFlight = false;
  private generation = 0;
  private ids = 0;
  private failureCount = 0;
  private readonly debounceMillis: number;
  private readonly minGapMillis: number;
  private readonly windowMillis: number;

  constructor(private readonly opts: CueEngineOptions) {
    this.debounceMillis = opts.debounceMillis ?? 1_500;
    this.minGapMillis = opts.minGapMillis ?? 8_000;
    this.windowMillis = opts.windowMillis ?? 60_000;
  }

  /** Consecutive LLM failures (0 after any success). */
  get failures(): number {
    return this.failureCount;
  }

  nextCueId(): number {
    return this.opts.nextId ? this.opts.nextId() : ++this.ids;
  }

  setPrepNote(text: string | null): void {
    this.prepNote = text ?? '';
  }

  /** Recent transcript text (for the answer context). */
  recentText(): string {
    return this.window.map((l) => l.text).join(' ');
  }

  reset(): void {
    if (this.debounce) clearTimeout(this.debounce);
    this.debounce = null;
    this.generation += 1;
    this.inFlight = false;
    this.window = [];
    this.shownKeys.clear();
    this.shownTitles = [];
    this.lastEmitAt = Number.MIN_SAFE_INTEGER / 2;
    this.failureCount = 0;
  }

  onFinal(text: string): void {
    const trimmed = text.trim();
    if (trimmed === '') return;
    this.window.push({ text: trimmed, at: this.opts.clock() });
    if (this.debounce) clearTimeout(this.debounce);
    this.debounce = setTimeout(() => {
      this.debounce = null;
      if (this.inFlight) return;
      void this.run();
    }, this.debounceMillis);
  }

  private async run(): Promise<void> {
    const now = this.opts.clock();
    while (this.window.length > 0 && now - this.window[0]!.at > this.windowMillis) this.window.shift();
    if (this.window.length === 0 || now - this.lastEmitAt < this.minGapMillis) return;
    const gen = this.generation;
    const text = this.opts.prompt.render(this.recentText(), this.prepNote, this.shownTitles);
    this.inFlight = true;
    let raw: string;
    try {
      raw = await this.opts.classify(text, this.opts.prompt.maxTokens);
    } catch {
      if (gen === this.generation) { this.failureCount += 1; this.inFlight = false; }
      return;
    }
    if (gen !== this.generation) return;
    this.inFlight = false;
    this.failureCount = 0;
    const parsed = parseCues(raw);
    if (!parsed) return;
    const fresh = parsed.find((c) => !this.shownKeys.has(key(c)));
    if (!fresh) return;
    this.shownKeys.add(key(fresh));
    this.shownTitles.push(fresh.title);
    this.lastEmitAt = this.opts.clock();
    this.opts.emit({
      id: this.nextCueId(),
      type: fresh.type,
      title: fresh.title,
      body: fresh.body,
      detail: fresh.detail,
      entity: fresh.entity,
      createdAtMillis: this.lastEmitAt,
    });
  }
}

const key = (c: ParsedCue) => (c.entity ?? c.title).toLowerCase().trim();
