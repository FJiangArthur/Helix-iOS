// OpenAI Realtime transcription over a browser WebSocket (GA interface,
// checked against developers.openai.com 2026-10-05): connect, send
// `session.update` with `session.type = "transcription"`, stream
// `input_audio_buffer.append` (base64 24 kHz pcm16), receive
// `conversation.item.input_audio_transcription.delta|completed`.
import { bytesToBase64, bytesToPcm16, pcm16ToBytes, Resampler16kTo24k } from './pcm';
import { RoleTimeline, SegmentAssembler, type Segment, type SpeakerRole } from './segments';
import type { Transcriber } from './transcriber';

export const REALTIME_URL = 'wss://api.openai.com/v1/realtime?intent=transcription';

/** Browser WebSockets cannot set headers; the key travels as a subprotocol. */
export function realtimeProtocols(apiKey: string): string[] {
  return ['realtime', `openai-insecure-api-key.${apiKey}`];
}

export function realtimeSessionUpdate(model: string) {
  return {
    type: 'session.update',
    session: {
      type: 'transcription',
      audio: {
        input: {
          format: { type: 'audio/pcm', rate: 24000 },
          transcription: { model, language: 'en' },
          turn_detection: { type: 'server_vad', threshold: 0.5, prefix_padding_ms: 300, silence_duration_ms: 500 },
          noise_reduction: null,
        },
      },
    },
  };
}

/** The subset of WebSocket we use (injectable for tests). */
export interface SocketLike {
  readyState: number;
  onopen: (() => void) | null;
  onmessage: ((ev: { data: unknown }) => void) | null;
  onerror: ((ev: unknown) => void) | null;
  onclose: ((ev: { code: number; reason: string }) => void) | null;
  send(data: string): void;
  close(): void;
}

export interface RealtimeOptions {
  apiKey: string;
  model: string;
  socketFactory?: (url: string, protocols: string[]) => SocketLike;
}

const OPEN = 1;
const MAX_PENDING_FRAMES = 50; // ~5 s of 100 ms frames while connecting

export class RealtimeTranscriber implements Transcriber {
  onSegment: ((s: Segment) => void) | null = null;
  onFailure: ((why: string) => void) | null = null;

  private socket: SocketLike | null = null;
  private readonly resampler = new Resampler16kTo24k();
  private readonly roles = new RoleTimeline();
  private readonly assembler = new SegmentAssembler(this.roles, (s) => this.onSegment?.(s));
  private pending: string[] = [];
  private failed = false;
  private stopped = false;

  constructor(private readonly opts: RealtimeOptions) {}

  start(): void {
    this.stopped = false;
    this.failed = false;
    const factory = this.opts.socketFactory ?? ((url, protocols) => new WebSocket(url, protocols) as unknown as SocketLike);
    const s = factory(REALTIME_URL, realtimeProtocols(this.opts.apiKey));
    this.socket = s;
    s.onopen = () => {
      s.send(JSON.stringify(realtimeSessionUpdate(this.opts.model)));
      for (const m of this.pending) s.send(m);
      this.pending = [];
    };
    s.onmessage = (ev) => {
      let e: Record<string, unknown>;
      try {
        e = JSON.parse(String(ev.data));
      } catch {
        return;
      }
      if (e.type === 'error') {
        const err = e.error as { message?: string } | undefined;
        this.fail(err?.message ?? 'error');
        return;
      }
      this.assembler.onServerEvent(e);
    };
    s.onerror = () => this.fail('socket error');
    s.onclose = (ev) => this.fail(`closed ${ev.code}`);
  }

  stop(): void {
    this.stopped = true;
    this.pending = [];
    this.assembler.reset();
    this.roles.reset();
    this.resampler.reset();
    const s = this.socket;
    this.socket = null;
    s?.close();
  }

  appendPcm16k(bytes: Uint8Array, role: SpeakerRole): void {
    if (this.stopped || this.failed) return;
    const samples = bytesToPcm16(bytes);
    this.roles.add((samples.length / 16000) * 1000, role);
    const out = this.resampler.process(samples);
    if (out.length === 0) return;
    const msg = JSON.stringify({ type: 'input_audio_buffer.append', audio: bytesToBase64(pcm16ToBytes(out)) });
    if (this.socket?.readyState === OPEN) this.socket.send(msg);
    else {
      this.pending.push(msg);
      if (this.pending.length > MAX_PENDING_FRAMES) this.pending.shift();
    }
  }

  private fail(why: string): void {
    if (this.stopped || this.failed) return;
    this.failed = true;
    this.onFailure?.(why);
  }
}
