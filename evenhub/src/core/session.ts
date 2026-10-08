// Conversate state machine (spec §4.2 + contract 0.3). Line-for-line port of
// Android ConversateSession.kt. Pure and single-threaded: the app calls it
// from one event loop and asks for screen() after every input. Timers are
// driven by tick() against the injected clock.
import { type Cue, CueQueue } from './cue';
import type { ConversateIntent } from './intents';
import { type MenuSpec, renderLabel } from './menu';
import {
  type ConversatePrefs,
  DEFAULT_PREFS,
  type PanelKind,
  PANEL_KINDS,
  type PanelRow,
  type PrepNoteRef,
  type ScreenModel,
  type SessionEffect,
} from './screen';

export const CONFIRM_END_MILLIS = 3_000;
export const CONFIRM_GUARD_MILLIS = 400;
export const LIVE_TITLE = 'HELIX';
export const PICKER_TITLE = 'PREP NOTE';
export const SKIP_AND_START = 'Skip & start';
export const NO_PREP_NOTE = 'No prep note for this session.';
export const EMPTY_PANEL = 'Nothing here';
export const DEFAULT_MODE = 'PHONE_MIC';

type MenuKind = 'IDLE' | 'LIVE' | 'PICKER' | 'MODE' | 'DISPLAY';

/** The idle/live menu a child screen was opened from (contract 0.3 §2). */
interface Parent {
  kind: 'IDLE' | 'LIVE';
  cursor: number;
}

type Overlay =
  | { t: 'Menu'; kind: MenuKind; cursor: number; parent?: Parent }
  | { t: 'Detail'; cue: Cue; page: number }
  | { t: 'Prep'; page: number }
  | { t: 'Confirm'; until: number }
  | { t: 'Off' }
  | { t: 'Panel'; kind: PanelKind; cursor: number; parent: Parent }
  | { t: 'PanelDetail'; kind: PanelKind; cursor: number; page: number; parent: Parent }
  | { t: 'Ask'; parent: Parent };

const toMenu = (p: Parent): Overlay => ({ t: 'Menu', kind: p.kind, cursor: p.cursor });
const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));

export class ConversateSession {
  private prefs: ConversatePrefs;
  private overlay: Overlay | null = null;
  private readonly queue = new CueQueue();
  private shown: Cue | null = null;
  private shownUntil = 0;
  private captions: string[] = [];
  private prepNotes: PrepNoteRef[] = [];
  private activePrep: PrepNoteRef | null = null;
  private paused = false;
  private live = false;
  private mode = DEFAULT_MODE;
  private readonly panels = new Map<PanelKind, PanelRow[]>();

  constructor(
    private readonly menu: MenuSpec,
    private readonly clock: () => number,
    prefs: ConversatePrefs = DEFAULT_PREFS,
    private readonly detailPageCount: (cue: Cue) => number = () => 1,
    private readonly textPageCount: (text: string) => number = () => 1,
  ) {
    this.prefs = { ...DEFAULT_PREFS, ...prefs };
  }

  get isLive(): boolean {
    return this.live;
  }

  /** True while a list is open (G1 long-press means SELECT, not MENU). */
  get selectContext(): boolean {
    return this.overlay?.t === 'Menu' || this.overlay?.t === 'Panel';
  }

  /** Nothing open and no cue on screen: BACK here would leave the page. */
  get isAtRoot(): boolean {
    return this.overlay === null && this.currentShown(this.clock()) === null;
  }

  /** The Ask overlay is waiting for the next utterance (§6). */
  get isAsking(): boolean {
    return this.overlay?.t === 'Ask';
  }

  get currentPrefs(): ConversatePrefs {
    return { ...this.prefs };
  }

  get isPaused(): boolean {
    return this.paused;
  }

  get currentMode(): string {
    return this.mode;
  }

  /** Mode chosen on the phone (contract 0.3 §3). */
  setMode(id: string): void {
    this.mode = id;
  }

  setPrepNotes(notes: PrepNoteRef[]): void {
    this.prepNotes = [...notes];
  }

