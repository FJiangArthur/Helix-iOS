import type { Segment, SpeakerRole } from './segments';

/** Common shape of the realtime and chunked transcribers. */
export interface Transcriber {
  onSegment: ((s: Segment) => void) | null;
  onFailure: ((why: string) => void) | null;
  start(): void;
  stop(): void;
  /** One Even Hub audio frame: 16 kHz s16le mono. */
  appendPcm16k(bytes: Uint8Array, role: SpeakerRole): void;
}

export const DEFAULT_TRANSCRIBE_MODEL = 'gpt-4o-mini-transcribe';
