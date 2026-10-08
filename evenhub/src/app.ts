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
import type { Cue, CueType } from './core/cue';
import { BODY_MAX, DETAIL_MAX } from './core/cueParser';
import { loadCuePrompt } from './core/cuePrompt';
import { type ConversateIntent, IntentDeduper, type IntentSource } from './core/intents';
import { loadMenu } from './core/menu';
import { type ConversatePrefs, DEFAULT_PREFS, PANEL_KINDS, type PanelKind, type PrepNoteRef, type SessionEffect } from './core/screen';
import { ConversateSession } from './core/session';
import { buildContextMenu } from './g2/contextMenu';
import { InputAdapter } from './g2/input';
import { DEFAULT_G2_MODE, type G2Mode, g2MenuSpec, isG2Mode, OMI_UNAVAILABLE } from './g2/modes';
import { detailPageCount, FULL_LINES, LINE_CHARS, renderPage, type RenderResult, textPageCount } from './g2/render';
import { type Dashboard, type FetchFn, normalizeRelayUrl, RelayClient, RelayError } from './relay/client';
import { DashboardSource } from './relay/dashboard';
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
  /** fetch used for helix-relay calls (tests inject a fake relay). */
  relayFetch?: FetchFn;
}

export type AudioSourceChoice = 'glasses' | 'phone';
/** Where an Ask came from: the phone box or the glasses Ask overlay. */
export type AskSource = 'phone' | 'glasses';

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
  mode: G2Mode;
  relayConfigured: boolean;
  /** Relay URL (not secret); the relay key never enters state. */
  relayUrl: string;
  relayStatus: string | null;
  askBusy: boolean;
  /** Streamed answer to the last Ask (phone page). */
  askAnswer: string;
  /** Reminder ids already shown while this app run is open (dedupe). */
  remindersShown: string[];
}

export const TICK_MILLIS = 250;
export const CAPTION_UPGRADE_GAP_MILLIS = 300;
export const REMINDER_POLL_MILLIS = 5 * 60_000;
/** Reminder lines kept for the idle home. */
export const HOME_REMINDERS = 2;
export const NEEDS_KEY_LINES = ['Add your OpenAI key in', 'Helix Live on your phone'];
const HOME_FOOTER = 'Hold for menu. Double-tap to exit.';
const HOME_KEY_LINE = 'Add your OpenAI key on the phone for captions.';

const fitLine = (t: string) => {
  const s = t.replace(/\s+/g, ' ').trim();
  return s.length <= LINE_CHARS ? s : s.slice(0, LINE_CHARS - 1).trimEnd() + '~';
};

/**
 * Idle home from the relay dashboard (plan D2): reminders, briefing, next open
 * to-do and the top headline, at most FULL_LINES lines. Lower-priority lines
 * (briefing) are dropped first when the budget is short.
 */
