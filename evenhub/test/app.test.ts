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
import { App, type HubBridge } from '../src/app';
import type { Segment } from '../src/audio/segments';
import { contextMenuItemId } from '../src/g2/contextMenu';
import { validatePage } from '../src/g2/validate';
import { KEYS, memoryStore } from '../src/storage';

class FakeBridge implements HubBridge {
  calls: Array<{ fn: string; arg?: unknown; arg2?: unknown }> = [];
  listener: ((e: EvenHubEvent) => void) | null = null;
  rebuildOk = true;
  async createStartUpPageContainer(c: CreateStartUpPageContainer) { this.calls.push({ fn: 'create', arg: c }); return StartUpPageCreateResult.success; }
  async rebuildPageContainer(c: RebuildPageContainer) { this.calls.push({ fn: 'rebuild', arg: c }); return this.rebuildOk; }
  async textContainerUpgrade(c: TextContainerUpgrade) { this.calls.push({ fn: 'upgrade', arg: c }); return true; }
  async audioControl(open: boolean, source?: AudioInputSource) { this.calls.push({ fn: 'audio', arg: open, arg2: source }); return true; }
  async shutDownPageContainer(mode?: number) { this.calls.push({ fn: 'shutdown', arg: mode }); return true; }
  onEvenHubEvent(cb: (e: EvenHubEvent) => void) { this.listener = cb; return () => { this.listener = null; }; }
  fire(type: string, jsonData: Record<string, unknown>) { this.listener!(evenHubEventFromJson({ type, jsonData })); }
  gesture(t: OsEventTypeList, src = EventSourceType.TOUCH_EVENT_FROM_GLASSES_R) { this.fire('sysEvent', { eventType: t, eventSource: src }); }
  of(fn: string) { return this.calls.filter((c) => c.fn === fn); }
  clear() { this.calls = []; }
}

class FakeTranscriber {
  onSegment: ((s: Segment) => void) | null = null;
  onMode: ((m: string) => void) | null = null;
  onFailure: ((w: string) => void) | null = null;
  started = 0;
  stopped = 0;
  frames: Array<[number, string]> = [];
  start() { this.started++; }
  stop() { this.stopped++; }
  appendPcm16k(b: Uint8Array, role: string) { this.frames.push([b.length, role]); }
}

const flush = () => vi.advanceTimersByTimeAsync(0);

