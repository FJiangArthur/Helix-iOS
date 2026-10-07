// App controller: the only thing that touches the Even Hub bridge. Wires
// session <-> renderer <-> transcriber <-> cue/answer engines. Single-threaded
// (browser event loop), like the Android ConversateController.
import {
  AudioInputSource,
  type AudioSpeakerRole,
  CreateStartUpPageContainer,
  type EvenHubEvent,
  type RebuildPageContainer,
  StartUpPageCreateResult,
  type TextContainerUpgrade,
} from '@evenrealities/even_hub_sdk';
import { AnswerEngine } from './ai/answers';
import { CueEngine } from './ai/cueEngine';
import { openaiAnswer, openaiClassify } from './ai/openai';
import { ChunkedTranscriber } from './audio/chunked';
import { RealtimeTranscriber } from './audio/realtime';
import type { Segment, SpeakerRole } from './audio/segments';
import { type TranscriberMode, TranscriberSupervisor } from './audio/supervisor';
import { DEFAULT_TRANSCRIBE_MODEL } from './audio/transcriber';
import { CaptionBuffer, wrapText } from './core/captionBuffer';
import type { Cue } from './core/cue';
import { loadCuePrompt } from './core/cuePrompt';
import { type ConversateIntent, IntentDeduper, type IntentSource } from './core/intents';
import { loadMenu } from './core/menu';
import { type ConversatePrefs, DEFAULT_PREFS, type PrepNoteRef, type SessionEffect } from './core/screen';
import { ConversateSession } from './core/session';
import { buildContextMenu } from './g2/contextMenu';
import { InputAdapter } from './g2/input';
import { detailPageCount, FULL_LINES, LINE_CHARS, renderPage, type RenderResult, textPageCount } from './g2/render';
import { KEYS, type KeyValueStore, parseJson, PREP_NOTE_MAX_CHARS, sanitizePrepNotes } from './storage';

/** The subset of EvenAppBridge the app uses (EvenAppBridge satisfies it). */
export interface HubBridge {
  createStartUpPageContainer(c: CreateStartUpPageContainer): Promise<StartUpPageCreateResult>;
  rebuildPageContainer(c: RebuildPageContainer): Promise<boolean>;
  textContainerUpgrade(c: TextContainerUpgrade): Promise<boolean>;
  audioControl(isOpen: boolean, source?: AudioInputSource): Promise<boolean>;
  shutDownPageContainer(exitMode?: number): Promise<boolean>;
  onEvenHubEvent(cb: (e: EvenHubEvent) => void): () => void;
}

export interface AppTranscriber {
  onSegment: ((s: Segment) => void) | null;
  onMode?: ((m: TranscriberMode) => void) | null;
  start(): void;
  stop(): void;
  appendPcm16k(bytes: Uint8Array, role: SpeakerRole): void;
}

export interface AppDeps {
  bridge: HubBridge | null;
  store: KeyValueStore;
  clock?: () => number;
  makeTranscriber?: (apiKey: string) => AppTranscriber;
  classify?: (apiKey: string, prompt: string, maxTokens: number) => Promise<string>;
  answer?: (apiKey: string, question: string, context: string) => Promise<string>;
}

export type AudioSourceChoice = 'glasses' | 'phone';

export interface AppState {
  live: boolean;
  paused: boolean;
  hasKey: boolean;
  needsKey: boolean;
  foreground: boolean;
  audioOn: boolean;
  transcriberMode: TranscriberMode | null;
  cueFailures: number;
  prefs: ConversatePrefs;
  prepNotes: PrepNoteRef[];
  audioSource: AudioSourceChoice;
  preview: string;
  lastError: string | null;
}

export const TICK_MILLIS = 250;
export const CAPTION_UPGRADE_GAP_MILLIS = 300;
export const NEEDS_KEY_LINES = ['Add your OpenAI key in', 'Helix Live on your phone'];

/** Idle home page: first launch must explain what to do, never show a black screen. */
export function idleHint(hasKey: boolean): string {
  return hasKey
    ? 'Helix Live\n\nHold the touchpad or R1 ring\nto start a session.\n\nDouble-tap to exit.'
    : 'Helix Live\n\n' + NEEDS_KEY_LINES.join('\n') + '.\n\nDouble-tap to exit.';
}