  /** Rows for a dashboard panel; an open panel keeps its cursor clamped (§5). */
  setPanelRows(kind: PanelKind, rows: PanelRow[]): void {
    this.panels.set(kind, rows.map((r) => ({ ...r })));
    const o = this.overlay;
    if (o?.t === 'Panel' && o.kind === kind) {
      this.overlay = { ...o, cursor: clamp(o.cursor, 0, Math.max(0, rows.length - 1)) };
    } else if (o?.t === 'PanelDetail' && o.kind === kind && o.cursor >= rows.length) {
      this.overlay = { t: 'Panel', kind, cursor: Math.max(0, rows.length - 1), parent: o.parent };
    }
  }

  panelRows(kind: PanelKind): PanelRow[] {
    return (this.panels.get(kind) ?? []).map((r) => ({ ...r }));
  }

  /** Which panel is open (for refreshes), or null. */
  get openPanel(): PanelKind | null {
    const o = this.overlay;
    return o?.t === 'Panel' || o?.t === 'PanelDetail' ? o.kind : null;
  }

  updatePrefs(prefs: ConversatePrefs): void {
    this.prefs = { ...DEFAULT_PREFS, ...prefs };
    if (!prefs.cuesOn) {
      this.queue.clear();
      this.shown = null;
    }
  }

  setPaused(paused: boolean): void {
    this.paused = paused;
  }

  startLive(prepNoteId: string | null): SessionEffect[] {
    this.live = true;
    this.paused = false;
    this.activePrep = this.prepNotes.find((n) => n.id === prepNoteId) ?? null;
    this.queue.clear();
    this.shown = null;
    this.captions = [];
    this.overlay = null;
    return [{ type: 'Start', prepNoteId }];
  }

  endLive(): SessionEffect[] {
    this.live = false;
    this.queue.clear();
    this.shown = null;
    this.captions = [];
    this.overlay = null;
    this.activePrep = null;
    return [{ type: 'End' }];
  }

  onCaptionLines(lines: string[]): void {
    this.captions = [...lines];
  }

  onCue(cue: Cue): void {
    if (!this.live || !this.prefs.cuesOn) return;
    const now = this.clock();
    const current = this.currentShown(now);
    if (cue.type === 'ANSWER' && current !== null && current.type !== 'ANSWER') {
      this.queue.offer(current, now);
      this.show(cue, now);
      return;
    }
    this.queue.offer(cue, now);
    this.promote(now);
  }

  /** Feeds the utterance heard while Ask is listening (§6). */
  onAskText(text: string): SessionEffect[] {
    const q = text.trim();
    if (this.overlay?.t !== 'Ask' || q === '') return [];
    this.overlay = null;
    this.promote(this.clock());
    return [{ type: 'AskQuestion', text: q }];
  }

  /** Shows an answer as a cue detail overlay (not live / display-only, §6). */
  showAnswer(cue: Cue): void {
    this.overlay = { t: 'Detail', cue, page: 0 };
  }

  tick(): void {
    const now = this.clock();
    const o = this.overlay;
    if (o?.t === 'Confirm' && now > o.until) this.overlay = null;
    if (this.shown !== null && now >= this.shownUntil) this.shown = null;
    this.promote(now);
  }

  /** Applies [intent]; afterwards a waiting cue may surface (e.g. once a menu closes). */
  onIntent(intent: ConversateIntent): SessionEffect[] {
    const effects = this.handle(intent);
    this.promote(this.clock());
    return effects;
  }

  /**
   * G2 native contextual menu: the OS picks an item directly (no cursor).
   * Activates the idle/live menu item [id] as if the in-app cursor were on
   * it, replacing any open in-app overlay. Ids not in the current context are
   * ignored.
   */
  activateMenuItem(id: string): SessionEffect[] {
    const kind: MenuKind = this.live ? 'LIVE' : 'IDLE';
    const items = kind === 'IDLE' ? this.menu.idle : this.menu.live;
    const cursor = items.findIndex((i) => i.id === id);
    if (cursor < 0) return [];
    const effects: SessionEffect[] = this.overlay?.t === 'Ask' ? [{ type: 'AskCancel' }] : [];
    if (this.overlay !== null && this.overlay.t !== 'Confirm') this.overlay = null;
    effects.push(...this.activate({ t: 'Menu', kind, cursor }));
    this.promote(this.clock());
    return effects;
  }

