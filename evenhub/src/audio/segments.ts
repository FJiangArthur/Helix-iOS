// Turns OpenAI realtime transcription server events into caption segments
// (partials + finals) tagged with the Even Hub speaker role.

export type SpeakerRole = 'self' | 'other' | 'unknown';

export interface Segment {
  itemId: string;
  text: string;
  isFinal: boolean;
  role: SpeakerRole;
}

/** Remembers which speaker role each stretch of appended audio carried. */
export class RoleTimeline {
  private spans: Array<{ start: number; end: number; role: SpeakerRole }> = [];
  private cursor = 0;
  private readonly keepMillis = 120_000;

  /** Records [durationMs] of appended audio with [role]. */
  add(durationMs: number, role: SpeakerRole): void {
    const last = this.spans[this.spans.length - 1];
    if (last && last.role === role && last.end === this.cursor) last.end += durationMs;
    else this.spans.push({ start: this.cursor, end: this.cursor + durationMs, role });
    this.cursor += durationMs;
    while (this.spans.length > 0 && this.spans[0]!.end < this.cursor - this.keepMillis) this.spans.shift();
  }

  get elapsedMs(): number {
    return this.cursor;
  }

  /** Majority role over [from, to] ms of appended audio; 'unknown' if none. */
  roleBetween(from: number, to: number): SpeakerRole {
    const weight: Record<SpeakerRole, number> = { self: 0, other: 0, unknown: 0 };
    for (const s of this.spans) {
      const overlap = Math.min(s.end, to) - Math.max(s.start, from);
      if (overlap > 0) weight[s.role] += overlap;
    }
    const best = (Object.keys(weight) as SpeakerRole[]).reduce((a, b) => (weight[b] > weight[a] ? b : a), 'unknown');
    return weight[best] > 0 ? best : 'unknown';
  }

  reset(): void {
    this.spans = [];
    this.cursor = 0;
  }
}

interface Item {
  text: string;
  start?: number;
  end?: number;
}

/**
 * Event names per the current OpenAI Realtime docs (GA interface):
 * input_audio_buffer.speech_started/stopped (audio_start_ms/audio_end_ms,
 * item_id), conversation.item.input_audio_transcription.delta (delta) and
 * .completed (transcript). Several items can be open at once; the partial is
 * every open item's text in arrival order.
 */
export class SegmentAssembler {
  private items = new Map<string, Item>();

  constructor(private readonly roles: RoleTimeline, private readonly emit: (s: Segment) => void) {}

  onServerEvent(e: Record<string, unknown>): void {
    const id = typeof e.item_id === 'string' ? e.item_id : null;
    switch (e.type) {
      case 'input_audio_buffer.speech_started':
        if (id) this.item(id).start = typeof e.audio_start_ms === 'number' ? e.audio_start_ms : undefined;
        break;
      case 'input_audio_buffer.speech_stopped':
        if (id) this.item(id).end = typeof e.audio_end_ms === 'number' ? e.audio_end_ms : undefined;
        break;
      case 'conversation.item.input_audio_transcription.delta':
        if (id && typeof e.delta === 'string') {
          this.item(id).text += e.delta;
          this.emitPartial(id);
        }
        break;
      case 'conversation.item.input_audio_transcription.completed':
        if (id) {
          const item = this.item(id);
          const text = typeof e.transcript === 'string' ? e.transcript.trim() : item.text.trim();
          const role = this.roleOf(item);
          this.items.delete(id);
          if (text !== '') this.emit({ itemId: id, text, isFinal: true, role });
          const next = [...this.items.keys()][0];
          if (next) this.emitPartial(next);
        }
        break;
      default:
        break;
    }
  }

  reset(): void {
    this.items.clear();
  }

  private item(id: string): Item {
    let item = this.items.get(id);
    if (!item) {
      item = { text: '' };
      this.items.set(id, item);
    }
    return item;
  }

  private roleOf(item: Item): SpeakerRole {
    const start = item.start ?? 0;
    const end = item.end ?? this.roles.elapsedMs;
    return this.roles.roleBetween(start, Math.max(end, start + 1));
  }

  private emitPartial(lastId: string): void {
    const text = [...this.items.values()].map((i) => i.text.trim()).filter((t) => t !== '').join(' ');
    const first = this.items.values().next().value as Item | undefined;
    this.emit({ itemId: lastId, text, isFinal: false, role: first ? this.roleOf(first) : 'unknown' });
  }
}