function defaultTranscriber(apiKey: string): AppTranscriber {
  const sup = new TranscriberSupervisor({
    realtime: () => new RealtimeTranscriber({ apiKey, model: DEFAULT_TRANSCRIBE_MODEL }),
    chunked: () => new ChunkedTranscriber({ apiKey, model: DEFAULT_TRANSCRIBE_MODEL }),
  });
  return sup;
}

export class App {
  private readonly clock: () => number;
  private readonly menu = loadMenu();
  private readonly session: ConversateSession;
  private readonly captions = new CaptionBuffer((t) => wrapText(t, LINE_CHARS), FULL_LINES);
  private readonly deduper: IntentDeduper;
  private readonly input: InputAdapter;
  private readonly cues: CueEngine;
  private readonly answers: AnswerEngine;
  private apiKey: string | null = null;
  private transcriber: AppTranscriber | null = null;
  private unsubscribe: (() => void) | null = null;
  private ticker: ReturnType<typeof setInterval> | null = null;
  private listeners = new Set<(s: AppState) => void>();

  // render pipeline
  private created = false;
  private lastRendered: RenderResult | null = null;
  private rendering = false;
  private dirty = false;
  private dirtyUrgent = false;
  private throttle: ReturnType<typeof setTimeout> | null = null;
  private lastUpgradeAt = Number.MIN_SAFE_INTEGER / 2;

  state: AppState = {
    live: false,
    paused: false,
    hasKey: false,
    needsKey: false,
    foreground: true,
    audioOn: false,
    transcriberMode: null,
    cueFailures: 0,
    prefs: { ...DEFAULT_PREFS },
    prepNotes: [],
    audioSource: 'glasses',
    preview: '',
    lastError: null,
  };

  constructor(private readonly deps: AppDeps) {
    this.clock = deps.clock ?? (() => Date.now());
    this.session = new ConversateSession(this.menu, this.clock, DEFAULT_PREFS, detailPageCount, textPageCount);
    this.deduper = new IntentDeduper(this.clock);
    this.input = new InputAdapter(this.clock);
    const classify = deps.classify ?? ((key, prompt, max) => openaiClassify(key, prompt, max));
    const answer = deps.answer ?? ((key, q, ctx) => openaiAnswer(key, q, ctx, 3));
    this.cues = new CueEngine({
      classify: (prompt, max) => (this.apiKey ? classify(this.apiKey, prompt, max) : Promise.reject(new Error('no key'))),
      prompt: loadCuePrompt(),
      clock: this.clock,
      emit: (cue) => this.onCue(cue),
    });
    this.answers = new AnswerEngine({
      answer: (q) => (this.apiKey ? answer(this.apiKey, q, this.cues.recentText()) : Promise.reject(new Error('no key'))),
      clock: this.clock,
      nextId: () => this.cues.nextCueId(),
      emit: (cue) => this.onCue(cue),
    });
  }

  // ---- lifecycle -------------------------------------------------------

  async init(): Promise<void> {
    const { store } = this.deps;
    this.apiKey = (await store.get(KEYS.apiKey))?.trim() || null;
    const prefs = { ...DEFAULT_PREFS, ...parseJson<Partial<ConversatePrefs>>(await store.get(KEYS.prefs), {}) };
    const notes = sanitizePrepNotes(parseJson<unknown>(await store.get(KEYS.prepNotes), []));
    const source = (await store.get(KEYS.audioSource)) === 'phone' ? 'phone' : 'glasses';
    this.session.updatePrefs(prefs);
    this.session.setPrepNotes(notes);
    this.patch({ prefs, prepNotes: notes, audioSource: source, hasKey: this.apiKey !== null });
    this.unsubscribe = this.deps.bridge?.onEvenHubEvent((e) => this.onHubEvent(e)) ?? null;
    this.ticker = setInterval(() => {
      this.session.tick();
      this.requestRender(false);
    }, TICK_MILLIS);
    this.requestRender(true);
  }

