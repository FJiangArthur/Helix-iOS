import { describe, expect, it } from 'vitest';
import { normalizeRelayUrl, RelayClient, RelayError } from '../src/relay/client';
import { DashboardSource, dashboardRows } from '../src/relay/dashboard';
import { dashboardFixture, fakeRelay, RELAY_KEY as KEY, RELAY_URL as BASE } from './fakeRelay';

const client = (f: ReturnType<typeof fakeRelay>, key = KEY) => new RelayClient({ url: BASE + '/', key }, f.fetchFn);

describe('RelayClient', () => {
  it('normalizes the relay URL and rejects non-http(s) ones', () => {
    expect(normalizeRelayUrl(' https://mac.ts.net/ ')).toBe('https://mac.ts.net');
    expect(normalizeRelayUrl('mac.ts.net')).toBe('https://mac.ts.net');
    expect(normalizeRelayUrl('ftp://x')).toBeNull();
    // Security: the bearer key never travels in cleartext except to loopback.
    expect(normalizeRelayUrl('http://mac.example.com:8790')).toBeNull();
    expect(normalizeRelayUrl('http://127.0.0.1:8790')).toBe('http://127.0.0.1:8790');
    expect(normalizeRelayUrl('http://localhost:8790')).toBe('http://localhost:8790');
    expect(normalizeRelayUrl('')).toBeNull();
  });

  it('health needs no key', async () => {
    const f = fakeRelay();
    await expect(client(f, 'wrong').health()).resolves.toEqual({ ok: true, version: '0.3.0' });
    expect(f.calls[0]!.url).toBe(`${BASE}/health`);
  });

  it('getDashboard sends the bearer key and returns the fixture', async () => {
    const f = fakeRelay();
    const d = await client(f).getDashboard();
    expect(new Headers(f.calls[0]!.init.headers).get('authorization')).toBe(`Bearer ${KEY}`);
    expect(d.briefing).toHaveLength(3);
    expect(d.todos.map((t) => t.id)).toEqual(['t1', 't2']);
  });

  it('a wrong key is a RelayError with status 401', async () => {
    const f = fakeRelay();
    const err = await client(f, 'nope').getDashboard().catch((e) => e);
    expect(err).toBeInstanceOf(RelayError);
    expect(err.status).toBe(401);
    expect(err.message).toMatch(/unauthorized/);
  });

  it('network failure is a RelayError without status', async () => {
    const err = await client(fakeRelay({ fail: true })).getDashboard().catch((e) => e);
    expect(err).toBeInstanceOf(RelayError);
    expect(err.status).toBeUndefined();
  });

  it('patchTodo PATCHes {completed} and returns the todo', async () => {
    const f = fakeRelay();
    const todo = await client(f).patchTodo('t 1', true);
    expect(f.calls[0]!.url).toBe(`${BASE}/todos/t%201`);
    expect(f.calls[0]!.init.method).toBe('PATCH');
    expect(JSON.parse(String(f.calls[0]!.init.body))).toEqual({ completed: true });
    expect(todo?.completed).toBe(true);
  });

  it('getReminders passes since and returns the list', async () => {
    const f = fakeRelay();
    const r = await client(f).getReminders(1234);
    expect(f.calls[0]!.url).toBe(`${BASE}/reminders?since=1234`);
    expect(r.map((x) => x.id)).toEqual(['r-t1', 'r-brief-2026-10-07']);
  });

  it('ask streams SSE deltas split across chunks and resolves the full answer', async () => {
    const f = fakeRelay({ sse: ['data: {"delta":"Can', 'berra"}\n\ndata: {"delta":" is the capital."}\n', '\ndata: {"done":true}\n\n'] });
    const deltas: string[] = [];
    const answer = await client(f).ask('Capital of Australia?', { context: 'ctx', deep: true, onDelta: (d) => deltas.push(d) });
    expect(answer).toBe('Canberra is the capital.');
    expect(deltas).toEqual(['Canberra', ' is the capital.']);
    expect(JSON.parse(String(f.calls[0]!.init.body))).toEqual({ question: 'Capital of Australia?', context: 'ctx', deep: true });
  });

  it('ask surfaces a relay error event', async () => {
    const f = fakeRelay({ sse: ['data: {"error":"upstream down"}\n\n'] });
    await expect(client(f).ask('q')).rejects.toThrow(/upstream down/);
  });

  it('ask can be cancelled with an AbortSignal', async () => {
    const f = fakeRelay({ sse: ['data: {"delta":"a"}\n\n', 'data: {"delta":"b"}\n\n'] });
    const ac = new AbortController();
    const p = client(f).ask('q', { signal: ac.signal, onDelta: () => ac.abort() });
    await expect(p).rejects.toMatchObject({ name: 'AbortError' });
  });
});

describe('DashboardSource', () => {
  it('maps dashboard sections to panel rows (todos carry done)', () => {
    const rows = dashboardRows(dashboardFixture as never, 'todos');
    expect(rows).toEqual([
      { id: 't1', title: 'Send Q3 churn deck to Sam', detail: "From Omi conversation 'Acme sync'.", done: false },
      { id: 't2', title: 'Book dentist', detail: '', done: true },
    ]);
    expect(dashboardRows(dashboardFixture as never, 'news')[0]).toEqual({
      id: 'n1', title: 'Fed holds rates steady', detail: 'The Federal Reserve kept rates at 4.25-4.50% and signalled one cut this year.',
    });
  });

  it('caches the dashboard for 60 s and refetches after', async () => {
    let now = 0;
    const f = fakeRelay();
    const src = new DashboardSource(() => client(f), () => now);
    await src.dashboard();
    await src.dashboard();
    expect(f.fetchFn).toHaveBeenCalledTimes(1);
    now += 60_001;
    await src.dashboard();
    expect(f.fetchFn).toHaveBeenCalledTimes(2);
    await src.dashboard(true);
    expect(f.fetchFn).toHaveBeenCalledTimes(3);
  });

  it('concurrent requests share one fetch', async () => {
    const f = fakeRelay();
    const src = new DashboardSource(() => client(f), () => 0);
    await Promise.all([src.dashboard(), src.dashboard()]);
    expect(f.fetchFn).toHaveBeenCalledTimes(1);
  });

  it('keeps the last good dashboard when the relay becomes unreachable', async () => {
    let now = 0;
    let f = fakeRelay();
    const src = new DashboardSource(() => client(f), () => now);
    await src.dashboard();
    f = fakeRelay({ fail: true });
    now += 120_000;
    const d = await src.dashboard();
    expect(d?.briefing).toHaveLength(3);
    expect(src.lastError).toMatch(/fetch/i);
  });

  it('is null when no relay is configured', async () => {
    const src = new DashboardSource(() => null, () => 0);
    expect(await src.dashboard()).toBeNull();
    expect(src.rows('news')).toEqual([]);
  });

  it('patching a todo updates the cached row', async () => {
    const f = fakeRelay();
    const src = new DashboardSource(() => client(f), () => 0);
    await src.dashboard();
    await src.toggleTodo('t1', true);
    expect(src.rows('todos')[0]!.done).toBe(true);
  });
});
