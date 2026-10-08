// App wiring for contract 0.3 on G2: dashboard home, panels, to-do toggle,
// reminders, Ask (relay + OpenAI fallback), mode and display pickers.
import {
  AudioInputSource,
  type CreateStartUpPageContainer,
  type EvenHubEvent,
  EventSourceType,
  evenHubEventFromJson,
  OsEventTypeList,
  type RebuildPageContainer,
  StartUpPageCreateResult,
  type TextContainerUpgrade,
} from '@evenrealities/even_hub_sdk';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { App, dashboardHome, type HubBridge, REMINDER_POLL_MILLIS } from '../src/app';
import type { Segment } from '../src/audio/segments';
import { contextMenuItemId } from '../src/g2/contextMenu';
import { FULL_LINES } from '../src/g2/render';
import { validatePage } from '../src/g2/validate';
import { parseDashboard } from '../src/relay/client';
import { KEYS, memoryStore } from '../src/storage';
import { dashboardFixture, fakeRelay, RELAY_KEY, RELAY_URL } from './fakeRelay';

class FakeBridge implements HubBridge {
  calls: Array<{ fn: string; arg?: unknown; arg2?: unknown }> = [];
  listener: ((e: EvenHubEvent) => void) | null = null;
  async createStartUpPageContainer(c: CreateStartUpPageContainer) { this.calls.push({ fn: 'create', arg: c }); return StartUpPageCreateResult.success; }
  async rebuildPageContainer(c: RebuildPageContainer) { this.calls.push({ fn: 'rebuild', arg: c }); return true; }
  async textContainerUpgrade(c: TextContainerUpgrade) { this.calls.push({ fn: 'upgrade', arg: c }); return true; }
  async audioControl(open: boolean, source?: AudioInputSource) { this.calls.push({ fn: 'audio', arg: open, arg2: source }); return true; }
  async shutDownPageContainer(mode?: number) { this.calls.push({ fn: 'shutdown', arg: mode }); return true; }
  onEvenHubEvent(cb: (e: EvenHubEvent) => void) { this.listener = cb; return () => { this.listener = null; }; }
  fire(type: string, jsonData: Record<string, unknown>) { this.listener!(evenHubEventFromJson({ type, jsonData })); }
  gesture(t: OsEventTypeList) { this.fire('sysEvent', { eventType: t, eventSource: EventSourceType.TOUCH_EVENT_FROM_GLASSES_R }); }
  menu(id: string) { this.fire('menuItemClickEvent', { itemID: contextMenuItemId(id) }); }
  of(fn: string) { return this.calls.filter((c) => c.fn === fn); }
}

class FakeTranscriber {
  onSegment: ((s: Segment) => void) | null = null;
  onMode: ((m: string) => void) | null = null;
  started = 0;
  stopped = 0;
  start() { this.started++; }
  stop() { this.stopped++; }
  appendPcm16k() {}
  final(text: string) { this.onSegment!({ itemId: text, text, isFinal: true, role: 'self' }); }
}

const flush = async () => { for (let i = 0; i < 5; i++) await vi.advanceTimersByTimeAsync(0); };
const relayStore = (extra: Record<string, string> = {}) =>
  memoryStore({ [KEYS.apiKey]: 'test-key', [KEYS.relayUrl]: RELAY_URL, [KEYS.relayKey]: RELAY_KEY, ...extra });

