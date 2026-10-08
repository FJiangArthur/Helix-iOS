// Fake helix-relay for tests: serves the conversate-core fixtures and enforces
// the bearer key (CONTRACT-0.3.md §7).
import dashboardFixture from '@core-contract/fixtures/relay-dashboard.json';
import remindersFixture from '@core-contract/fixtures/relay-reminders.json';
import { vi } from 'vitest';

export const RELAY_URL = 'https://mac.tail1234.ts.net';
export const RELAY_KEY = 'relay-test-key';

export interface RelayCall { url: string; init: RequestInit }

export interface FakeRelayOptions {
  sse?: string[];
  fail?: boolean;
  failPatch?: boolean;
  reminders?: unknown;
  /** /ask keeps the stream open after the last chunk (an Ask still in flight). */
  hang?: boolean;
}

export function fakeRelay(opts: FakeRelayOptions = {}) {
  const calls: RelayCall[] = [];
  const state = { ...opts };
  const fetchFn = vi.fn(async (url: string, init: RequestInit = {}) => {
    calls.push({ url, init });
    if (state.fail) throw new TypeError('Failed to fetch');
    const path = new URL(url).pathname;
    const auth = new Headers(init.headers).get('authorization');
    if (path === '/health') return Response.json({ ok: true, version: '0.3.0' });
    if (auth !== `Bearer ${RELAY_KEY}`) return Response.json({ error: 'unauthorized' }, { status: 401 });
    if (path === '/dashboard') return Response.json(dashboardFixture);
    if (path === '/reminders') return Response.json(state.reminders ?? remindersFixture);
    if (path.startsWith('/todos/') && init.method === 'PATCH') {
      if (state.failPatch) return Response.json({ error: 'omi down' }, { status: 502 });
      const body = JSON.parse(String(init.body));
      return Response.json({ ok: true, todo: { ...dashboardFixture.todos[0], id: decodeURIComponent(path.slice(7)), completed: body.completed } });
    }
    if (path === '/ask' && init.method === 'POST') {
      const enc = new TextEncoder();
      const chunks = [...(state.sse ?? ['data: {"delta":"Canberra."}\n\n', 'data: {"done":true}\n\n'])];
      const signal = init.signal;
      const stream = new ReadableStream<Uint8Array>({
        async pull(controller) {
          if (signal?.aborted) { controller.error(new DOMException('aborted', 'AbortError')); return; }
          const next = chunks.shift();
          if (next === undefined && state.hang) {
            await new Promise<void>((resolve) => signal?.addEventListener('abort', () => resolve(), { once: true }));
            controller.error(new DOMException('aborted', 'AbortError'));
          } else if (next === undefined) controller.close();
          else controller.enqueue(enc.encode(next));
        },
      });
      return new Response(stream, { headers: { 'content-type': 'text/event-stream' } });
    }
    return Response.json({ error: 'not found' }, { status: 404 });
  });
  return { calls, fetchFn, state, of: (path: string) => calls.filter((c) => new URL(c.url).pathname.startsWith(path)) };
}

export { dashboardFixture, remindersFixture };
