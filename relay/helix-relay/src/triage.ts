import { isoUtc, title, truncate } from './text.js';
import { dayKey } from './time.js';
import type { ChatMessage, NewsItem, TodoItem } from './types.js';

export interface TriageInput {
  now: number;
  timeZone: string;
  /** Omi memory texts — the user's interests/facts used to rank news. */
  memories: string[];
  news: NewsItem[];
  todos: TodoItem[];
}

export interface TriageResult {
  briefing: string[];
  newsOrder: string[];
  dueAt: Record<string, string>;
}

const MAX_MEMORIES = 40;
const MAX_NEWS = 40;
const MAX_TODOS = 40;

const SYSTEM = [
  'You triage a personal dashboard shown on smart-glasses. Reply with ONE JSON object and nothing else:',
  '{"briefing": string[], "newsOrder": string[], "dueAt": {"<todoId>": "<ISO-8601 UTC>"}}',
  '- briefing: at most 3 short lines (each ≤ 60 characters), the most useful things for the user right now:',
  '  imminent to-dos, then news that matters given their memories. Plain text, no bullets or emoji.',
  '- newsOrder: news ids ordered by relevance to the user (memories = their interests/work); omit irrelevant ones.',
  '- dueAt: ONLY for listed to-dos whose text clearly implies a time or date ("by 2pm", "tomorrow", "Friday").',
  '  Resolve relative times against the given current time and time zone; output UTC. Omit a to-do when unsure.',
].join('\n');

export function openTodosLackingDue(todos: TodoItem[]): TodoItem[] {
  return todos.filter((t) => !t.completed && !t.dueAt);
}

export function buildTriageMessages(input: TriageInput): ChatMessage[] {
  const nowIso = isoUtc(input.now)!;
  const memories = input.memories.slice(0, MAX_MEMORIES).map((m) => `- ${truncate(m, 200)}`);
  const news = input.news.slice(0, MAX_NEWS).map((n) => `- ${n.id}: ${n.title} (${n.source})`);
  const open = input.todos.filter((t) => !t.completed).slice(0, MAX_TODOS);
  const openLines = open.map((t) => `- ${t.title}${t.dueAt ? ` (due ${t.dueAt})` : ''}`);
  const needDue = openTodosLackingDue(input.todos)
    .slice(0, MAX_TODOS)
    .map((t) => `- ${t.id}: ${t.detail || t.title}`);
  const user = [
    `Current time: ${nowIso} (user time zone: ${input.timeZone})`,
    '',
    'User memories:',
    ...(memories.length ? memories : ['(none)']),
    '',
    'Open to-dos:',
    ...(openLines.length ? openLines : ['(none)']),
    '',
    'To-dos needing a due time (id: text):',
    ...(needDue.length ? needDue : ['(none)']),
    '',
    'News (id: headline):',
    ...(news.length ? news : ['(none)']),
  ].join('\n');
  return [
    { role: 'system', content: SYSTEM },
    { role: 'user', content: user },
  ];
}

function extractJson(raw: string): unknown {
  const fenced = /```(?:json)?\s*([\s\S]*?)```/i.exec(raw);
  const body = (fenced?.[1] ?? raw).trim();
  const start = body.indexOf('{');
  const end = body.lastIndexOf('}');
  if (start === -1 || end <= start) return undefined;
  try {
    return JSON.parse(body.slice(start, end + 1));
  } catch {
    return undefined;
  }
}

const MAX_PAST_MS = 7 * 24 * 3600 * 1000;
const MAX_FUTURE_MS = 400 * 24 * 3600 * 1000;

/** Validate the model's JSON. Invalid → null (caller keeps raw data + deterministic briefing). */
export function parseTriage(raw: string, input: TriageInput): TriageResult | null {
  const obj = extractJson(raw) as Record<string, unknown> | undefined;
  if (!obj || typeof obj !== 'object' || Array.isArray(obj)) return null;
  const b = obj.briefing;
  if (!Array.isArray(b) || !b.every((l) => typeof l === 'string')) return null;
  const briefing = (b as string[]).map((l) => title(l)).filter(Boolean).slice(0, 3);

  const known = new Set(input.news.map((n) => n.id));
  const newsOrder = Array.isArray(obj.newsOrder)
    ? [...new Set((obj.newsOrder as unknown[]).filter((id): id is string => typeof id === 'string' && known.has(id)))]
    : [];

  const asked = new Set(openTodosLackingDue(input.todos).map((t) => t.id));
  const dueAt: Record<string, string> = {};
  if (obj.dueAt && typeof obj.dueAt === 'object' && !Array.isArray(obj.dueAt)) {
    for (const [id, v] of Object.entries(obj.dueAt as Record<string, unknown>)) {
      if (!asked.has(id) || typeof v !== 'string') continue;
      const iso = isoUtc(v);
      if (!iso) continue;
      const t = Date.parse(iso);
      if (t < input.now - MAX_PAST_MS || t > input.now + MAX_FUTURE_MS) continue;
      dueAt[id] = iso;
    }
  }
  return { briefing, newsOrder, dueAt };
}

export function applyNewsOrder(news: NewsItem[], order: string[]): NewsItem[] {
  const byId = new Map(news.map((n) => [n.id, n]));
  const ranked = order.map((id) => byId.get(id)).filter((n): n is NewsItem => !!n);
  const rest = news.filter((n) => !order.includes(n.id));
  return [...ranked, ...rest];
}

/** Briefing used when the LLM is unavailable or returns garbage. */
export function fallbackBriefing(todos: TodoItem[], news: NewsItem[], now: number, timeZone: string): string[] {
  const out: string[] = [];
  const open = todos.filter((t) => !t.completed);
  const today = dayKey(now, timeZone);
  const dueToday = open.filter((t) => t.dueAt && dayKey(Date.parse(t.dueAt), timeZone) === today).length;
  if (open.length > 0) {
    out.push(
      dueToday > 0
        ? `${dueToday} to-do${dueToday > 1 ? 's' : ''} due today, ${open.length} open.`
        : `${open.length} open to-do${open.length > 1 ? 's' : ''}.`,
    );
  }
  if (news[0]) out.push(news[0].title);
  return out.map((l) => title(l)).slice(0, 3);
}