  dispose(): void {
    if (this.ticker) clearInterval(this.ticker);
    if (this.throttle) clearTimeout(this.throttle);
    this.ticker = null;
    this.throttle = null;
    this.unsubscribe?.();
    this.unsubscribe = null;
    this.transcriber?.stop();
    this.cues.reset();
    this.answers.reset();
  }

  subscribe(listener: (s: AppState) => void): () => void {
    this.listeners.add(listener);
    listener(this.state);
    return () => this.listeners.delete(listener);
  }

  // ---- phone-side controls -------------------------------------------------

  async start(prepNoteId: string | null): Promise<void> {
    await this.apply(this.session.startLive(prepNoteId));
  }

  async end(): Promise<void> {
    if (this.session.isLive) await this.apply(this.session.endLive());
  }

  async setPaused(paused: boolean): Promise<void> {
    if (!this.session.isLive || this.session.isPaused === paused) return;
    this.session.setPaused(paused);
    await this.apply([{ type: 'SetPaused', paused }]);
  }

  intent(intent: ConversateIntent, source: IntentSource = 'PHONE'): Promise<void> {
    if (!this.deduper.accept(intent, source)) return Promise.resolve();
    // Even Hub review rule: double-tap on the root page must open the system
    // exit dialog (shutDownPageContainer(1)); custom confirm screens are
    // rejected. So on G2 the shared ConfirmEnd overlay is never used.
    if (intent === 'BACK' && this.session.isAtRoot) return this.exitToSystem();
    return this.apply(this.session.onIntent(intent));
  }

  private async exitToSystem(): Promise<void> {
    await this.deps.bridge?.shutDownPageContainer(1);
  }

  async updatePrefs(prefs: ConversatePrefs): Promise<void> {
    const clean: ConversatePrefs = {
      captionsOn: prefs.captionsOn,
      cuesOn: prefs.cuesOn,
      autoPopup: prefs.autoPopup,
      cueDurationMillis: Math.max(3_000, Math.min(15_000, Math.round(prefs.cueDurationMillis))),
    };
    this.session.updatePrefs(clean);
    await this.persistPrefs();
    this.requestRender(true);
  }

  async setApiKey(key: string): Promise<void> {
    const k = key.trim();
    this.apiKey = k === '' ? null : k;
    await this.deps.store.set(KEYS.apiKey, k);
    this.patch({ hasKey: this.apiKey !== null });
    if (this.session.isLive) {
      this.transcriber?.stop();
      this.transcriber = null;
      this.state.audioOn = false;
      this.captions.clear();
      this.session.onCaptionLines([]);
    }
    await this.syncAudio();
    this.refreshCaptions();
    this.requestRender(true);
  }

  async setAudioSource(source: AudioSourceChoice): Promise<void> {
    await this.deps.store.set(KEYS.audioSource, source);
    this.patch({ audioSource: source });
    if (this.state.audioOn) {
      await this.audioOff();
      await this.syncAudio();
    }
  }

  async savePrepNote(note: PrepNoteRef): Promise<void> {
    const clean = { id: note.id, title: note.title.trim() || 'Untitled', text: note.text.slice(0, PREP_NOTE_MAX_CHARS) };
    const list = this.state.prepNotes.some((n) => n.id === clean.id)
      ? this.state.prepNotes.map((n) => (n.id === clean.id ? clean : n))
      : [...this.state.prepNotes, clean];
    await this.persistNotes(list);
  }

  async deletePrepNote(id: string): Promise<void> {
    await this.persistNotes(this.state.prepNotes.filter((n) => n.id !== id));
  }

  // ---- inputs ------------------------------------------------------------

  private onHubEvent(e: EvenHubEvent): void {
    const audio = e.audioEvent;
    if (audio) {
      if (this.state.audioOn) this.transcriber?.appendPcm16k(audio.audioPcm, roleOf(audio.speakerRole));
      return;
    }
    const action = this.input.map(e);
    if (!action) return;
    switch (action.type) {
      case 'intent':
        void this.intent(action.intent, action.source);
        break;
      case 'menuItem':
        void this.apply(this.session.activateMenuItem(action.menuId));
        break;
      case 'lifecycle':
        void this.onLifecycle(action.phase);
        break;
    }
  }

