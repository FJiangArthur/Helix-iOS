// Fallback transcriber: 3 s WAV chunks to the REST transcription endpoint.
// Finals only (no partials), used when the realtime socket keeps failing.
import type { Segment, SpeakerRole } from './segments';
import type { Transcriber } from './transcriber';

export const TRANSCRIPTIONS_URL = 'https://api.openai.com/v1/audio/transcriptions';

export function encodeWav(pcm: Uint8Array, sampleRate: number): Uint8Array<ArrayBuffer> {
  const out = new Uint8Array(44 + pcm.length);
  const dv = new DataView(out.buffer);
  const ascii = (o: number, s: string) => { for (let i = 0; i < 4; i++) out[o + i] = s.charCodeAt(i); };
  ascii(0, 'RIFF');
  dv.setUint32(4, 36 + pcm.length, true);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  dv.setUint32(16, 16, true); // fmt chunk size
  dv.setUint16(20, 1, true); // PCM
  dv.setUint16(22, 1, true); // mono
  dv.setUint32(24, sampleRate, true);
  dv.setUint32(28, sampleRate * 2, true); // byte rate
  dv.setUint16(32, 2, true); // block align
  dv.setUint16(34, 16, true); // bits per sample
  ascii(36, 'data');
  dv.setUint32(40, pcm.length, true);
  out.set(pcm, 44);
  return out;
}

export type FetchFn = (url: string, init: RequestInit) => Promise<Response>;

export interface ChunkedOptions {
  apiKey: string;
  model: string;
  fetchFn?: FetchFn;
  chunkMillis?: number;
}

export class ChunkedTranscriber implements Transcriber {
  onSegment: ((s: Segment) => void) | null = null;
  onFailure: ((why: string) => void) | null = null;

  private chunks: Uint8Array[] = [];
  private size = 0;
  private roleBytes: Record<SpeakerRole, number> = { self: 0, other: 0, unknown: 0 };
  private seq = 0;
  private running = false;
  private inFlight = new Set<Promise<void>>();
  private readonly chunkBytes: number;

  constructor(private readonly opts: ChunkedOptions) {
    this.chunkBytes = Math.round(((opts.chunkMillis ?? 3000) / 1000) * 16000) * 2;
  }

  start(): void {
    this.running = true;
  }

  stop(): void {
    this.running = false;
    this.chunks = [];
    this.size = 0;
    this.roleBytes = { self: 0, other: 0, unknown: 0 };
  }

  appendPcm16k(bytes: Uint8Array, role: SpeakerRole): void {
    if (!this.running) return;
    this.chunks.push(bytes.slice());
    this.size += bytes.length;
    this.roleBytes[role] += bytes.length;
    if (this.size >= this.chunkBytes) this.flush();
  }

  /** Resolves when every request sent so far has finished (tests). */
  async idle(): Promise<void> {
    await Promise.all([...this.inFlight]);
  }

  private flush(): void {
    const pcm = new Uint8Array(this.size);
    let o = 0;
    for (const c of this.chunks) { pcm.set(c, o); o += c.length; }
    const role = (Object.keys(this.roleBytes) as SpeakerRole[]).reduce((a, b) => (this.roleBytes[b] > this.roleBytes[a] ? b : a), 'unknown');
    this.chunks = [];
    this.size = 0;
    this.roleBytes = { self: 0, other: 0, unknown: 0 };
    const itemId = `chunk-${++this.seq}`;
    const p = this.send(pcm, itemId, role).finally(() => this.inFlight.delete(p));
    this.inFlight.add(p);
  }

  private async send(pcm: Uint8Array, itemId: string, role: SpeakerRole): Promise<void> {
    const form = new FormData();
    form.append('file', new Blob([encodeWav(pcm, 16000)], { type: 'audio/wav' }), `${itemId}.wav`);
    form.append('model', this.opts.model);
    form.append('language', 'en');
    form.append('response_format', 'json');
    const fetchFn = this.opts.fetchFn ?? ((url, init) => fetch(url, init));
    try {
      const res = await fetchFn(TRANSCRIPTIONS_URL, { method: 'POST', headers: { Authorization: `Bearer ${this.opts.apiKey}` }, body: form });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = (await res.json()) as { text?: string };
      const text = (json.text ?? '').trim();
      if (text !== '' && this.running) this.onSegment?.({ itemId, text, isFinal: true, role });
    } catch (e) {
      this.onFailure?.(e instanceof Error ? e.message : String(e));
    }
  }
}
