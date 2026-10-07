// Conversate state machine (spec §4.2). Line-for-line port of Android
// ConversateSession.kt. Pure and single-threaded: the app calls it from one
// event loop and asks for screen() after every input. Timers are driven by
// tick() against the injected clock.
import { type Cue, CueQueue } from './cue';
import type { ConversateIntent } from './intents';
import { type MenuSpec, renderLabel } from './menu';
import { type ConversatePrefs, DEFAULT_PREFS, type PrepNoteRef, type ScreenModel, type SessionEffect } from './screen';

export const CONFIRM_END_MILLIS = 3_000;
export const CONFIRM_GUARD_MILLIS = 400;
export const LIVE_TITLE = 'HELIX';
export const PICKER_TITLE = 'PREP NOTE';
export const SKIP_AND_START = 'Skip & start';
export const NO_PREP_NOTE = 'No prep note for this session.';

type MenuKind = 'IDLE' | 'LIVE' | 'PICKER';

type Overlay =
  | { t: 'Menu'; kind: MenuKind; cursor: number }
  | { t: 'Detail'; cue: Cue; page: number }
  | { t: 'Prep'; page: number }
  | { t: 'Confirm'; until: number }
  | { t: 'Off' };

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

  constructor(
    private readonly menu: MenuSpec,
    private readonly clock: () => number,
    prefs: ConversatePrefs = DEFAULT_PREFS,
    private readonly detailPageCount: (cue: Cue) => number = () => 1,
    private readonly textPageCount: (text: string) => number = () => 1,
  ) {
    this.prefs = { ...prefs };
  }

  get isLive(): boolean {
    return this.live;
  }

  /** True while a list is open (G1 long-press means SELECT, not MENU). */
  get selectContext(): boolean {
    return this.overlay?.t === 'Menu';
  }

  /** Nothing open and no cue on screen: BACK here would leave the page. */
  get isAtRoot(): boolean {
    return this.overlay === null && this.currentShown(this.clock()) === null;
  }

  get currentPrefs(): ConversatePrefs {
    return { ...this.prefs };
  }

  get isPaused(): boolean {
    return this.paused;
  }

  setPrepNotes(notes: PrepNoteRef[]): void {
    this.prepNotes = [...notes];
  }

  updatePrefs(prefs: ConversatePrefs): void {
    this.prefs = { ...prefs };
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
   * it, replacing any open in-app menu. Ids not in the current context are
   * ignored.
   */
  activateMenuItem(id: string): SessionEffect[] {
    const kind: MenuKind = this.live ? 'LIVE' : 'IDLE';
    const items = kind === 'IDLE' ? this.menu.idle : this.menu.live;
    const cursor = items.findIndex((i) => i.id === id);
    if (cursor < 0) return [];
    if (this.overlay?.t === 'Menu' || this.overlay?.t === 'Off') this.overlay = null;
    const effects = this.activate({ t: 'Menu', kind, cursor });
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
            case 'MENU': this.overlay = { t: 'Menu', kind: 'LIVE', cursor: 0 }; break;
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
        this.overlay = o.kind === 'PICKER' ? { t: 'Menu', kind: 'IDLE', cursor: 0 } : null;
        break;
      case 'SELECT': return this.activate(o);
      default: break;
    }
    return [];
  }

  private activate(o: Extract<Overlay, { t: 'Menu' }>): SessionEffect[] {
    if (o.kind === 'PICKER') {
      const note = o.cursor === 0 ? null : this.prepNotes[o.cursor - 1] ?? null;
      return this.startLive(note?.id ?? null);
    }
    const items = o.kind === 'IDLE' ? this.menu.idle : this.menu.live;
    switch (items[o.cursor]?.id) {
      case 'start':
        if (this.prepNotes.length === 0) return this.startLive(null);
        this.overlay = { t: 'Menu', kind: 'PICKER', cursor: 0 };
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

  private menuTitle(kind: MenuKind): string {
    return kind === 'PICKER' ? PICKER_TITLE : LIVE_TITLE;
  }

  private menuLabels(kind: MenuKind): string[] {
    const flags = { paused: this.paused, captions: this.prefs.captionsOn, cues: this.prefs.cuesOn };
    switch (kind) {
      case 'IDLE': return this.menu.idle.map((i) => renderLabel(i, flags));
      case 'LIVE': return this.menu.live.map((i) => renderLabel(i, flags));
      case 'PICKER': return [SKIP_AND_START, ...this.prepNotes.map((n) => n.title)];
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
