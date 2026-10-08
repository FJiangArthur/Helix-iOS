import { mergeNews } from './sources/news.js';
import { toOmiItem, toTodo } from './sources/omi.js';
import type { Snapshot, Store } from './store.js';
import { isoUtc } from './text.js';
import { applyNewsOrder, buildTriageMessages, fallbackBriefing, parseTriage } from './triage.js';
import type { ChatMessage, NewsItem, OmiActionItem, OmiMemory, TodoItem, XItem } from './types.js';

export interface RefreshSources {
  listActionItems(): Promise<OmiActionItem[]>;
  listMemories(): Promise<OmiMemory[]>;
  getXPosts(): Promise<XItem[]>;
  fetchFinnhub(): Promise<NewsItem[]>;
  fetchRss(): Promise<NewsItem[]>;
  /** Run the triage chat completion and return the raw model text. */
  triage(messages: ChatMessage[]): Promise<string>;
}

export interface RefreshOptions {
  now: () => number;
  timeZone: string;
  log: (msg: string) => void;
}

const MAX_TODOS = 50;
const MAX_NEWS_TRIAGE = 40;
const MAX_NEWS = 20;
const MAX_X = 20;
const MAX_OMI = 20;

const errMsg = (e: unknown) => (e instanceof Error ? e.message : String(e));

function sortTodos(todos: TodoItem[]): TodoItem[] {
  const due = (t: TodoItem) => (t.dueAt ? Date.parse(t.dueAt) : Number.POSITIVE_INFINITY);
  return [...todos].sort((a, b) => Number(a.completed) - Number(b.completed) || due(a) - due(b));
}

/**
 * One refresh cycle. Each source is independent: a failure keeps that source's last good
 * value (empty on a cold cache) and never breaks the dashboard. The LLM only re-orders news,
 * writes the briefing and fills in due times; if it fails we keep the raw data.
 */
export async function refresh(store: Store, src: RefreshSources, opts: RefreshOptions): Promise<void> {
  const prev = store.get();
  const now = opts.now();
  const [items, memories, xPosts, finnhub, rss] = await Promise.allSettled([
    src.listActionItems(),
    src.listMemories(),
    src.getXPosts(),
    src.fetchFinnhub(),
    src.fetchRss(),
  ]);
  const fail = (name: string, r: PromiseSettledResult<unknown>) => {
    if (r.status === 'rejected') opts.log(`refresh: ${name} failed: ${errMsg(r.reason)}`);
  };
  fail('omi action items', items);
  fail('omi memories', memories);
  fail('omi x posts', xPosts);
  fail('finnhub', finnhub);
  fail('rss', rss);

  // To-dos: keep LLM overrides only for items that still exist and still lack an Omi due_at.
  let overrides = prev.dueAtOverrides;
  let todos: TodoItem[];
  if (items.status === 'fulfilled') {
    const live = items.value;
    overrides = Object.fromEntries(
      Object.entries(overrides).filter(([id]) => live.some((i) => i.id === id && !i.due_at)),
    );
    todos = live.map((i) => toTodo(i, overrides));
  } else {
    todos = prev.todos;
  }

  const memoryTexts = memories.status === 'fulfilled' ? memories.value.map((m) => m.content) : [];
  const omi =
    memories.status === 'fulfilled'
      ? [...memories.value]
          .sort((a, b) => (Date.parse(b.created_at ?? '') || 0) - (Date.parse(a.created_at ?? '') || 0))
          .slice(0, MAX_OMI)
          .map(toOmiItem)
      : prev.omi;

  let news: NewsItem[];
  if (finnhub.status === 'rejected' && rss.status === 'rejected') news = prev.news;
  else
    news = mergeNews(
      finnhub.status === 'fulfilled' ? finnhub.value : [],
      rss.status === 'fulfilled' ? rss.value : [],
    ).slice(0, MAX_NEWS_TRIAGE);

  const x = xPosts.status === 'fulfilled' ? xPosts.value.slice(0, MAX_X) : prev.x;

  // LLM triage.
  const input = { now, timeZone: opts.timeZone, memories: memoryTexts, news, todos };
  let briefing: string[] | null = null;
  try {
    const parsed = parseTriage(await src.triage(buildTriageMessages(input)), input);
    if (parsed) {
      briefing = parsed.briefing;
      news = applyNewsOrder(news, parsed.newsOrder);
      if (Object.keys(parsed.dueAt).length > 0) {
        overrides = { ...overrides, ...parsed.dueAt };
        todos = todos.map((t) => (!t.dueAt && parsed.dueAt[t.id] ? { ...t, dueAt: parsed.dueAt[t.id]! } : t));
      }
    } else {
      opts.log('refresh: triage returned invalid JSON; keeping raw data');
    }
  } catch (e) {
    opts.log(`refresh: triage failed: ${errMsg(e)}`);
  }
  if (briefing === null) briefing = fallbackBriefing(todos, news, now, opts.timeZone);

  const next: Snapshot = {
    generatedAt: isoUtc(now)!,
    briefing,
    news: news.slice(0, MAX_NEWS),
    x,
    todos: sortTodos(todos).slice(0, MAX_TODOS),
    omi,
    dueAtOverrides: overrides,
  };
  store.set(next);
  try {
    await store.save();
  } catch (e) {
    opts.log(`refresh: could not persist cache: ${errMsg(e)}`);
  }
}

/** Run `job` now and every `minutes`; a tick is skipped while the previous run is still going. */
export function startScheduler(job: () => Promise<void>, minutes: number, log: (msg: string) => void): () => void {
  let running = false;
  const tick = () => {
    if (running) return;
    running = true;
    job()
      .catch((e: unknown) => log(`scheduler: job failed: ${errMsg(e)}`))
      .finally(() => {
        running = false;
      });
  };
  tick();
  const timer = setInterval(tick, minutes * 60_000);
  timer.unref();
  return () => clearInterval(timer);
}
