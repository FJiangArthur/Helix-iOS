import http from 'node:http';
import type { AddressInfo } from 'node:net';
import { afterEach, describe, expect, it } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { RateLimitedError } from '../src/sources/omi.js';
import { emptySnapshot, Store } from '../src/store.js';
import { UpstreamError } from '../src/http.js';
import type { StreamChat, TodoItem } from '../src/types.js';
import { auth, buildTestApp, testConfig } from './helpers.js';

let app: FastifyInstance;
afterEach(async () => {
  await app?.close();
});

const NOW = Date.parse('2026-10-07T20:55:00Z'); // 1:55pm in Los Angeles
const todo = (id: string, dueAt: string | null, completed = false, title = `Task ${id}`): TodoItem => ({
  id,
  title,
  detail: '',
  completed,
  dueAt,
});

function seeded(): Store {
  const s = new Store(null);
  s.set({
    ...emptySnapshot(),
    generatedAt: '2026-10-07T20:45:00Z',
    briefing: ['Call with Acme at 3pm: bring the Q3 churn numbers.', '2 to-dos due today.'],
    news: [{ id: 'n1', title: 'Fed', detail: '', source: 'reuters.com', url: 'https://r/x', publishedAt: '2026-10-07T13:10:00Z' }],
    x: [{ id: 'x1', title: '@a: b', detail: 'b', url: 'https://x.com/a/status/x1' }],
    omi: [{ id: 'm1', title: 'Likes mornings', detail: 'Likes mornings', createdAt: '2026-10-06T09:00:00Z' }],
    todos: [
      todo('t1', '2026-10-07T21:00:00Z', false, 'Send Q3 churn deck to Sam'), // due in 5 min
      todo('t4', '2026-10-07T19:00:00Z'), // overdue
      todo('t5', '2026-10-07T21:30:00Z'), // 35 min away → not yet
      todo('t6', '2026-10-07T20:50:00Z', true), // completed
      todo('t7', null),
    ],
    dueAtOverrides: { t7x: '2026-10-07T22:00:00Z' },
  });
  return s;
}

describe('GET sub-resources', () => {
  it('serves /news, /x, /todos, /omi/memories from the cache', async () => {
    app = buildTestApp({ store: seeded() });
    for (const [url, key] of [
      ['/news', 'news'],
      ['/x', 'x'],
      ['/todos', 'todos'],
      ['/omi/memories', 'omi'],
    ] as const) {
      const res = await app.inject({ method: 'GET', url, headers: auth });
      expect(res.statusCode, url).toBe(200);
      expect(Object.keys(res.json())).toEqual([key]);
    }
  });
});

describe('PATCH /todos/:id', () => {
  it('forwards completion to Omi and returns the updated contract todo', async () => {
    const store = seeded();
    const calls: Array<[string, boolean]> = [];
    app = buildTestApp({
      store,
      patchTodo: async (id, completed) => {
        calls.push([id, completed]);
        return { id, description: 'Send Q3 churn deck to Sam', completed, due_at: '2026-10-07T21:00:00Z' };
      },
    });
    const res = await app.inject({ method: 'PATCH', url: '/todos/t1', headers: auth, payload: { completed: true } });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({
      ok: true,
      todo: { id: 't1', title: 'Send Q3 churn deck to Sam', detail: '', completed: true, dueAt: '2026-10-07T21:00:00Z' },
    });
    expect(calls).toEqual([['t1', true]]);
    expect(store.dashboard().todos.find((t) => t.id === 't1')?.completed).toBe(true);
  });

  it.each([[{}], [{ completed: 'yes' }], [null]])('rejects bad bodies with 400 (%j)', async (payload) => {
    app = buildTestApp({ store: seeded(), patchTodo: async () => Promise.reject(new Error('should not be called')) });
    const res = await app.inject({
      method: 'PATCH',
      url: '/todos/t1',
      headers: { ...auth, 'content-type': 'application/json' },
      payload: JSON.stringify(payload),
    });
    expect(res.statusCode).toBe(400);
    expect(res.json()).toHaveProperty('error');
  });

  it('maps Omi rate limiting to 429 with Retry-After and upstream 404 to 404', async () => {
    app = buildTestApp({
      store: seeded(),
      now: () => NOW,
      patchTodo: async () => {
        throw new RateLimitedError('action-write', NOW + 30_000);
      },
    });
    const limited = await app.inject({ method: 'PATCH', url: '/todos/t1', headers: auth, payload: { completed: true } });
    expect(limited.statusCode).toBe(429);
    expect(limited.headers['retry-after']).toBe('30');
    expect(limited.json()).toEqual({ error: 'rate_limited' });
    await app.close();

    app = buildTestApp({
      store: seeded(),
      patchTodo: async () => {
        throw new UpstreamError('omi', 404, 'not found');
      },
    });
    const missing = await app.inject({ method: 'PATCH', url: '/todos/zz', headers: auth, payload: { completed: true } });
    expect(missing.statusCode).toBe(404);
    expect(missing.json()).toEqual({ error: 'not_found' });
    await app.close();

    app = buildTestApp({
      store: seeded(),
      patchTodo: async () => {
        throw new Error('ECONNRESET');
      },
    });
    const broken = await app.inject({ method: 'PATCH', url: '/todos/t1', headers: auth, payload: { completed: true } });
    expect(broken.statusCode).toBe(502);
    expect(broken.json()).toEqual({ error: 'upstream_failed' });
  });
});