export function dashboardHome(d: Dashboard | null, reminders: string[], hasKey: boolean): string {
  const fixed = ['Helix Live', ...(hasKey ? [] : [HOME_KEY_LINE]), HOME_FOOTER];
  let budget = FULL_LINES - fixed.length;
  const take = (lines: string[]) => {
    const out = lines.slice(0, Math.max(0, budget));
    budget -= out.length;
    return out;
  };
  const remind = take(reminders.slice(-HOME_REMINDERS).map((r) => fitLine(`! ${r}`)));
  const todo = d?.todos.find((t) => !t.completed);
  const todoLine = take(todo ? [fitLine(`To-do: ${todo.title}`)] : []);
  const news = take(d?.news[0] ? [fitLine(`News: ${d.news[0].title}`)] : []);
  const seen = new Set(reminders.map((r) => r.trim()));
  const brief = take((d?.briefing ?? []).filter((b) => !seen.has(b.trim())).map(fitLine));
  return [fixed[0]!, ...remind, ...brief, ...todoLine, ...news, ...fixed.slice(1)].join('\n');
}

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
  private readonly menu = g2MenuSpec(loadMenu());
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

  // relay (dashboards, reminders, ask)
  private relayKey: string | null = null;
  private relayClient: RelayClient | null = null;
  private readonly dashboard: DashboardSource;
  private reminderTimer: ReturnType<typeof setInterval> | null = null;
  private lastReminderPoll: number | null = null;
  private homeReminders: string[] = [];
  /** In-flight Ask per origin: the glasses never abort a phone Ask (§6). */
  private readonly asks: Record<AskSource, { ac: AbortController; gen: number } | null> = { phone: null, glasses: null };
  private askGeneration = 0;

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
    mode: DEFAULT_G2_MODE,
    relayConfigured: false,
    relayUrl: '',
    relayStatus: null,
    askBusy: false,
    askAnswer: '',
    remindersShown: [],
  };

  constructor(private readonly deps: AppDeps) {
    this.clock = deps.clock ?? (() => Date.now());
    this.session = new ConversateSession(this.menu, this.clock, DEFAULT_PREFS, detailPageCount, textPageCount);
    this.session.setMode(DEFAULT_G2_MODE);
    this.dashboard = new DashboardSource(() => this.relayClient, this.clock);
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
    const prefs = sanitizePrefs(parseJson<Partial<ConversatePrefs>>(await store.get(KEYS.prefs), {}));
    const notes = sanitizePrepNotes(parseJson<unknown>(await store.get(KEYS.prepNotes), []));
    const storedMode = await store.get(KEYS.mode);
    const legacySource = (await store.get(KEYS.audioSource)) === 'phone' ? 'PHONE_MIC' : DEFAULT_G2_MODE;
    const mode: G2Mode = isG2Mode(storedMode) ? storedMode : legacySource;
    const relayUrl = normalizeRelayUrl((await store.get(KEYS.relayUrl)) ?? '');
    this.relayKey = (await store.get(KEYS.relayKey))?.trim() || null;
    this.relayClient = this.makeRelayClient(relayUrl);
    this.session.updatePrefs(prefs);
    this.session.setPrepNotes(notes);
    this.session.setMode(mode);
    this.patch({
      prefs,
      prepNotes: notes,
      mode,
      audioSource: sourceOf(mode),
      hasKey: this.apiKey !== null,
      relayConfigured: this.relayClient !== null,
      relayUrl: relayUrl ?? '',
    });
    this.unsubscribe = this.deps.bridge?.onEvenHubEvent((e) => this.onHubEvent(e)) ?? null;
    this.ticker = setInterval(() => {
      this.session.tick();
      this.requestRender(false);
    }, TICK_MILLIS);
    this.reminderTimer = setInterval(() => this.pollRelaySafely(), REMINDER_POLL_MILLIS);
    // First paint is the static hint (never black); the dashboard follows.
    this.requestRender(true);
    // Never wait on the relay (§8): the dashboard fills in when it arrives.
    this.pollRelaySafely();
  }

  dispose(): void {
    if (this.ticker) clearInterval(this.ticker);
    if (this.throttle) clearTimeout(this.throttle);
    if (this.reminderTimer) clearInterval(this.reminderTimer);
    this.reminderTimer = null;
    this.cancelAsk('phone');
    this.cancelAsk('glasses');
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

  async updatePrefs(patch: Partial<ConversatePrefs>): Promise<void> {
    const clean = sanitizePrefs({ ...this.session.currentPrefs, ...patch });
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

  /** Legacy microphone selector: glasses -> GLASSES_MIC, phone -> PHONE_MIC. */
  async setAudioSource(source: AudioSourceChoice): Promise<void> {
    await this.setMode(source === 'phone' ? 'PHONE_MIC' : 'GLASSES_MIC');
  }

  /**
   * Operating mode from the phone or the glasses picker. Contract id OMI has
   * no G2 path: the wearer gets a notice and the current mode stays.
   */
  async setMode(id: string): Promise<void> {
    if (!isG2Mode(id)) {
      this.session.setMode(this.state.mode);
      if (id === 'OMI') this.notify('Mode', OMI_UNAVAILABLE);
      this.requestRender(true);
      return;
    }
    this.session.setMode(id);
    await this.deps.store.set(KEYS.mode, id);
    await this.deps.store.set(KEYS.audioSource, sourceOf(id));
    const sourceChanged = sourceOf(id) !== this.state.audioSource;
    this.patch({ mode: id, audioSource: sourceOf(id) });
    if (this.state.audioOn && sourceChanged) await this.audioOff();
    this.refreshCaptions();
    await this.syncAudio();
    this.requestRender(true);
  }

  // ---- relay (dashboards, reminders, ask) ----------------------------------

  private makeRelayClient(url: string | null): RelayClient | null {
    if (!url || !this.relayKey) return null;
    try {
      return new RelayClient({ url, key: this.relayKey }, this.deps.relayFetch);
    } catch {
      return null;
    }
  }

  /** Saves the relay URL and key (key stays out of state); empty URL clears. */
  async setRelay(rawUrl: string, key: string): Promise<void> {
    const trimmed = rawUrl.trim();
    const url = trimmed === '' ? null : normalizeRelayUrl(trimmed);
    if (trimmed !== '' && url === null) {
      this.patch({ relayStatus: 'Relay URL is not valid (use https://<mac>.<tailnet>.ts.net)' });
      return;
    }
    const k = key.trim();
    if (k !== '' || url === null) this.relayKey = k === '' ? null : k;
    await this.deps.store.set(KEYS.relayUrl, url ?? '');
    if (k !== '' || url === null) await this.deps.store.set(KEYS.relayKey, this.relayKey ?? '');
    this.relayClient = this.makeRelayClient(url);
    this.dashboard.reset();
    this.homeReminders = [];
    this.patch({
      relayConfigured: this.relayClient !== null,
      relayUrl: url ?? '',
      relayStatus: url !== null && this.relayKey === null ? 'Add the relay key' : null,
    });
    this.requestRender(true);
    await this.pollRelay();
  }

  /** "Test connection": /health, then an authenticated /dashboard to check the key. */
  async testRelay(): Promise<void> {
    const client = this.relayClient;
    if (!client) {
      this.patch({ relayStatus: 'Relay not configured' });
      return;
    }
    try {
      const h = await client.health();
      await this.dashboard.dashboard(true);
      const err = this.dashboard.lastError;
      this.patch({ relayStatus: err ? `Relay reachable, but: ${err}` : `Connected (relay ${h.version || '?'})` });
      this.applyDashboard();
    } catch (e) {
      this.patch({ relayStatus: errorText(e) });
    }
  }

  /** Fire-and-forget pollRelay: failures land in relayStatus, never reject. */
  private pollRelaySafely(): void {
    this.pollRelay().catch((e) => this.patch({ relayStatus: errorText(e) }));
  }

  /** Dashboard refresh + reminder poll (every REMINDER_POLL_MILLIS while open). */
  private async pollRelay(): Promise<void> {
    if (!this.relayClient) return;
    await this.dashboard.dashboard();
    this.patch({ relayStatus: this.dashboard.lastError });
    this.applyDashboard();
    await this.pollReminders();
    this.requestRender(false);
  }

  private applyDashboard(): void {
    if (!this.dashboard.current) return;
    for (const kind of PANEL_KINDS) this.session.setPanelRows(kind, this.dashboard.rows(kind));
    this.requestRender(false);
  }

  private async pollReminders(): Promise<void> {
    const client = this.relayClient;
    if (!client) return;
    const now = this.clock();
    const since = this.lastReminderPoll ?? now - REMINDER_POLL_MILLIS;
    let list;
    try {
      list = await client.getReminders(since);
    } catch (e) {
      this.patch({ relayStatus: errorText(e) });
      return;
    }
    this.lastReminderPoll = now;
    const seen = new Set(this.state.remindersShown);
    const fresh = list.filter((r) => !seen.has(r.id));
    if (fresh.length === 0) return;
    this.patch({ remindersShown: [...this.state.remindersShown, ...fresh.map((r) => r.id)] });
    for (const r of fresh) {
      if (this.session.isLive && this.session.currentPrefs.cuesOn) {
        this.onCue(this.makeCue('NOTICE', 'Reminder', r.text));
      } else {
        this.homeReminders = [...this.homeReminders, r.text].slice(-HOME_REMINDERS);
      }
    }
    this.requestRender(true);
  }

  private async openPanel(kind: PanelKind): Promise<void> {
    if (!this.relayClient) {
      this.patch({ relayStatus: 'Add a relay URL and key on the phone for dashboards' });
      return;
    }
    await this.dashboard.dashboard();
    this.patch({ relayStatus: this.dashboard.lastError });
    if (this.dashboard.current) this.session.setPanelRows(kind, this.dashboard.rows(kind));
    this.requestRender(true);
  }

  private async toggleTodo(id: string, done: boolean): Promise<void> {
    try {
      await this.dashboard.toggleTodo(id, done);
    } catch (e) {
      this.dashboard.setDone(id, !done);
      this.session.setPanelRows('todos', this.session.panelRows('todos').map((r) => (r.id === id ? { ...r, done: !done } : r)));
      this.patch({ lastError: `Could not update to-do: ${errorText(e)}` });
      this.requestRender(true);
    }
  }

  /**
   * Ask ChatGPT (phone box or glasses Ask). Relay configured -> POST /ask
   * (streamed); otherwise the user's OpenAI key. A new question cancels the
   * one in flight from the same origin only. The answer is an ANSWER cue
   * (live) or an answer card.
   */
  async ask(question: string, deep = false, source: AskSource = 'phone'): Promise<void> {
    const q = question.trim();
    if (q === '') return;
    this.cancelAsk(source);
    const ac = new AbortController();
    const gen = ++this.askGeneration;
    this.asks[source] = { ac, gen };
    const current = () => this.asks[source]?.gen === gen;
    const context = this.session.isLive ? this.cues.recentText() : '';
    this.patch({ askBusy: true, askAnswer: '' });
    let text: string;
    try {
      if (this.relayClient) {
        let streamed = '';
        text = await this.relayClient.ask(q, {
          context,
          deep,
          signal: ac.signal,
          onDelta: (d) => {
            if (!current()) return;
            streamed += d;
            this.patch({ askAnswer: streamed });
          },
        });
      } else if (this.apiKey) {
        const answer = this.deps.answer ?? ((key, qq, ctx) => openaiAnswer(key, qq, ctx, 3));
        text = await answer(this.apiKey, q, context);
      } else {
        throw new RelayError('Add a relay or an OpenAI key on the phone');
      }
    } catch (e) {
      if (!current()) return; // a newer Ask from this origin owns the state
      this.asks[source] = null;
      if ((e as { name?: string })?.name === 'AbortError') {
        this.patch({ askBusy: this.askInFlight() });
        return;
      }
      this.patch({ askBusy: this.askInFlight(), askAnswer: '', lastError: `Ask failed: ${errorText(e)}` });
      this.notify('Ask failed', errorText(e));
      return;
    }
    if (!current()) return;
    this.asks[source] = null;
    const answer = text.replace(/\s+/g, ' ').trim() || 'No answer.';
    this.patch({ askBusy: this.askInFlight(), askAnswer: answer });
    this.deliver(this.makeCue('ANSWER', 'Answer', answer));
  }

  /** Aborts [source]'s in-flight Ask; its catch path clears askBusy. */
  private cancelAsk(source: AskSource): void {
    this.asks[source]?.ac.abort();
  }

  private askInFlight(): boolean {
    return this.asks.phone !== null || this.asks.glasses !== null;
  }

  private makeCue(type: CueType, title: string, text: string): Cue {
    const body = text.replace(/\s+/g, ' ').trim();
    return {
      id: this.cues.nextCueId(),
      type,
      title,
      body: body.slice(0, BODY_MAX),
      detail: body.length > BODY_MAX ? body.slice(0, DETAIL_MAX) : null,
      createdAtMillis: this.clock(),
    };
  }

  /** Live with cues on -> cue path; otherwise an answer card overlay. */
  private deliver(cue: Cue): void {
    if (this.session.isLive && this.session.currentPrefs.cuesOn) this.onCue(cue);
    // showAnswer cancels an open Ask overlay (AskCancel); apply() then
    // re-syncs audio so the mic opened for Ask is released (§6).
    else void this.apply(this.session.showAnswer(cue));
  }

  private notify(title: string, text: string): void {
    this.deliver(this.makeCue('NOTICE', title, text));
  }

  private homeText(): string {
    const hasKey = this.apiKey !== null;
    const d = this.dashboard.current;
    if (this.relayClient && (d || this.homeReminders.length > 0)) return dashboardHome(d, this.homeReminders, hasKey);
    return idleHint(hasKey);
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
    if (this.session.isAsking) {
      // Ask (contract §6): the next final utterance is the question.
      if (seg.isFinal) void this.apply(this.session.onAskText(seg.text));
      return;
    }
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
        case 'SetPref':
          await this.persistPrefs();
          break;
        case 'SetPaused':
        case 'AskListen':
          break;
        case 'SetMode':
          await this.setMode(effect.mode);
          break;
        case 'RequestPanel':
          void this.openPanel(effect.kind);
          break;
        case 'ToggleTodo':
          void this.toggleTodo(effect.id, effect.done);
          break;
        case 'AskCancel':
          this.cancelAsk('glasses');
          break;
        case 'AskQuestion':
          void this.ask(effect.text, false, 'glasses');
          break;
      }
    }
    if (effects.some((e) => e.type === 'AskListen') && this.apiKey === null) {
      // No speech-to-text without the OpenAI key: back out with a hint.
      this.session.onIntent('BACK');
      this.notify('Ask', 'Ask by voice needs your OpenAI key; use the Ask box on the phone.');
    }
    this.patch({ live: this.session.isLive, paused: this.session.isPaused, prefs: this.session.currentPrefs });
    this.refreshCaptions();
    this.requestRender(true);
    await this.syncAudio();
  }

  /** With no key the caption slot carries the setup prompt instead of speech. */
  private refreshCaptions(): void {
    const needsKey = this.session.isLive && this.apiKey === null && this.state.mode !== 'DISPLAY_ONLY';
    this.patch({ needsKey });
    if (needsKey) this.session.onCaptionLines(NEEDS_KEY_LINES);
    else this.session.onCaptionLines(this.captions.lines());
  }

  private async syncAudio(): Promise<void> {
    // Display-only keeps the mic closed except while Ask is listening (the wearer asked to speak).
    const captioning = this.session.isLive && !this.session.isPaused && this.state.mode !== 'DISPLAY_ONLY';
    const want = (captioning || this.session.isAsking) && this.state.foreground && this.apiKey !== null;
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
      const prefs = this.session.currentPrefs;
      const result = renderPage(this.session.screen(), {
        menu,
        previous: this.lastRendered,
        captionLines: prefs.captionLines,
        brightness: prefs.brightness,
        idleHint: this.session.isLive ? undefined : this.homeText(),
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

const clampInt = (v: unknown, lo: number, hi: number, dflt: number) => {
  const n = Math.round(Number(v));
  return Number.isFinite(n) ? Math.max(lo, Math.min(hi, n)) : dflt;
};

/** Bounds every pref (stored JSON may be stale or hand-edited). */
export function sanitizePrefs(p: Partial<ConversatePrefs>): ConversatePrefs {
  const d = DEFAULT_PREFS;
  return {
    captionsOn: typeof p.captionsOn === 'boolean' ? p.captionsOn : d.captionsOn,
    cuesOn: typeof p.cuesOn === 'boolean' ? p.cuesOn : d.cuesOn,
    autoPopup: typeof p.autoPopup === 'boolean' ? p.autoPopup : d.autoPopup,
    cueDurationMillis: clampInt(p.cueDurationMillis, 3_000, 15_000, d.cueDurationMillis),
    captionLines: clampInt(p.captionLines, 2, 5, d.captionLines),
    brightness: clampInt(p.brightness, 1, 4, d.brightness),
  };
}

/** Mic used by a mode (DISPLAY_ONLY: glasses, only for Ask). */
function sourceOf(mode: G2Mode): AudioSourceChoice {
  return mode === 'PHONE_MIC' ? 'phone' : 'glasses';
}

function errorText(e: unknown): string {
  return e instanceof Error ? e.message : String(e);
}

function flagsOf(p: ConversatePrefs) {
  return { captions: p.captionsOn, cues: p.cuesOn };
}

function roleOf(r: AudioSpeakerRole): SpeakerRole {
  return r === 'self' ? 'self' : r === 'other' ? 'other' : 'unknown';
}
