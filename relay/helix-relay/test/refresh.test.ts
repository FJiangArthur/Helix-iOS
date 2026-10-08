import { mkdtemp, readFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { refresh, startScheduler, type RefreshSources } from '../src/refresh.js';
import { Store } from '../src/store.js';
import type { ChatMessage } from '../src/types.js';

const NOW = Date.parse('2026-10-07T15:00:00Z');
const opts = { now: () => NOW, timeZone: 'America/Los_Angeles', log: () => {} };

function sources(over: Partial<RefreshSources> = {}): RefreshSources {
  return {
    listActionItems: async () => [
      { id: 't2', description: 'Book dentist', completed: true, due_at: null },
      { id: 't1', description: 'Send Q3 churn deck to Sam by 2pm', completed: false, due_at: null },
      { id: 't3', description: 'Renew passport', completed: false, due_at: '2026-10-20T00:00:00Z' },
    ],
    listMemories: async () => [{ id: 'm1', content: 'Prefers morning meetings', created_at: '2026-10-06T09:00:00Z' }],
    getXPosts: async () => [{ id: 'x1', title: '@karpathy: evals', detail: 'evals', url: 'https://x.com/karpathy/status/x1' }],
    fetchFinnhub: async () => [
      { id: 'f-1', title: 'Nvidia chip', detail: '', source: 'Reuters', url: 'https://e/1', publishedAt: '2026-10-07T12:00:00Z' },
    ],
    fetchRss: async () => [
      { id: 'r-1', title: 'Fed holds', detail: '', source: 'reuters.com', url: 'https://e/2', publishedAt: '2026-10-07T13:00:00Z' },
    ],
    triage: async () =>
      JSON.stringify({ briefing: ['Deck to Sam due 2pm.', 'Nvidia chip news.'], newsOrder: ['f-1'], dueAt: { t1: '2026-10-07T21:00:00Z' } }),
    ...over,
  };
}

let tmp: string | undefined;
afterEach(async () => {
  if (tmp) await rm(tmp, { recursive: true, force: true });
  tmp = undefined;
  vi.useRealTimers();
});

describe('refresh job', () => {
  it('builds the dashboard: ranked news, LLM due times, briefing, open to-dos first', async () => {
    const store = new Store(null);
    let msgs: ChatMessage[] = [];
    await refresh(store, sources({ triage: async (m) => ((msgs = m), sources().triage(m)) }), opts);
    const d = store.dashboard();
    expect(d.generatedAt).toBe('2026-10-07T15:00:00Z');
    expect(d.briefing).toEqual(['Deck to Sam due 2pm.', 'Nvidia chip news.']);
    expect(d.news.map((n) => n.id)).toEqual(['f-1', 'r-1']);
    expect(d.todos.map((t) => [t.id, t.dueAt])).toEqual([
      ['t1', '2026-10-07T21:00:00Z'],
      ['t3', '2026-10-20T00:00:00Z'],
      ['t2', null],
    ]);
    expect(d.x).toHaveLength(1);
    expect(d.omi[0]?.title).toBe('Prefers morning meetings');
    expect(msgs[1]?.content).toContain('Prefers morning meetings');
    expect(store.get().dueAtOverrides).toEqual({ t1: '2026-10-07T21:00:00Z' });
  });

  it('keeps raw to-dos and uses a deterministic briefing when the LLM output is invalid or the call fails', async () => {
    for (const triage of [async () => 'sorry, I cannot', async () => Promise.reject(new Error('proxy down'))]) {
      const store = new Store(null);
      await refresh(store, sources({ triage }), opts);
      const d = store.dashboard();
      expect(d.todos.find((t) => t.id === 't1')?.dueAt).toBeNull();
      expect(d.briefing).toEqual(['2 open to-dos.', 'Fed holds']);
      expect(d.news.map((n) => n.id)).toEqual(['r-1', 'f-1']);
    }
  });

  it('a failing source yields an empty array on a cold cache and never breaks the others', async () => {
    const store = new Store(null);
    const boom = async () => Promise.reject(new Error('down'));
    await refresh(
      store,
      sources({ listActionItems: boom, listMemories: boom, fetchFinnhub: boom, fetchRss: boom, getXPosts: boom }),
      opts,
    );
    const d = store.dashboard();
    expect(d.todos).toEqual([]);
    expect(d.omi).toEqual([]);
    expect(d.news).toEqual([]);
    expect(d.x).toEqual([]);
    expect(d.generatedAt).toBe('2026-10-07T15:00:00Z');
  });

  it('keeps the last good value of a source that fails (e.g. Omi 429 backoff)', async () => {
    const store = new Store(null);
    await refresh(store, sources(), opts);
    await refresh(store, sources({ listActionItems: async () => Promise.reject(new Error('429')) }), opts);
    expect(store.dashboard().todos.map((t) => t.id)).toEqual(['t1', 't3', 't2']);
    // LLM due override survives because the item still exists.
    expect(store.dashboard().todos[0]?.dueAt).toBe('2026-10-07T21:00:00Z');
  });

  it('does not ask the LLM again for a to-do it already resolved, and prunes overrides for vanished items', async () => {
    const store = new Store(null);
    await refresh(store, sources(), opts);
    let second = '';
    await refresh(
      store,
      sources({
        listActionItems: async () => [{ id: 't9', description: 'Call mom tomorrow', completed: false, due_at: null }],
        triage: async (m) => ((second = m[1]?.content ?? ''), JSON.stringify({ briefing: [] })),
      }),
      opts,
    );
    expect(second).not.toContain('t1:');
    expect(second).toContain('t9: Call mom tomorrow');
    expect(store.get().dueAtOverrides).toEqual({});
  });

  it('persists the cache to disk and reloads it', async () => {
    tmp = await mkdtemp(path.join(os.tmpdir(), 'helix-relay-'));
    const store = Store.forDataDir(tmp);
    await refresh(store, sources(), opts);
    const onDisk = JSON.parse(await readFile(path.join(tmp, 'cache.json'), 'utf8')) as { todos: unknown[] };
    expect(onDisk.todos).toHaveLength(3);
    const again = Store.forDataDir(tmp);
    await again.load();
    expect(again.dashboard()).toEqual(store.dashboard());
  });
});

describe('scheduler', () => {
  it('runs immediately, then every N minutes, never overlapping', async () => {
    vi.useFakeTimers();
    let running = 0;
    let maxRunning = 0;
    let runs = 0;
    const job = async () => {
      runs++;
      running++;
      maxRunning = Math.max(maxRunning, running);
      await new Promise((r) => setTimeout(r, 20 * 60_000)); // slower than the interval
      running--;
    };
    const stop = startScheduler(job, 15, () => {});
    expect(runs).toBe(1);
    await vi.advanceTimersByTimeAsync(15 * 60_000);
    expect(runs).toBe(1); // previous run still in flight → skipped
    await vi.advanceTimersByTimeAsync(15 * 60_000);
    expect(runs).toBe(2);
    expect(maxRunning).toBe(1);
    stop();
  });
});