describe('App', () => {
  let bridge: FakeBridge;
  let tx: FakeTranscriber;
  let app: App;
  let classify: ReturnType<typeof vi.fn>;

  async function boot(store = memoryStore({ [KEYS.apiKey]: 'test-key' })) {
    bridge = new FakeBridge();
    tx = new FakeTranscriber();
    classify = vi.fn(async () => '{"cues":[]}');
    app = new App({
      bridge,
      store,
      makeTranscriber: () => tx,
      classify,
      answer: async () => 'Four million.',
    });
    await app.init();
    await flush();
  }

  beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(1_000_000); });
  afterEach(() => { app?.dispose(); vi.useRealTimers(); });

  it('creates a valid start-up page with the idle context menu, then subscribes', async () => {
    await boot();
    const [create] = bridge.of('create');
    expect(create).toBeDefined();
    const page = create!.arg as CreateStartUpPageContainer;
    expect(validatePage(page)).toEqual({ valid: true });
    expect(page.menuObject!.menuItems!.map((i) => i.itemName)).toEqual(['Start Conversate']);
    expect(bridge.listener).not.toBeNull();
    expect(bridge.of('rebuild')).toEqual([]);
  });

  it('long-press opens the menu, click starts a session and arms the glasses mic', async () => {
    await boot();
    bridge.gesture(OsEventTypeList.LONG_PRESS_EVENT);
    await flush();
    // Blank -> menu share the full-screen layout, so the menu arrives as an upgrade.
    expect(bridge.of('rebuild')).toEqual([]);
    expect((bridge.of('upgrade').at(-1)!.arg as TextContainerUpgrade).content).toContain('> Start Conversate');
    bridge.gesture(OsEventTypeList.CLICK_EVENT);
    await flush();
    expect(app.state.live).toBe(true);
    expect(tx.started).toBe(1);
    expect(bridge.of('audio').at(-1)).toEqual({ fn: 'audio', arg: true, arg2: AudioInputSource.Glasses });
    const livePage = bridge.of('rebuild').at(-1)!.arg as RebuildPageContainer;
    expect(validatePage(livePage)).toEqual({ valid: true });
    expect(livePage.menuObject!.menuItems!.map((i) => i.itemName)).toContain('End session');
  });

  it('streams audio frames to the transcriber and captions via throttled upgrades', async () => {
    await boot();
    await app.start(null);
    await flush();
    bridge.fire('audioEvent', { audioPcm: Array(3200).fill(0), speakerRole: 'other' });
    expect(tx.frames).toEqual([[3200, 'other']]);
    bridge.clear();
    tx.onSegment!({ itemId: 'a', text: 'hello', isFinal: false, role: 'other' });
    await flush();
    tx.onSegment!({ itemId: 'a', text: 'hello there', isFinal: false, role: 'other' });
    await flush();
    tx.onSegment!({ itemId: 'a', text: 'hello there friend', isFinal: true, role: 'other' });
    await flush();
    const upgrades = bridge.of('upgrade').map((c) => (c.arg as TextContainerUpgrade).content);
    expect(upgrades).toEqual(['hello']);
    await vi.advanceTimersByTimeAsync(300);
    expect(bridge.of('upgrade').map((c) => (c.arg as TextContainerUpgrade).content)).toEqual(['hello', 'hello there friend']);
    expect(bridge.of('rebuild')).toEqual([]);
    expect(app.state.preview).toContain('hello there friend');
  });

  it('a final question from the other speaker pops an ANSWER cue card', async () => {
    await boot();
    await app.start(null);
    await flush();
    tx.onSegment!({ itemId: 'q', text: 'What was revenue in Q3?', isFinal: true, role: 'other' });
    await flush();
    const page = bridge.of('rebuild').at(-1)!.arg as RebuildPageContainer;
    const cue = page.textObject!.find((t) => t.containerName === 'cue');
    expect(cue?.content).toContain('ANSWER  Answer');
    expect(cue?.content).toContain('Four million.');
  });

  it('cue engine runs on finals with the stored key', async () => {
    await boot();
    await app.start(null);
    tx.onSegment!({ itemId: 'x', text: 'we use retrieval augmented generation', isFinal: true, role: 'other' });
    await vi.advanceTimersByTimeAsync(1600);
    expect(classify).toHaveBeenCalledTimes(1);
    expect(classify.mock.calls[0]![0]).toBe('test-key');
  });

  // Simulator 0.9.5 emits FOREGROUND_ENTER when the OS context menu opens over
  // the app and FOREGROUND_EXIT when it closes (see NOTES.md), so neither may
  // close the mic: both re-assert it, and EXIT (overlay gone) redraws the page.
  it('foreground enter/exit never close the mic; exit re-arms audio and rebuilds', async () => {
    await boot();
    await app.start(null);
    await flush();
    bridge.clear();
    bridge.gesture(OsEventTypeList.FOREGROUND_ENTER_EVENT);
    await flush();
    expect(bridge.of('audio')).toEqual([{ fn: 'audio', arg: true, arg2: AudioInputSource.Glasses }]);
    expect(bridge.of('rebuild')).toEqual([]);
    bridge.clear();
    bridge.gesture(OsEventTypeList.FOREGROUND_EXIT_EVENT);
    await flush();
    expect(bridge.of('audio')).toEqual([{ fn: 'audio', arg: true, arg2: AudioInputSource.Glasses }]);
    expect(bridge.of('rebuild').length).toBe(1);
    expect(tx.stopped).toBe(0);
    expect(tx.started).toBe(1);
  });

  it('phone WebView resume re-arms audio and rebuilds; system exit closes the mic', async () => {
    await boot();
    await app.start(null);
    await flush();
    bridge.clear();
    await app.resume();
    await flush();
    expect(bridge.of('audio')).toEqual([{ fn: 'audio', arg: true, arg2: AudioInputSource.Glasses }]);
    expect(bridge.of('rebuild').length).toBe(1);
    bridge.clear();
    bridge.gesture(OsEventTypeList.SYSTEM_EXIT_EVENT);
    await flush();
    expect(bridge.of('audio')).toEqual([{ fn: 'audio', arg: false, arg2: undefined }]);
    expect(tx.stopped).toBe(1);
  });

  it('native context menu end item ends the session and closes the mic', async () => {
    await boot();
    await app.start(null);
    await flush();
    bridge.fire('menuItemClickEvent', { itemID: contextMenuItemId('end') });
    await flush();
    expect(app.state.live).toBe(false);
    expect(bridge.of('audio').at(-1)!.arg).toBe(false);
  });

  it('ring and temple echo of one gesture moves the menu cursor once', async () => {
    await boot();
    await app.start(null);
    bridge.gesture(OsEventTypeList.LONG_PRESS_EVENT);
    await flush();
    bridge.gesture(OsEventTypeList.SCROLL_BOTTOM_EVENT, EventSourceType.TOUCH_EVENT_FROM_RING);
    bridge.gesture(OsEventTypeList.SCROLL_BOTTOM_EVENT, EventSourceType.TOUCH_EVENT_FROM_GLASSES_R);
    await flush();
    expect(app.state.preview).toContain('2/6');
  });

  it('missing key: session starts, lens shows a prompt, no mic, no crash', async () => {
    await boot(memoryStore());
    await app.start(null);
    await flush();
    expect(app.state.live).toBe(true);
    expect(app.state.needsKey).toBe(true);
    expect(tx.started).toBe(0);
    expect(bridge.of('audio').filter((c) => c.arg === true)).toEqual([]);
    expect(app.state.preview).toContain('OpenAI key');
    await app.setApiKey('later-key');
    await flush();
    expect(tx.started).toBe(1);
    expect(app.state.needsKey).toBe(false);
  });

  it('a failed rebuild forces the next render to rebuild again', async () => {
    await boot();
    bridge.rebuildOk = false;
    await app.start(null);
    await flush();
    bridge.rebuildOk = true;
    bridge.clear();
    tx.onSegment!({ itemId: 'a', text: 'hi', isFinal: false, role: 'other' });
    await flush();
    expect(bridge.of('rebuild').length).toBe(1);
  });

  it('persists prefs and prep notes, capping note length', async () => {
    const store = memoryStore({ [KEYS.apiKey]: 'k' });
    await boot(store);
    await app.updatePrefs({ captionsOn: false, cuesOn: true, autoPopup: true, cueDurationMillis: 9000 });
    await app.savePrepNote({ id: 'n1', title: 'Acme', text: 'x'.repeat(6000) });
    expect(JSON.parse(store.data[KEYS.prefs]!)).toMatchObject({ captionsOn: false, cueDurationMillis: 9000 });
    expect(JSON.parse(store.data[KEYS.prepNotes]!)[0].text.length).toBe(5000);
    await app.deletePrepNote('n1');
    expect(JSON.parse(store.data[KEYS.prepNotes]!)).toEqual([]);
  });
});