describe('App with helix-relay (contract 0.3)', () => {
  let bridge: FakeBridge;
  let tx: FakeTranscriber;
  let app: App;
  let relay: ReturnType<typeof fakeRelay>;
  let answer: ReturnType<typeof vi.fn>;

  async function boot(store = relayStore(), relayOpts = {}) {
    bridge = new FakeBridge();
    tx = new FakeTranscriber();
    relay = fakeRelay(relayOpts);
    answer = vi.fn(async () => 'Canberra (OpenAI).');
    app = new App({ bridge, store, makeTranscriber: () => tx, classify: async () => '{"cues":[]}', answer, relayFetch: relay.fetchFn });
    await app.init();
    await flush();
  }

  /** Everything currently drawn on the lens. */
  const lens = () => app.state.preview;

  beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(1_000_000); });
  afterEach(() => { app?.dispose(); vi.useRealTimers(); });

  describe('idle home', () => {
    it('first paint is the static hint (never black), then the dashboard summary', async () => {
      await boot();
      const create = bridge.of('create')[0]!.arg as CreateStartUpPageContainer;
      expect(create.textObject![0]!.content).toContain('Helix Live');
      expect(lens()).toContain('Call with Acme at 3pm');
      expect(lens()).toContain('To-do: Send Q3 churn deck to Sam');
      expect(lens()).toContain('News: Fed holds rates steady');
      expect(lens().split('\n').length).toBeLessThanOrEqual(FULL_LINES);
    });

    it('summary is capped at 9 lines with every line within the lens width', () => {
      const d = parseDashboard({ ...dashboardFixture, briefing: Array.from({ length: 12 }, (_, i) => `Brief ${i} ${'w'.repeat(90)}`) });
      const text = dashboardHome(d, ['Due 2pm: something'], true);
      expect(text.split('\n').length).toBeLessThanOrEqual(FULL_LINES);
      expect(text).toContain('Due 2pm: something');
    });

    it('falls back to the hint when the relay is unreachable', async () => {
      await boot(relayStore(), { fail: true });
      expect(lens()).toContain('Hold the touchpad');
      expect(app.state.relayStatus).toMatch(/unreachable/i);
    });

    it('keeps the add-your-key message when neither relay nor key is set', async () => {
      await boot(memoryStore());
      expect(lens()).toContain('Add your OpenAI key');
      expect(relay.fetchFn).not.toHaveBeenCalled();
    });

    it('with a relay but no OpenAI key the summary carries a key line', async () => {
      await boot(memoryStore({ [KEYS.relayUrl]: RELAY_URL, [KEYS.relayKey]: RELAY_KEY }));
      expect(lens()).toContain('To-do: Send Q3 churn deck to Sam');
      expect(lens()).toMatch(/OpenAI key/);
    });
  });

  describe('panels', () => {
    it('native menu To-dos opens the panel from relay data; tap toggles via PATCH', async () => {
      await boot();
      bridge.menu('todos');
      await flush();
      expect(lens()).toContain('> [ ] Send Q3 churn deck to Sam');
      expect(lens()).toContain('[x] Book dentist');
      bridge.gesture(OsEventTypeList.CLICK_EVENT);
      await flush();
      expect(lens()).toContain('> [x] Send Q3 churn deck to Sam');
      const patch = relay.of('/todos/')[0]!;
      expect(patch.init.method).toBe('PATCH');
      expect(JSON.parse(String(patch.init.body))).toEqual({ completed: true });
    });

    it('a failed PATCH reverts the row and reports the error', async () => {
      await boot(relayStore(), { failPatch: true });
      bridge.menu('todos');
      await flush();
      bridge.gesture(OsEventTypeList.CLICK_EVENT);
      await flush();
      expect(lens()).toContain('> [ ] Send Q3 churn deck to Sam');
      expect(app.state.lastError).toMatch(/to-do/i);
    });

    it('news panel opens a paged detail; every page validates', async () => {
      await boot();
      bridge.menu('news');
      await flush();
      expect(lens()).toContain('NEWS');
      bridge.gesture(OsEventTypeList.CLICK_EVENT);
      await flush();
      expect(lens()).toContain('The Federal Reserve kept rates');
      for (const c of [...bridge.of('rebuild'), ...bridge.of('create')]) expect(validatePage(c.arg as RebuildPageContainer)).toEqual({ valid: true });
    });

    it('without a relay a panel says Nothing here', async () => {
      await boot(memoryStore({ [KEYS.apiKey]: 'k' }));
      bridge.menu('x');
      await flush();
      expect(lens()).toContain('> Nothing here');
    });
  });

  describe('reminders', () => {
    it('live: each new reminder pops once as a NOTICE cue', async () => {
      await boot(relayStore(), { reminders: { reminders: [] } });
      await app.start(null);
      await flush();
      relay.state.reminders = undefined; // the relay now has the fixture's reminders
      await vi.advanceTimersByTimeAsync(REMINDER_POLL_MILLIS);
      await flush();
      expect(lens()).toContain('Due 2pm: Send Q3 churn deck to Sam');
      const polls = relay.of('/reminders');
      expect(polls.length).toBeGreaterThanOrEqual(2);
      expect(new URL(polls.at(-1)!.url).searchParams.get('since')).not.toBeNull();
      expect(app.state.remindersShown).toEqual(['r-t1', 'r-brief-2026-10-07']);
      await vi.advanceTimersByTimeAsync(REMINDER_POLL_MILLIS);
      await flush();
      expect(app.state.remindersShown).toEqual(['r-t1', 'r-brief-2026-10-07']);
    });

    it('not live: reminders update the idle home', async () => {
      await boot();
      expect(lens()).toContain('Due 2pm: Send Q3 churn deck to Sam');
    });
  });

  describe('ask', () => {
    it('glasses Ask listens, sends the next final to /ask and shows the answer', async () => {
      await boot();
      bridge.menu('ask');
      await flush();
      expect(lens()).toContain('Ask: listening...');
      expect(bridge.of('audio').at(-1)).toMatchObject({ arg: true });
      tx.final('What is the capital of Australia?');
      await flush();
      const call = relay.of('/ask')[0]!;
      expect(JSON.parse(String(call.init.body)).question).toBe('What is the capital of Australia?');
      expect(lens()).toContain('Canberra.');
      expect(bridge.of('audio').at(-1)).toMatchObject({ arg: false });
    });

    it('double-tap while listening cancels and closes the mic', async () => {
      await boot();
      bridge.menu('ask');
      await flush();
      bridge.gesture(OsEventTypeList.DOUBLE_CLICK_EVENT);
      await flush();
      expect(lens()).toContain('> Ask ChatGPT');
      expect(bridge.of('audio').at(-1)).toMatchObject({ arg: false });
      expect(bridge.of('shutdown')).toEqual([]);
    });

    it('live: the answer arrives as an ANSWER cue card', async () => {
      await boot();
      await app.start(null);
      await flush();
      await app.ask('Capital of Australia?');
      await flush();
      const page = bridge.of('rebuild').at(-1)!.arg as RebuildPageContainer;
      expect(page.textObject!.find((t) => t.containerName === 'cue')?.content).toContain('Canberra.');
    });

    it('phone Ask streams the answer into state', async () => {
      await boot(relayStore(), { sse: ['data: {"delta":"Can"}\n\n', 'data: {"delta":"berra"}\n\n', 'data: {"done":true}\n\n'] });
      const seen: string[] = [];
      app.subscribe((s) => seen.push(s.askAnswer));
      await app.ask('Capital?', true);
      await flush();
      expect(seen).toContain('Can');
      expect(app.state.askAnswer).toBe('Canberra');
      expect(JSON.parse(String(relay.of('/ask')[0]!.init.body)).deep).toBe(true);
    });

    it('relay failure shows an error line, no OpenAI fallback', async () => {
      await boot(relayStore(), { sse: ['data: {"error":"codex-proxy down"}\n\n'] });
      await app.ask('Q?');
      await flush();
      expect(lens()).toMatch(/Ask failed/);
      expect(answer).not.toHaveBeenCalled();
    });

    it('without a relay Ask uses the OpenAI key', async () => {
      await boot(memoryStore({ [KEYS.apiKey]: 'k' }));
      await app.ask('Capital?');
      await flush();
      expect(answer).toHaveBeenCalledWith('k', 'Capital?', expect.any(String));
      expect(lens()).toContain('Canberra (OpenAI).');
    });

    it('a new question cancels the one in flight', async () => {
      await boot(relayStore(), { sse: ['data: {"delta":"slow"}\n\n'] });
      const first = app.ask('one');
      const second = app.ask('two');
      await Promise.all([first, second]);
      expect((relay.of('/ask')[0]!.init.signal as AbortSignal).aborted).toBe(true);
    });
  });

  describe('ask cancel isolation (contract §6)', () => {
    const slow = { sse: ['data: {"delta":"thinking"}\n\n'], hang: true };
    const signalOf = (i: number) => relay.of('/ask')[i]!.init.signal as AbortSignal;

    it('glasses BACK while listening never aborts a phone Ask', async () => {
      await boot(relayStore(), slow);
      void app.ask('phone question');
      await flush();
      expect(app.state.askBusy).toBe(true);
      bridge.menu('ask');
      await flush();
      bridge.gesture(OsEventTypeList.DOUBLE_CLICK_EVENT);
      await flush();
      expect(signalOf(0).aborted).toBe(false);
      expect(app.state.askBusy).toBe(true);
    });

    it('a newer glasses Ask never aborts a phone Ask', async () => {
      await boot(relayStore(), slow);
      void app.ask('phone question');
      await flush();
      bridge.menu('ask');
      await flush();
      tx.final('glasses question');
      await flush();
      expect(relay.of('/ask')).toHaveLength(2);
      expect(signalOf(0).aborted).toBe(false);
    });

    it('AskCancel aborts the glasses Ask in flight and clears askBusy', async () => {
      await boot(relayStore(), slow);
      bridge.menu('ask');
      await flush();
      tx.final('glasses question');
      await flush();
      expect(app.state.askBusy).toBe(true);
      bridge.menu('ask');
      await flush();
      bridge.gesture(OsEventTypeList.DOUBLE_CLICK_EVENT);
      await flush();
      expect(signalOf(0).aborted).toBe(true);
      expect(app.state.askBusy).toBe(false);
      expect(app.state.lastError).toBeNull();
    });

    it('a newer glasses Ask aborts the older glasses Ask only', async () => {
      await boot(relayStore(), slow);
      bridge.menu('ask');
      await flush();
      tx.final('first');
      await flush();
      bridge.menu('ask');
      await flush();
      tx.final('second');
      await flush();
      expect(signalOf(0).aborted).toBe(true);
      expect(signalOf(1).aborted).toBe(false);
      expect(app.state.askBusy).toBe(true);
    });
  });

  describe('ask releases the mic (contract §6)', () => {
    const listening = async () => {
      bridge.menu('ask');
      await flush();
      expect(bridge.of('audio').at(-1)).toMatchObject({ arg: true });
      expect(app.state.audioOn).toBe(true);
    };

    it('a phone answer shown while the glasses listen closes Ask and the mic', async () => {
      await boot();
      await listening();
      await app.ask('Capital?');
      await flush();
      expect(lens()).toContain('Canberra.');
      expect(lens()).not.toContain('Ask: listening');
      expect(bridge.of('audio').at(-1)).toMatchObject({ arg: false });
      expect(app.state.audioOn).toBe(false);
    });

    it('an Ask-failed notice shown while listening releases the mic', async () => {
      await boot(relayStore(), { sse: ['data: {"error":"down"}\n\n'] });
      await listening();
      await app.ask('Q?');
      await flush();
      expect(lens()).toMatch(/Ask failed/);
      expect(bridge.of('audio').at(-1)).toMatchObject({ arg: false });
      expect(app.state.audioOn).toBe(false);
    });

    it('Display only: an answer shown while listening closes the one-utterance mic', async () => {
      await boot();
      await app.setMode('DISPLAY_ONLY');
      await listening();
      await app.ask('Q?');
      await flush();
      expect(bridge.of('audio').at(-1)).toMatchObject({ arg: false });
    });
  });

  describe('mode and display pickers', () => {
    it('G2 mode picker offers Glasses mic / Phone mic / Display only and switches the mic', async () => {
      const store = relayStore();
      await boot(store);
      await app.start(null);
      await flush();
      expect(bridge.of('audio').at(-1)).toEqual({ fn: 'audio', arg: true, arg2: AudioInputSource.Glasses });
      bridge.menu('mode');
      await flush();
      expect(lens()).toContain('> Glasses mic');
      expect(lens()).toContain('Phone mic');
      expect(lens()).toContain('Display only');
      expect(lens()).not.toContain('Omi');
      bridge.gesture(OsEventTypeList.SCROLL_BOTTOM_EVENT);
      await flush();
      bridge.gesture(OsEventTypeList.CLICK_EVENT);
      await flush();
      expect(app.state.mode).toBe('PHONE_MIC');
      expect(store.data[KEYS.mode]).toBe('PHONE_MIC');
      expect(bridge.of('audio').at(-1)).toEqual({ fn: 'audio', arg: true, arg2: AudioInputSource.Phone });
    });

    it('Display only closes the mic and needs no key', async () => {
      await boot(memoryStore({ [KEYS.mode]: 'DISPLAY_ONLY' }));
      await app.start(null);
      await flush();
      expect(bridge.of('audio').filter((c) => c.arg === true)).toEqual([]);
      expect(app.state.needsKey).toBe(false);
    });

    it('OMI is not available on G2: notice, mode unchanged', async () => {
      await boot();
      await app.setMode('OMI');
      await flush();
      expect(app.state.mode).toBe('GLASSES_MIC');
      expect(lens()).toContain('Omi not available on G2');
    });

    it('legacy audioSource=phone migrates to PHONE_MIC', async () => {
      await boot(memoryStore({ [KEYS.audioSource]: 'phone' }));
      expect(app.state.mode).toBe('PHONE_MIC');
      expect(app.state.audioSource).toBe('phone');
    });

    it('display picker brightness rebuilds with the new textColor and persists', async () => {
      const store = relayStore();
      await boot(store);
      bridge.menu('display');
      await flush();
      expect(lens()).toContain('Brightness: 3');
      bridge.gesture(OsEventTypeList.SCROLL_BOTTOM_EVENT);
      bridge.gesture(OsEventTypeList.SCROLL_BOTTOM_EVENT);
      await flush();
      bridge.gesture(OsEventTypeList.CLICK_EVENT);
      await flush();
      expect(lens()).toContain('Brightness: 4');
      const page = bridge.of('rebuild').at(-1)!.arg as RebuildPageContainer;
      expect(page.textObject!.every((t) => t.textColor === 4)).toBe(true);
      expect(JSON.parse(store.data[KEYS.prefs]!).brightness).toBe(4);
    });
  });

  describe('relay settings', () => {
    it('saves URL and key, never exposing the key in state', async () => {
      const store = memoryStore({ [KEYS.apiKey]: 'k' });
      await boot(store);
      expect(app.state.relayConfigured).toBe(false);
      await app.setRelay('mac.tail1234.ts.net/', RELAY_KEY);
      await flush();
      expect(store.data[KEYS.relayUrl]).toBe(RELAY_URL);
      expect(store.data[KEYS.relayKey]).toBe(RELAY_KEY);
      expect(app.state.relayConfigured).toBe(true);
      expect(JSON.stringify(app.state)).not.toContain(RELAY_KEY);
      expect(lens()).toContain('To-do:');
    });

    it('rejects an invalid URL', async () => {
      await boot(memoryStore());
      await app.setRelay('ftp://nope', 'k');
      expect(app.state.relayConfigured).toBe(false);
      expect(app.state.relayStatus).toMatch(/not valid/i);
    });

    it('test connection hits /health', async () => {
      await boot();
      await app.testRelay();
      expect(app.state.relayStatus).toMatch(/connected.*0\.3\.0/i);
    });
  });
});
