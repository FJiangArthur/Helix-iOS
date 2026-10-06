// Runs the realtime transcriber and falls back to chunked REST after the
// socket has failed [maxRealtimeFailures] times in this session.
import type { Segment, SpeakerRole } from './segments';
import type { Transcriber } from './transcriber';

export type TranscriberMode = 'realtime' | 'chunked';

export interface SupervisorDeps {
  realtime: () => Transcriber;
  chunked: () => Transcriber;
  maxRealtimeFailures?: number;
}

export class TranscriberSupervisor {
  onSegment: ((s: Segment) => void) | null = null;
  onMode: ((m: TranscriberMode) => void) | null = null;
  onFailure: ((why: string) => void) | null = null;

  private current: Transcriber | null = null;
  private failures = 0;
  private mode: TranscriberMode = 'realtime';

  constructor(private readonly deps: SupervisorDeps) {}

  get activeMode(): TranscriberMode {
    return this.mode;
  }

  start(): void {
    this.stop();
    this.launch(this.failures >= (this.deps.maxRealtimeFailures ?? 2) ? 'chunked' : 'realtime');
  }

  stop(): void {
    const c = this.current;
    this.current = null;
    if (c) {
      c.onSegment = null;
      c.onFailure = null;
      c.stop();
    }
  }

  appendPcm16k(bytes: Uint8Array, role: SpeakerRole): void {
    this.current?.appendPcm16k(bytes, role);
  }

  private launch(mode: TranscriberMode): void {
    this.mode = mode;
    const t = mode === 'realtime' ? this.deps.realtime() : this.deps.chunked();
    this.current = t;
    t.onSegment = (s) => this.onSegment?.(s);
    t.onFailure = (why) => {
      this.onFailure?.(why);
      if (mode !== 'realtime' || this.current !== t) return;
      this.failures += 1;
      this.stop();
      this.launch(this.failures >= (this.deps.maxRealtimeFailures ?? 2) ? 'chunked' : 'realtime');
    };
    this.onMode?.(mode);
    t.start();
  }
}