describe('GET /reminders', () => {
  it('returns due/overdue open to-dos after `since` plus the daily briefing', async () => {
    app = buildTestApp({ store: seeded(), now: () => NOW });
    const since = Date.parse('2026-10-07T06:00:00Z'); // 11pm LA the day before
    const res = await app.inject({ method: 'GET', url: `/reminders?since=${since}`, headers: auth });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({
      reminders: [
        { id: 'r-t4', kind: 'todo', text: 'Due 12pm: Task t4', dueAt: '2026-10-07T19:00:00Z' },
        { id: 'r-t1', kind: 'todo', text: 'Due 2pm: Send Q3 churn deck to Sam', dueAt: '2026-10-07T21:00:00Z' },
        { id: 'r-brief-2026-10-07', kind: 'briefing', text: 'Call with Acme at 3pm: bring the Q3 churn numbers.', dueAt: null },
      ],
    });
  });

  it('skips items already delivered (dueAt <= since) but includes today\'s briefing on every call', async () => {
    app = buildTestApp({ store: seeded(), now: () => NOW });
    const since = Date.parse('2026-10-07T20:00:00Z'); // 1pm LA, same local day
    const res = await app.inject({ method: 'GET', url: `/reminders?since=${since}`, headers: auth });
    expect(res.json()).toEqual({
      reminders: [
        { id: 'r-t1', kind: 'todo', text: 'Due 2pm: Send Q3 churn deck to Sam', dueAt: '2026-10-07T21:00:00Z' },
        { id: 'r-brief-2026-10-07', kind: 'briefing', text: 'Call with Acme at 3pm: bring the Q3 churn numbers.', dueAt: null },
      ],
    });
  });

  it('keys the briefing id by the local day in RELAY_TZ, not UTC', async () => {
    const lateEvening = Date.parse('2026-10-08T05:30:00Z'); // 10:30pm Oct 7 in Los Angeles, Oct 8 in UTC
    app = buildTestApp({ store: seeded(), now: () => lateEvening });
    const res = await app.inject({ method: 'GET', url: `/reminders?since=${lateEvening - 60_000}`, headers: auth });
    const ids = (res.json() as { reminders: Array<{ id: string }> }).reminders.map((r) => r.id);
    expect(ids).toContain('r-brief-2026-10-07');
    await app.close();

    app = buildTestApp({ store: seeded(), now: () => lateEvening, config: testConfig({ RELAY_TZ: 'UTC' }) });
    const utc = await app.inject({ method: 'GET', url: `/reminders?since=${lateEvening - 60_000}`, headers: auth });
    expect((utc.json() as { reminders: Array<{ id: string }> }).reminders.map((r) => r.id)).toContain('r-brief-2026-10-08');
  });

  it('defaults a missing since to 24h ago and rejects garbage', async () => {
    app = buildTestApp({ store: seeded(), now: () => NOW });
    const ok = await app.inject({ method: 'GET', url: '/reminders', headers: auth });
    expect(ok.statusCode).toBe(200);
    expect((ok.json() as { reminders: unknown[] }).reminders).toHaveLength(3);
    const bad = await app.inject({ method: 'GET', url: '/reminders?since=yesterday', headers: auth });
    expect(bad.statusCode).toBe(400);
    expect(bad.json()).toEqual({ error: 'invalid since' });
  });
});

