// Device-neutral input for Conversate (spec §4.1). Port of Android
// ConversateIntent.kt: every device maps raw gestures to these intents.

export type ConversateIntent = 'NEXT' | 'PREV' | 'SELECT' | 'BACK' | 'MENU' | 'HEAD_UP' | 'HEAD_DOWN';

export const INTENTS: readonly ConversateIntent[] = ['NEXT', 'PREV', 'SELECT', 'BACK', 'MENU', 'HEAD_UP', 'HEAD_DOWN'];

/** G2_TOUCHPAD is G2-only (Hub temple touch); R1 is the ring on either device. */
export type IntentSource = 'G1_TOUCHPAD' | 'R1' | 'PHONE' | 'G2_TOUCHPAD';

/** Drops the same intent arriving from a different source within [windowMillis]. */
export class IntentDeduper {
  private lastIntent: ConversateIntent | null = null;
  private lastSource: IntentSource | null = null;
  private lastAt = Number.MIN_SAFE_INTEGER / 2;

  constructor(private readonly clock: () => number, private readonly windowMillis = 250) {}

  accept(intent: ConversateIntent, source: IntentSource): boolean {
    const now = this.clock();
    const duplicate = intent === this.lastIntent && source !== this.lastSource && now - this.lastAt < this.windowMillis;
    if (duplicate) return false;
    this.lastIntent = intent;
    this.lastSource = source;
    this.lastAt = now;
    return true;
  }
}
