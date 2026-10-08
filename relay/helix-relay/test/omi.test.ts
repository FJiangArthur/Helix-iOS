import { MockAgent, getGlobalDispatcher, setGlobalDispatcher, type Dispatcher } from 'undici';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { OmiClient, RateLimitedError, toOmiItem, toTodo } from '../src/sources/omi.js';
import { isoUtc, truncate } from '../src/text.js';

const BASE = 'https://api.omi.me';
let agent: MockAgent;
let prev: Dispatcher;
let clock = 1_800_000_000_000;

beforeEach(() => {
  prev = getGlobalDispatcher();
  agent = new MockAgent();
  agent.disableNetConnect();
  setGlobalDispatcher(agent);
  clock = 1_800_000_000_000;
});
afterEach(async () => {
  setGlobalDispatcher(prev);
  await agent.close();
});

const client = () => new OmiClient({ baseUrl: BASE, key: 'omi_dev_k', timeoutMs: 2000 }, () => clock);

describe('text helpers', () => {
  it('truncates with an ellipsis inside the limit and collapses whitespace', () => {
    expect(truncate('a  b\n c', 60)).toBe('a b c');
    const t = truncate('x'.repeat(100), 60);
    expect(t.length).toBe(60);
    expect(t.endsWith('…')).toBe(true);
  });
  it('formats ISO-8601 UTC without milliseconds', () => {
    expect(isoUtc('2026-10-07T21:00:00.123456+00:00')).toBe('2026-10-07T21:00:00Z');
    expect(isoUtc('garbage')).toBeNull();
    expect(isoUtc(null)).toBeNull();
  });
});

describe('OmiClient', () => {
  it('lists action items with the dev key', async () => {
    agent
      .get(BASE)
      .intercept({
        path: (p) => p.startsWith('/v1/dev/user/action-items'),
        method: 'GET',
        headers: { authorization: 'Bearer omi_dev_k' },
      })
      .reply(200, [{ id: 'a1', description: 'Send deck', completed: false, due_at: null }]);
    const items = await client().listActionItems();
    expect(items).toHaveLength(1);
    expect(items[0]?.id).toBe('a1');
  });

  it('PATCHes completion to /action-items/{id}', async () => {
    let body = '';
    agent
      .get(BASE)
      .intercept({
        path: '/v1/dev/user/action-items/a%2F1',
        method: 'PATCH',
        body: (b) => {
          body = b;
          return true;
        },
      })
      .reply(200, { id: 'a/1', description: 'Send deck', completed: true, due_at: '2026-10-07T21:00:00Z' });
    const item = await client().patchActionItem('a/1', true);
    expect(JSON.parse(body)).toEqual({ completed: true });
    expect(item.completed).toBe(true);
  });

  it('honours 429 Retry-After and does not call upstream until it elapses', async () => {
    const pool = agent.get(BASE);
    pool
      .intercept({ path: (p) => p.startsWith('/v1/dev/user/memories'), method: 'GET' })
      .reply(429, { detail: 'slow down' }, { headers: { 'retry-after': '120' } });
    const c = client();
    await expect(c.listMemories()).rejects.toBeInstanceOf(RateLimitedError);
    // Still inside the window: no interceptor registered, so a network call would throw a MockAgent error.
    clock += 60_000;
    const err = await c.listMemories().catch((e: unknown) => e);
    expect(err).toBeInstanceOf(RateLimitedError);
    expect((err as RateLimitedError).retryAt).toBe(1_800_000_000_000 + 120_000);
    // After the window it calls again.
    clock += 61_000;
    pool
      .intercept({ path: (p) => p.startsWith('/v1/dev/user/memories'), method: 'GET' })
      .reply(200, [{ id: 'm1', content: 'Likes mornings', created_at: '2026-10-06T09:00:00Z' }]);
    await expect(c.listMemories()).resolves.toHaveLength(1);
  });

  it('treats 403 developer_memory_access_not_ready as an empty list', async () => {
    agent
      .get(BASE)
      .intercept({ path: (p) => p.startsWith('/v1/dev/user/memories'), method: 'GET' })
      .reply(403, {
        detail: { code: 'developer_memory_access_not_ready', message: 'Developer Memory API access is not enabled' },
      });
    await expect(client().listMemories()).resolves.toEqual([]);
  });

  it('throws on other upstream errors', async () => {
    agent
      .get(BASE)
      .intercept({ path: (p) => p.startsWith('/v1/dev/user/action-items'), method: 'GET' })
      .reply(500, 'boom');
    await expect(client().listActionItems()).rejects.toThrow(/500/);
  });

  it('refuses to call without a key', async () => {
    const c = new OmiClient({ baseUrl: BASE, key: undefined, timeoutMs: 1000 }, () => clock);
    await expect(c.listActionItems()).rejects.toThrow(/OMI_DEV_KEY/);
  });
});

describe('mapping', () => {
  it('maps an action item to a contract todo, using the LLM due override only when Omi has none', () => {
    const long = 'Send the Q3 churn deck to Sam and include the cohort breakdown for enterprise accounts';
    const t = toTodo({ id: 't1', description: long, completed: false, due_at: null }, { t1: '2026-10-07T21:00:00Z' });
    expect(t).toEqual({
      id: 't1',
      title: truncate(long, 60),
      detail: long,
      completed: false,
      dueAt: '2026-10-07T21:00:00Z',
    });
    const t2 = toTodo({ id: 't2', description: 'Book dentist', completed: true, due_at: '2026-10-08T16:00:00.000000Z' }, { t2: 'x' });
    expect(t2).toEqual({ id: 't2', title: 'Book dentist', detail: '', completed: true, dueAt: '2026-10-08T16:00:00Z' });
  });

  it('maps a memory to a contract omi item', () => {
    expect(toOmiItem({ id: 'm1', content: 'Prefers morning meetings', created_at: '2026-10-06T09:00:00Z' })).toEqual({
      id: 'm1',
      title: 'Prefers morning meetings',
      detail: 'Prefers morning meetings',
      createdAt: '2026-10-06T09:00:00Z',
    });
  });
});
