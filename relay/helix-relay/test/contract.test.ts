// Validates relay output against the canonical fixtures in conversate-core (CONTRACT-0.3 §7).
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, describe, expect, it } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { refresh, type RefreshSources } from '../src/refresh.js';
import { Store } from '../src/store.js';
import { auth, buildTestApp } from './helpers.js';

const FIXTURES = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../conversate-core/fixtures');
const fixture = (name: string) => JSON.parse(readFileSync(path.join(FIXTURES, name), 'utf8')) as unknown;


const typeOf = (v: unknown) => (v === null ? 'null' : Array.isArray(v) ? 'array' : typeof v);

/**
 * Check `actual` against `expected` (the fixture): same keys at every object level,
 * and every value's JSON type is one the fixture uses for that key across all of its
 * array elements (so `dueAt` may be string or null because the fixture shows both).
 */
function assertShape(actual: unknown, expected: unknown, where = '$'): void {
  if (Array.isArray(expected)) {
    expect(Array.isArray(actual), `${where} should be an array`).toBe(true);
    const objects = expected.filter((e) => e && typeof e === 'object' && !Array.isArray(e)) as Record<string, unknown>[];
    if (objects.length === 0) {
      const types = new Set(expected.map(typeOf));
      for (const [i, a] of (actual as unknown[]).entries()) expect(types.has(typeOf(a)), `${where}[${i}] type ${typeOf(a)}`).toBe(true);
      return;
    }
    const keys = Object.keys(objects[0]!).sort();
    const types: Record<string, Set<string>> = {};
    for (const o of objects) {
      expect(Object.keys(o).sort(), 'fixture items are uniform').toEqual(keys);
      for (const k of keys) (types[k] ??= new Set()).add(typeOf(o[k]));
    }
    for (const [i, a] of (actual as unknown[]).entries()) {
      expect(typeOf(a), `${where}[${i}]`).toBe('object');
      const obj = a as Record<string, unknown>;
      expect(Object.keys(obj).sort(), `${where}[${i}] keys`).toEqual(keys);
      for (const k of keys) {
        expect(types[k]!.has(typeOf(obj[k])), `${where}[${i}].${k}: ${typeOf(obj[k])} not in ${[...types[k]!]}`).toBe(true);
      }
    }
    return;
  }
  if (expected && typeof expected === 'object') {
    expect(typeOf(actual), where).toBe('object');
    const e = expected as Record<string, unknown>;
    const a = actual as Record<string, unknown>;
    expect(Object.keys(a).sort(), `${where} keys`).toEqual(Object.keys(e).sort());
    for (const k of Object.keys(e)) assertShape(a[k], e[k], `${where}.${k}`);
    return;
  }
  expect(typeOf(actual), where).toBe(typeOf(expected));
}

const ISO_UTC = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const NOW = Date.parse('2026-10-07T20:55:00Z');

const sources: RefreshSources = {
  listActionItems: async () => [
    { id: 't1', description: 'Send Q3 churn deck to Sam', completed: false, due_at: null, conversation_id: 'c1' },
    { id: 't2', description: 'Book dentist', completed: true, due_at: null },
    { id: 't3', description: 'x'.repeat(900), completed: false, due_at: '2026-10-07T20:50:00.000000+00:00' },
  ],
  listMemories: async () => [{ id: 'm1', content: 'Prefers morning meetings', created_at: '2026-10-06T09:00:00Z', category: 'interesting' }],
  getXPosts: async () => [{ id: 'x1', title: '@karpathy: new post on LLM evals', detail: 'Thread', url: 'https://x.com/karpathy/status/1' }],
  fetchFinnhub: async () => [
    { id: 'f-2', title: 'Nvidia unveils new data-center chip', detail: 'Ships in Q1.', source: 'finnhub', url: 'https://example.com/n2', publishedAt: '2026-10-07T12:00:00Z' },
  ],
  fetchRss: async () => [
    { id: 'r-1', title: 'Fed holds rates steady', detail: 'y'.repeat(50), source: 'reuters.com', url: 'https://www.reuters.com/x', publishedAt: '2026-10-07T13:10:00Z' },
  ],
  triage: async () =>
    JSON.stringify({
      briefing: ['Call with Acme at 3pm: bring the Q3 churn numbers.', '2 to-dos due today.', 'Nvidia earnings tonight.'],
      newsOrder: ['r-1', 'f-2'],
      dueAt: { t1: '2026-10-07T21:00:00Z' },
    }),
};

let app: FastifyInstance;
afterEach(async () => {
  await app?.close();
});

async function populatedApp() {
  const store = new Store(null);
  await refresh(store, sources, { now: () => NOW, timeZone: 'America/Los_Angeles', log: () => {} });
  return buildTestApp({ store, now: () => NOW });
}

describe('contract: relay output matches conversate-core fixtures', () => {
  it('the fixtures themselves satisfy the checker', () => {
    assertShape(fixture('relay-dashboard.json'), fixture('relay-dashboard.json'));
    assertShape(fixture('relay-reminders.json'), fixture('relay-reminders.json'));
  });

  it('GET /dashboard has exactly the fixture keys and types', async () => {
    app = await populatedApp();
    const res = await app.inject({ method: 'GET', url: '/dashboard', headers: auth });
    expect(res.statusCode).toBe(200);
    const body = res.json() as Record<string, unknown>;
    assertShape(body, fixture('relay-dashboard.json'));
    // Every list is non-empty here, so the per-item checks actually ran.
    for (const k of ['news', 'x', 'todos', 'omi', 'briefing']) expect((body[k] as unknown[]).length, k).toBeGreaterThan(0);
    const d = body as { generatedAt: string; todos: Array<{ title: string; detail: string; dueAt: string | null }>; news: Array<{ publishedAt: string }>; omi: Array<{ createdAt: string }> };
    expect(d.generatedAt).toMatch(ISO_UTC);
    for (const t of d.todos) {
      expect(t.title.length).toBeLessThanOrEqual(60);
      expect(t.detail.length).toBeLessThanOrEqual(600);
      if (t.dueAt) expect(t.dueAt).toMatch(ISO_UTC);
    }
    for (const n of d.news) expect(n.publishedAt).toMatch(ISO_UTC);
    for (const o of d.omi) expect(o.createdAt).toMatch(ISO_UTC);
  });

  it('a cold, empty dashboard still has the fixture keys', async () => {
    app = buildTestApp();
    const res = await app.inject({ method: 'GET', url: '/dashboard', headers: auth });
    assertShape(res.json(), fixture('relay-dashboard.json'));
  });

  it('GET /reminders has exactly the fixture keys and types (todo + briefing kinds)', async () => {
    app = await populatedApp();
    const res = await app.inject({ method: 'GET', url: `/reminders?since=${NOW - 16 * 3600_000}`, headers: auth });
    expect(res.statusCode).toBe(200);
    const body = res.json() as { reminders: Array<{ kind: string }> };
    assertShape(body, fixture('relay-reminders.json'));
    expect(new Set(body.reminders.map((r) => r.kind))).toEqual(new Set(['todo', 'briefing']));
  });

  it('GET /health matches §7', async () => {
    app = buildTestApp();
    expect((await app.inject({ method: 'GET', url: '/health' })).json()).toEqual({ ok: true, version: '0.3.0' });
  });
});