  /**
   * The phone WebView came back (visibilitychange) after a possible
   * suspension: re-assert the mic and redraw the whole page.
   */
  async resume(): Promise<void> {
    this.patch({ foreground: true });
    await this.rearmAudio();
    this.lastRendered = null;
    this.requestRender(true);
  }

  /**
   * FOREGROUND_ENTER/EXIT bracket a system layer over the app (observed:
   * the OS context menu emits ENTER on open, EXIT on close), so neither
   * closes the mic. Both re-assert it; EXIT (layer gone) also redraws.
   * Only SYSTEM/ABNORMAL_EXIT close the mic.
   */
  private async onLifecycle(phase: 'foregroundEnter' | 'foregroundExit' | 'exit'): Promise<void> {
    if (phase === 'exit') {
      // The wearer confirmed the system exit dialog: end the session too.
      if (this.session.isLive) await this.apply(this.session.endLive());
      this.patch({ foreground: false });
      await this.syncAudio();
      return;
    }
    await this.rearmAudio();
    if (phase === 'foregroundExit') {
      this.lastRendered = null;
      this.requestRender(true);
    }
  }

  private async rearmAudio(): Promise<void> {
    if (!this.state.audioOn) {
      await this.syncAudio();
      return;
    }
    try {
      await this.deps.bridge?.audioControl(true, this.audioInput());
    } catch {
      /* next re-arm retries */
    }
  }

  private audioInput(): AudioInputSource {
    return this.state.audioSource === 'phone' ? AudioInputSource.Phone : AudioInputSource.Glasses;
  }

  private onSegment(seg: Segment): void {
    if (!this.session.isLive) return;
    this.captions.onSegment(seg);
    this.session.onCaptionLines(this.captions.lines());
    if (seg.isFinal) {
      if (this.session.currentPrefs.cuesOn) {
        this.cues.onFinal(seg.text);
        void this.answers.onFinal(seg.text, seg.role);
      }
    }
    this.requestRender(false);
  }

  private onCue(cue: Cue): void {
    this.session.onCue(cue);
    this.patch({ cueFailures: this.cues.failures });
    this.requestRender(true);
  }

  // ---- effects -------------------------------------------------------------

  private async apply(effects: SessionEffect[]): Promise<void> {
    for (const effect of effects) {
      switch (effect.type) {
        case 'Start': {
          this.captions.clear();
          this.cues.reset();
          this.answers.reset();
          this.cues.setPrepNote(this.state.prepNotes.find((n) => n.id === effect.prepNoteId)?.text ?? null);
          break;
        }
        case 'End':
          this.cues.reset();
          this.answers.reset();
          this.captions.clear();
          break;
        case 'SetCaptions':
        case 'SetCues':
          await this.persistPrefs();
          break;
        case 'SetPaused':
          break;
      }
    }
    this.patch({ live: this.session.isLive, paused: this.session.isPaused, prefs: this.session.currentPrefs });
    this.refreshCaptions();
    this.requestRender(true);
    await this.syncAudio();
  }

  /** With no key the caption slot carries the setup prompt instead of speech. */
  private refreshCaptions(): void {
    const needsKey = this.session.isLive && this.apiKey === null;
    this.patch({ needsKey });
    if (needsKey) this.session.onCaptionLines(NEEDS_KEY_LINES);
    else this.session.onCaptionLines(this.captions.lines());
  }

  private async syncAudio(): Promise<void> {
    const want = this.session.isLive && !this.session.isPaused && this.state.foreground && this.apiKey !== null;
    if (want && !this.state.audioOn) await this.audioOn();
    else if (!want && this.state.audioOn) await this.audioOff();
  }

  private async audioOn(): Promise<void> {
    if (!this.apiKey) return;
    this.state.audioOn = true;
    const make = this.deps.makeTranscriber ?? defaultTranscriber;
    const t = make(this.apiKey);
    this.transcriber = t;
    t.onSegment = (s) => this.onSegment(s);
    t.onMode = (m) => this.patch({ transcriberMode: m });
    t.start();
    const source = this.audioInput();
    try {
      const ok = (await this.deps.bridge?.audioControl(true, source)) ?? false;
      if (!ok && this.deps.bridge) this.patch({ lastError: 'Microphone could not be opened' });
    } catch (e) {
      this.patch({ lastError: `Microphone error: ${String(e)}` });
    }
    this.patch({ audioOn: true });
  }

