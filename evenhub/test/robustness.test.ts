// @vitest-environment happy-dom
// Client robustness (conversate-core/CONTRACT-0.3.md §8): startup never waits
// on the relay, every relay request times out, Ask tolerates `: ping`.
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { App } from '../src/app';
import { startApp } from '../src/boot';
import { RELAY_TIMEOUT_MILLIS, RelayClient, RelayError, type FetchFn } from '../src/relay/client';
import { KEYS, memoryStore } from '../src/storage';
import { RELAY_KEY, RELAY_URL } from './fakeRelay';

/** A fetch that never answers, like a relay behind a dead tailnet; honours abort like real fetch. */
function hangingFetch() {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  const fn: FetchFn = (url, init = {}) => {
    calls.push({ url, init });
    return new Promise<Response>((_, reject) => {
      init.signal?.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError')));
    });
  };
  return { fn: vi.fn(fn), calls };
}

/** A fetch that never answers and ignores abort entirely. */
const deafFetch: FetchFn = () => new Promise<Response>(() => {});

/** /ask response whose body chunks arrive on a schedule (ms after headers). */
function scheduledSse(schedule: Array<[number, string]>): FetchFn {
  return async () => {
    const enc = new TextEncoder();
    const stream = new ReadableStream<Uint8Array>({
      start(controller) {
        let at = 0;
        for (const [delay, text] of schedule) {
          at += delay;
          setTimeout(() => controller.enqueue(enc.encode(text)), at);
        }
      },
    });
    return new Response(stream, { headers: { 'content-type': 'text/event-stream' } });
  };
}

const client = (fetchFn: FetchFn) => new RelayClient({ url: RELAY_URL, key: RELAY_KEY }, fetchFn);

describe('relay request timeout', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('is 15 s', () => expect(RELAY_TIMEOUT_MILLIS).toBe(15_000));

  it('a hanging /dashboard rejects with a RelayError after 15 s', async () => {
    const f = hangingFetch();
    const p = client(f.fn).getDashboard();
    const settled = vi.fn();
    p.catch(settled);
    await vi.advanceTimersByTimeAsync(RELAY_TIMEOUT_MILLIS - 1);
    expect(settled).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1);
    const err = await p.catch((e) => e);
    expect(err).toBeInstanceOf(RelayError);
    expect(err.message).toMatch(/timed out/i);
  });

  it('times out even when fetch ignores the abort signal', async () => {
    const p = client(deafFetch).getReminders(0).catch((e) => e);
    await vi.advanceTimersByTimeAsync(RELAY_TIMEOUT_MILLIS);
    expect(await p).toBeInstanceOf(RelayError);
  });

  it('ask: no first byte within 15 s rejects', async () => {
    const f = hangingFetch();
    const p = client(f.fn).ask('Q?').catch((e) => e);
    await vi.advanceTimersByTimeAsync(RELAY_TIMEOUT_MILLIS);
    const err = await p;
    expect(err).toBeInstanceOf(RelayError);
    expect(err.message).toMatch(/timed out/i);
  });

  it('ask: headers but a silent body for 15 s rejects', async () => {
    const p = client(scheduledSse([])).ask('Q?').catch((e) => e);
    await vi.advanceTimersByTimeAsync(RELAY_TIMEOUT_MILLIS);
    expect(await p).toBeInstanceOf(RelayError);
  });

  it('ask: after the first byte there is no limit while pings arrive; `: ping` is ignored', async () => {
    const deltas: string[] = [];
    const p = client(
      scheduledSse([
        [5_000, ': ping\n\n'],
        [14_000, ': ping\n\n'],
        [14_000, ': ping\n\n'],
        [14_000, 'data: {"delta":"Canberra."}\n\n'],
        [1_000, 'data: {"done":true}\n\n'],
      ]),
    ).ask('Q?', { onDelta: (d) => deltas.push(d) });
    await vi.advanceTimersByTimeAsync(60_000);
    await expect(p).resolves.toBe('Canberra.');
    expect(deltas).toEqual(['Canberra.']);
  });

  it('a caller abort is still an AbortError, not a timeout', async () => {
    const f = hangingFetch();
    const ac = new AbortController();
    const p = client(f.fn).ask('Q?', { signal: ac.signal }).catch((e) => e);
    ac.abort();
    await vi.advanceTimersByTimeAsync(0);
    expect((await p).name).toBe('AbortError');
  });
});

describe('startup never waits on the relay', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    document.body.innerHTML = '<main id="app"></main>';
  });
  afterEach(() => vi.useRealTimers());

  const relayStore = () => memoryStore({ [KEYS.apiKey]: 'k', [KEYS.relayUrl]: RELAY_URL, [KEYS.relayKey]: RELAY_KEY });

  it('App.init resolves while the relay hangs; the relay error lands after the timeout', async () => {
    const f = hangingFetch();
    const app = new App({ bridge: null, store: relayStore(), relayFetch: f.fn });
    const done = vi.fn();
    void app.init().then(done);
    await vi.advanceTimersByTimeAsync(0);
    expect(done).toHaveBeenCalled();
    expect(f.fn).toHaveBeenCalled();
    expect(app.state.preview).toContain('Helix Live');
    await vi.advanceTimersByTimeAsync(RELAY_TIMEOUT_MILLIS);
    expect(app.state.relayStatus).toMatch(/timed out/i);
    app.dispose();
  });

  it('startApp mounts the phone UI and the visibility re-arm while the relay hangs', async () => {
    const app = new App({ bridge: null, store: relayStore(), relayFetch: deafFetch });
    const resume = vi.spyOn(app, 'resume');
    const root = document.getElementById('app')!;
    const started = vi.fn();
    void startApp(root, app, document).then(started);
    await vi.advanceTimersByTimeAsync(0);
    expect(started).toHaveBeenCalled();
    expect(root.querySelector('#ask-form')).not.toBeNull();
    document.dispatchEvent(new Event('visibilitychange'));
    expect(resume).toHaveBeenCalled();
    app.dispose();
  });

  it('startApp still mounts the phone UI when init throws', async () => {
    const app = new App({ bridge: null, store: relayStore(), relayFetch: deafFetch });
    vi.spyOn(app, 'init').mockRejectedValue(new Error('store broke'));
    const root = document.getElementById('app')!;
    await startApp(root, app, document);
    expect(root.querySelector('#ask-form')).not.toBeNull();
    app.dispose();
  });
});