function fakeStream(parts: string[], seen?: { model?: string; messages?: unknown[] }): StreamChat {
  return async function* (req) {
    if (seen) {
      seen.model = req.model;
      seen.messages = req.messages;
    }
    for (const p of parts) yield p;
  };
}

describe('POST /ask', () => {
  it('streams deltas as SSE and finishes with done', async () => {
    const seen: { model?: string; messages?: unknown[] } = {};
    app = buildTestApp({ streamChat: fakeStream(['Paris', ' is the capital.'], seen) });
    const res = await app.inject({
      method: 'POST',
      url: '/ask',
      headers: { ...auth, origin: 'https://hub.example' },
      payload: { question: 'Capital of France?', context: 'We were talking about travel.' },
    });
    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toMatch(/^text\/event-stream/);
    expect(res.headers['access-control-allow-origin']).toBe('https://hub.example');
    expect(res.body).toBe(
      'data: {"delta":"Paris"}\n\ndata: {"delta":" is the capital."}\n\ndata: {"done":true}\n\n',
    );
    expect(seen.model).toBe('gpt-5.4');
    expect(JSON.stringify(seen.messages)).toContain('We were talking about travel.');
    expect(JSON.stringify(seen.messages)).toContain('Capital of France?');
  });

  it('uses the deep model when deep:true', async () => {
    const seen: { model?: string } = {};
    app = buildTestApp({ config: testConfig(), streamChat: fakeStream(['ok'], seen) });
    await app.inject({ method: 'POST', url: '/ask', headers: auth, payload: { question: 'Why?', deep: true } });
    expect(seen.model).toBe('gpt-5.5');
  });

  it('emits an error event when the upstream fails', async () => {
    app = buildTestApp({
      streamChat: async function* () {
        yield 'par';
        throw new Error('codex-proxy: HTTP 502');
      },
    });
    const res = await app.inject({ method: 'POST', url: '/ask', headers: auth, payload: { question: 'q' } });
    expect(res.body).toBe('data: {"delta":"par"}\n\ndata: {"error":"codex-proxy: HTTP 502"}\n\n');
  });

  it.each([[{}], [{ question: '' }], [{ question: 'q', deep: 'yes' }], [{ question: 'q', context: 5 }]])(
    'rejects invalid bodies with 400 JSON (%j)',
    async (payload) => {
      app = buildTestApp({ streamChat: fakeStream(['x']) });
      const res = await app.inject({ method: 'POST', url: '/ask', headers: auth, payload });
      expect(res.statusCode).toBe(400);
      expect(res.json()).toHaveProperty('error');
    },
  );

  it('aborts the upstream stream when the client disconnects', async () => {
    let aborted = false;
    let resolveAborted!: () => void;
    const abortedP = new Promise<void>((r) => (resolveAborted = r));
    app = buildTestApp({
      streamChat: async function* (_req, signal) {
        yield 'first';
        await new Promise<void>((resolve) => {
          signal.addEventListener('abort', () => {
            aborted = true;
            resolveAborted();
            resolve();
          });
        });
      },
    });
    await app.listen({ port: 0, host: '127.0.0.1' });
    const { port } = app.server.address() as AddressInfo;
    await new Promise<void>((resolve, reject) => {
      const req = http.request(
        { host: '127.0.0.1', port, path: '/ask', method: 'POST', headers: { ...auth, 'content-type': 'application/json' } },
        (res) => {
          res.once('data', (chunk: Buffer) => {
            expect(chunk.toString()).toContain('"delta":"first"');
            req.destroy();
            resolve();
          });
        },
      );
      req.on('error', () => {});
      req.once('error', reject);
      req.end(JSON.stringify({ question: 'q' }));
    });
    await Promise.race([abortedP, new Promise((_, rej) => setTimeout(() => rej(new Error('upstream not aborted')), 3000))]);
    expect(aborted).toBe(true);
  });
});