  private async audioOff(): Promise<void> {
    this.state.audioOn = false;
    const t = this.transcriber;
    this.transcriber = null;
    if (t) {
      t.onSegment = null;
      t.stop();
    }
    try {
      await this.deps.bridge?.audioControl(false);
    } catch {
      /* already closed */
    }
    this.patch({ audioOn: false, transcriberMode: null });
  }

  private async persistPrefs(): Promise<void> {
    const prefs = this.session.currentPrefs;
    this.patch({ prefs });
    await this.deps.store.set(KEYS.prefs, JSON.stringify(prefs));
  }

  private async persistNotes(list: PrepNoteRef[]): Promise<void> {
    this.session.setPrepNotes(list);
    this.patch({ prepNotes: list });
    await this.deps.store.set(KEYS.prepNotes, JSON.stringify(list));
  }

  // ---- rendering -----------------------------------------------------------

  /**
   * Latest state wins: one bridge operation in flight, newer requests
   * coalesce into one follow-up render. Non-urgent upgrades (captions, ticks)
   * are spaced ≥300 ms apart; user-driven renders go immediately.
   */
  private requestRender(urgent: boolean): void {
    if (this.rendering) {
      this.dirty = true;
      this.dirtyUrgent ||= urgent;
      return;
    }
    void this.renderNow(urgent);
  }

  private async renderNow(urgent: boolean): Promise<void> {
    this.rendering = true;
    try {
      const flags = { paused: this.session.isPaused, ...flagsOf(this.session.currentPrefs) };
      const menu = buildContextMenu(this.menu, this.session.isLive, flags);
      const result = renderPage(this.session.screen(), {
        menu,
        previous: this.lastRendered,
        idleHint: this.session.isLive ? undefined : idleHint(this.apiKey !== null),
      });
      const preview = Object.values(result.contents).join('\n\n');
      if (preview !== this.state.preview) this.patch({ preview });
      const bridge = this.deps.bridge;
      if (!bridge) {
        this.lastRendered = result;
        return;
      }
      if (result.kind === 'rebuild') {
        let ok: boolean;
        if (!this.created) {
          const r = await bridge.createStartUpPageContainer(new CreateStartUpPageContainer({ ...result.page }));
          ok = r === StartUpPageCreateResult.success;
          this.created = ok;
          if (!ok) this.patch({ lastError: `Glasses page create failed (${r})` });
        } else {
          ok = await bridge.rebuildPageContainer(result.page);
        }
        this.lastRendered = ok ? result : null;
        return;
      }
      if (result.upgrades.length === 0) return;
      const wait = CAPTION_UPGRADE_GAP_MILLIS - (this.clock() - this.lastUpgradeAt);
      if (!urgent && wait > 0) {
        if (!this.throttle) {
          this.throttle = setTimeout(() => {
            this.throttle = null;
            this.requestRender(false);
          }, wait);
        }
        return;
      }
      let ok = true;
      for (const u of result.upgrades) ok = (await bridge.textContainerUpgrade(u)) && ok;
      this.lastUpgradeAt = this.clock();
      this.lastRendered = ok ? result : null;
    } catch (e) {
      this.lastRendered = null;
      this.patch({ lastError: `Render failed: ${String(e)}` });
    } finally {
      this.rendering = false;
      if (this.dirty) {
        const u = this.dirtyUrgent;
        this.dirty = false;
        this.dirtyUrgent = false;
        void this.renderNow(u);
      }
    }
  }

  private patch(p: Partial<AppState>): void {
    this.state = { ...this.state, ...p };
    for (const l of this.listeners) l(this.state);
  }
}

function flagsOf(p: ConversatePrefs) {
  return { captions: p.captionsOn, cues: p.cuesOn };
}

function roleOf(r: AudioSpeakerRole): SpeakerRole {
  return r === 'self' ? 'self' : r === 'other' ? 'other' : 'unknown';
}