  private handle(intent: ConversateIntent): SessionEffect[] {
    // No head-up dashboard yet: head movement must not act as a tap.
    if (intent === 'HEAD_UP' || intent === 'HEAD_DOWN') return [];
    const now = this.clock();
    const o = this.overlay;
    if (o !== null) {
      switch (o.t) {
        case 'Off':
          this.overlay = null;
          return [];
        case 'Menu':
          return this.onMenuIntent(o, intent);
        case 'Detail':
          switch (intent) {
            case 'NEXT': this.overlay = { ...o, page: Math.min(o.page + 1, this.detailPageCount(o.cue) - 1) }; break;
            case 'PREV': this.overlay = { ...o, page: Math.max(o.page - 1, 0) }; break;
            case 'BACK': this.overlay = null; this.shown = null; this.promote(now); break;
            case 'MENU': this.overlay = { t: 'Menu', kind: this.live ? 'LIVE' : 'IDLE', cursor: 0 }; break;
            default: break;
          }
          return [];
        case 'Prep': {
          const text = this.activePrep?.text ?? NO_PREP_NOTE;
          switch (intent) {
            case 'NEXT': this.overlay = { ...o, page: Math.min(o.page + 1, this.textPageCount(text) - 1) }; break;
            case 'PREV': this.overlay = { ...o, page: Math.max(o.page - 1, 0) }; break;
            case 'BACK': this.overlay = null; break;
            case 'MENU': this.overlay = { t: 'Menu', kind: 'LIVE', cursor: 0 }; break;
            default: break;
          }
          return [];
        }
        case 'Panel':
          return this.onPanelIntent(o, intent);
        case 'PanelDetail': {
          const row = this.panelRows(o.kind)[o.cursor];
          const count = row ? this.textPageCount(`${row.title}\n${row.detail}`) : 1;
          switch (intent) {
            case 'NEXT': this.overlay = { ...o, page: Math.min(o.page + 1, count - 1) }; break;
            case 'PREV': this.overlay = { ...o, page: Math.max(o.page - 1, 0) }; break;
            case 'BACK':
            case 'MENU':
              this.overlay = { t: 'Panel', kind: o.kind, cursor: o.cursor, parent: o.parent };
              break;
            default: break;
          }
          return [];
        }
        case 'Ask':
          if (intent === 'BACK' || intent === 'MENU') {
            this.overlay = toMenu(o.parent);
            return [{ type: 'AskCancel' }];
          }
          return [];
        case 'Confirm':
          // Ignore a BACK that is really the same double-tap echoed.
          if (intent === 'BACK' && now < o.until - CONFIRM_END_MILLIS + CONFIRM_GUARD_MILLIS) return [];
          if (intent === 'BACK') return this.endLive();
          this.overlay = null;
          return [];
      }
    }
    if (intent === 'MENU') {
      this.overlay = { t: 'Menu', kind: this.live ? 'LIVE' : 'IDLE', cursor: 0 };
      return [];
    }
    if (!this.live) return [];
    const current = this.currentShown(now);
    switch (intent) {
      case 'NEXT':
      case 'SELECT':
        if (current !== null) this.overlay = { t: 'Detail', cue: current, page: 0 };
        else {
          const next = this.queue.poll(now);
          if (next) this.show(next, now);
        }
        break;
      case 'PREV':
        if (current !== null) { this.shown = null; this.promote(now); }
        break;
      case 'BACK':
        if (current !== null) { this.shown = null; this.promote(now); }
        else this.overlay = { t: 'Confirm', until: now + CONFIRM_END_MILLIS };
        break;
      default:
        break;
    }
    return [];
  }

  screen(): ScreenModel {
    const now = this.clock();
    const o = this.overlay;
    if (o === null) return this.liveScreen(now);
    switch (o.t) {
      case 'Off': return { kind: 'Blank' };
      case 'Menu': return { kind: 'Menu', title: this.menuTitle(o.kind), items: this.menuLabels(o.kind), cursor: o.cursor };
      case 'Detail': return { kind: 'CueDetail', cue: o.cue, page: o.page };
      case 'Prep':
        return { kind: 'PrepNoteView', title: this.activePrep?.title ?? PICKER_TITLE, text: this.activePrep?.text ?? NO_PREP_NOTE, page: o.page };
      case 'Confirm': return { kind: 'ConfirmEnd' };
      case 'Panel': return { kind: 'Panel', title: this.panelTitle(o.kind), items: this.panelLabels(o.kind), cursor: o.cursor };
      case 'PanelDetail': {
        const row = this.panels.get(o.kind)?.[o.cursor];
        return { kind: 'PanelDetail', title: row?.title ?? this.panelTitle(o.kind), text: row?.detail ?? '', page: o.page };
      }
      case 'Ask': return { kind: 'Ask' };
    }
  }

