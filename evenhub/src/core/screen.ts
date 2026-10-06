// What Conversate wants on the lens, independent of device (spec §4.2).
// Port of Android ScreenModel.kt; `kind` equals the Kotlin class simpleName so
// the shared vectors' `expect.kind` compares directly.
import type { Cue } from './cue';

export type ScreenModel =
  | { kind: 'Blank' }
  | { kind: 'Live'; cue: Cue | null; pendingCount: number; captionLines: string[]; captionsOn: boolean; paused: boolean }
  | { kind: 'CueDetail'; cue: Cue; page: number }
  | { kind: 'Menu'; title: string; items: string[]; cursor: number }
  | { kind: 'PrepNoteView'; title: string; text: string; page: number }
  | { kind: 'ConfirmEnd' };

export type ScreenKind = ScreenModel['kind'];

/** Screens the wearer opened. */
export function isInteractive(s: ScreenModel): boolean {
  return s.kind === 'CueDetail' || s.kind === 'Menu' || s.kind === 'PrepNoteView' || s.kind === 'ConfirmEnd';
}

export interface PrepNoteRef {
  id: string;
  title: string;
  text: string;
}

export interface ConversatePrefs {
  captionsOn: boolean;
  cuesOn: boolean;
  autoPopup: boolean;
  cueDurationMillis: number;
}

export const DEFAULT_PREFS: ConversatePrefs = {
  captionsOn: true,
  cuesOn: true,
  autoPopup: true,
  cueDurationMillis: 6_000,
};

export type SessionEffect =
  | { type: 'Start'; prepNoteId: string | null }
  | { type: 'End' }
  | { type: 'SetPaused'; paused: boolean }
  | { type: 'SetCaptions'; on: boolean }
  | { type: 'SetCues'; on: boolean };

/** ASCII-only glyphs (same set as Android) until G2 font coverage is checked. */
export const HudGlyphs = {
  CUE: '*',
  CURSOR: '>',
  MORE: '>>',
  RULE: '- - - - - - - - - -',
  PAUSED: '||',
} as const;
