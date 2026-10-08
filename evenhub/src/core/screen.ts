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
  | { kind: 'ConfirmEnd' }
  | { kind: 'Panel'; title: string; items: string[]; cursor: number }
  | { kind: 'PanelDetail'; title: string; text: string; page: number }
  | { kind: 'Ask' };

export type ScreenKind = ScreenModel['kind'];

/** Screens the wearer opened. */
export function isInteractive(s: ScreenModel): boolean {
  return (
    s.kind === 'CueDetail' || s.kind === 'Menu' || s.kind === 'PrepNoteView' || s.kind === 'ConfirmEnd' ||
    s.kind === 'Panel' || s.kind === 'PanelDetail' || s.kind === 'Ask'
  );
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
  /** Caption rows drawn in Live (contract 0.3 §4), 2..5. */
  captionLines: number;
  /** HUD brightness level 1..4 (G2: text `textColor`). */
  brightness: number;
}

export const DEFAULT_PREFS: ConversatePrefs = {
  captionsOn: true,
  cuesOn: true,
  autoPopup: true,
  cueDurationMillis: 6_000,
  captionLines: 5,
  brightness: 3,
};

/** Dashboard panel kinds (contract 0.3 §5). */
export type PanelKind = 'news' | 'x' | 'todos' | 'omi';
export const PANEL_KINDS: readonly PanelKind[] = ['news', 'x', 'todos', 'omi'];

export interface PanelRow {
  id: string;
  title: string;
  detail: string;
  done?: boolean;
}

export type SessionEffect =
  | { type: 'Start'; prepNoteId: string | null }
  | { type: 'End' }
  | { type: 'SetPaused'; paused: boolean }
  | { type: 'SetCaptions'; on: boolean }
  | { type: 'SetCues'; on: boolean }
  | { type: 'SetMode'; mode: string }
  | { type: 'SetPref'; id: string; value: number | string }
  | { type: 'RequestPanel'; kind: PanelKind }
  | { type: 'ToggleTodo'; id: string; done: boolean }
  | { type: 'AskListen' }
  | { type: 'AskCancel' }
  | { type: 'AskQuestion'; text: string };

/** ASCII-only glyphs (same set as Android) until G2 font coverage is checked. */
export const HudGlyphs = {
  CUE: '*',
  CURSOR: '>',
  MORE: '>>',
  RULE: '- - - - - - - - - -',
  PAUSED: '||',
} as const;