  private liveScreen(now: number): ScreenModel {
    if (!this.live) return { kind: 'Blank' };
    const cue = this.currentShown(now);
    const pending = cue === null && !this.prefs.autoPopup ? this.queue.count(now) : 0;
    if (!this.paused && cue === null && pending === 0 && !this.prefs.captionsOn) return { kind: 'Blank' };
    return { kind: 'Live', cue, pendingCount: pending, captionLines: [...this.captions], captionsOn: this.prefs.captionsOn, paused: this.paused };
  }

  private onMenuIntent(o: Extract<Overlay, { t: 'Menu' }>, intent: ConversateIntent): SessionEffect[] {
    const labels = this.menuLabels(o.kind);
    switch (intent) {
      case 'NEXT': this.overlay = { ...o, cursor: Math.min(o.cursor + 1, labels.length - 1) }; break;
      case 'PREV': this.overlay = { ...o, cursor: Math.max(o.cursor - 1, 0) }; break;
      case 'BACK':
      case 'MENU':
        if (o.parent) this.overlay = toMenu(o.parent);
        else this.overlay = o.kind === 'PICKER' ? { t: 'Menu', kind: 'IDLE', cursor: 0 } : null;
        break;
      case 'SELECT': return this.activate(o);
      default: break;
    }
    return [];
  }

  private onPanelIntent(o: Extract<Overlay, { t: 'Panel' }>, intent: ConversateIntent): SessionEffect[] {
    const rows = this.panels.get(o.kind) ?? [];
    switch (intent) {
      case 'NEXT': this.overlay = { ...o, cursor: Math.min(o.cursor + 1, Math.max(0, rows.length - 1)) }; break;
      case 'PREV': this.overlay = { ...o, cursor: Math.max(o.cursor - 1, 0) }; break;
      case 'BACK':
      case 'MENU':
        this.overlay = toMenu(o.parent);
        break;
      case 'SELECT': {
        const row = rows[o.cursor];
        if (!row) return [];
        if (o.kind === 'todos') {
          row.done = !(row.done ?? false);
          return [{ type: 'ToggleTodo', id: row.id, done: row.done }];
        }
        this.overlay = { t: 'PanelDetail', kind: o.kind, cursor: o.cursor, page: 0, parent: o.parent };
        break;
      }
      default: break;
    }
    return [];
  }

  private activate(o: Extract<Overlay, { t: 'Menu' }>): SessionEffect[] {
    switch (o.kind) {
      case 'PICKER': {
        const note = o.cursor === 0 ? null : this.prepNotes[o.cursor - 1] ?? null;
        return this.startLive(note?.id ?? null);
      }
      case 'MODE': {
        const item = this.menu.pickers.mode.items[o.cursor];
        if (!item) return [];
        this.mode = item.id;
        this.overlay = o.parent ? toMenu(o.parent) : null;
        return [{ type: 'SetMode', mode: item.id }];
      }
      case 'DISPLAY':
        return this.cycleDisplay(o.cursor);
      default:
        break;
    }
    const parent: Parent = { kind: o.kind, cursor: o.cursor };
    const items = o.kind === 'IDLE' ? this.menu.idle : this.menu.live;
    const id = items[o.cursor]?.id;
    if (id !== undefined && (PANEL_KINDS as readonly string[]).includes(id)) {
      const kind = id as PanelKind;
      this.overlay = { t: 'Panel', kind, cursor: 0, parent };
      return [{ type: 'RequestPanel', kind }];
    }
    switch (id) {
      case 'start':
        if (this.prepNotes.length === 0) return this.startLive(null);
        this.overlay = { t: 'Menu', kind: 'PICKER', cursor: 0 };
        return [];
      case 'ask':
        this.overlay = { t: 'Ask', parent };
        return [{ type: 'AskListen' }];
      case 'mode': {
        const cursor = Math.max(0, this.menu.pickers.mode.items.findIndex((i) => i.id === this.mode));
        this.overlay = { t: 'Menu', kind: 'MODE', cursor, parent };
        return [];
      }
      case 'display':
        this.overlay = { t: 'Menu', kind: 'DISPLAY', cursor: 0, parent };
        return [];
      case 'pause':
        this.paused = !this.paused;
        return [{ type: 'SetPaused', paused: this.paused }];
      case 'captions':
        this.prefs = { ...this.prefs, captionsOn: !this.prefs.captionsOn };
        return [{ type: 'SetCaptions', on: this.prefs.captionsOn }];
      case 'cues':
        this.updatePrefs({ ...this.prefs, cuesOn: !this.prefs.cuesOn });
        return [{ type: 'SetCues', on: this.prefs.cuesOn }];
      case 'prep_note':
        this.overlay = { t: 'Prep', page: 0 };
        return [];
      case 'display_off':
        this.overlay = { t: 'Off' };
        return [];
      case 'end':
        return this.endLive();
      default:
        return [];
    }
  }

  /** SELECT in the display picker: next value in `values`, wrapping (§4). */
  private cycleDisplay(cursor: number): SessionEffect[] {
    const item = this.menu.pickers.display.items[cursor];
    const values = item?.values ?? [];
    if (!item || values.length === 0) return [];
    const current = this.displayValue(item.id);
    const at = values.indexOf(current);
    let next: number | string;
    if (at >= 0) next = values[(at + 1) % values.length]!;
    else if (typeof current === 'number') next = values.find((v) => typeof v === 'number' && v > current) ?? values[0]!;
    else next = values[0]!;
    switch (item.id) {
      case 'captionLines': this.prefs = { ...this.prefs, captionLines: Number(next) }; break;
      case 'cueSeconds': this.prefs = { ...this.prefs, cueDurationMillis: Number(next) * 1000 }; break;
      case 'brightness': this.prefs = { ...this.prefs, brightness: Number(next) }; break;
      case 'captions': this.prefs = { ...this.prefs, captionsOn: next === 'on' }; break;
      default: return [];
    }
    return [{ type: 'SetPref', id: item.id, value: next }];
  }

  private displayValue(id: string): number | string {
    switch (id) {
      case 'captionLines': return this.prefs.captionLines;
      case 'cueSeconds': return Math.round(this.prefs.cueDurationMillis / 1000);
      case 'brightness': return this.prefs.brightness;
      case 'captions': return this.prefs.captionsOn ? 'on' : 'off';
      default: return '';
    }
  }

  private panelTitle(kind: PanelKind): string {
    return this.menu.panels[kind]?.title ?? kind.toUpperCase();
  }

  private panelLabels(kind: PanelKind): string[] {
    const rows = this.panels.get(kind) ?? [];
    if (rows.length === 0) return [EMPTY_PANEL];
    return rows.map((r) => (kind === 'todos' ? `[${r.done ? 'x' : ' '}] ${r.title}` : r.title));
  }

  private menuTitle(kind: MenuKind): string {
    switch (kind) {
      case 'PICKER': return PICKER_TITLE;
      case 'MODE': return this.menu.pickers.mode.title;
      case 'DISPLAY': return this.menu.pickers.display.title;
      default: return LIVE_TITLE;
    }
  }

  private menuLabels(kind: MenuKind): string[] {
    const flags = { paused: this.paused, captions: this.prefs.captionsOn, cues: this.prefs.cuesOn };
    switch (kind) {
      case 'IDLE': return this.menu.idle.map((i) => renderLabel(i, flags));
      case 'LIVE': return this.menu.live.map((i) => renderLabel(i, flags));
      case 'PICKER': return [SKIP_AND_START, ...this.prepNotes.map((n) => n.title)];
      case 'MODE': return this.menu.pickers.mode.items.map((i) => i.label);
      case 'DISPLAY':
        return this.menu.pickers.display.items.map((i) => i.label.replace('{v}', String(this.displayValue(i.id))));
    }
  }

  private currentShown(now: number): Cue | null {
    return this.shown !== null && now < this.shownUntil ? this.shown : null;
  }

  private show(cue: Cue, now: number): void {
    this.shown = cue;
    this.shownUntil = now + this.prefs.cueDurationMillis;
  }

  private promote(now: number): void {
    if (this.overlay !== null || !this.prefs.autoPopup || this.currentShown(now) !== null) return;
    const next = this.queue.poll(now);
    if (next) this.show(next, now);
  }
}
