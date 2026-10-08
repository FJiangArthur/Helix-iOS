import { describe, expect, it } from 'vitest';
import { applyNewsOrder, buildTriageMessages, fallbackBriefing, parseTriage, type TriageInput } from '../src/triage.js';
import type { NewsItem, TodoItem } from '../src/types.js';

const NOW = Date.parse('2026-10-07T15:00:00Z');
const news: NewsItem[] = [
  { id: 'n1', title: 'Fed holds rates steady', detail: '', source: 'reuters.com', url: 'u1', publishedAt: '2026-10-07T13:10:00Z' },
  { id: 'n2', title: 'Nvidia unveils new chip', detail: '', source: 'finnhub', url: 'u2', publishedAt: '2026-10-07T12:00:00Z' },
  { id: 'n3', title: 'Local weather', detail: '', source: 'x', url: 'u3', publishedAt: '2026-10-07T11:00:00Z' },
];
const todos: TodoItem[] = [
  { id: 't1', title: 'Send Q3 churn deck to Sam by 2pm', detail: '', completed: false, dueAt: null },
  { id: 't2', title: 'Book dentist', detail: '', completed: false, dueAt: '2026-10-08T16:00:00Z' },
  { id: 't3', title: 'Old thing', detail: '', completed: true, dueAt: null },
];
const input: TriageInput = { now: NOW, timeZone: 'America/Los_Angeles', memories: ['Works on GPU infra', 'Prefers morning meetings'], news, todos };

describe('triage prompt', () => {
  it('includes memories, headlines with ids, and only open to-dos without a due time', () => {
    const msgs = buildTriageMessages(input);
    expect(msgs[0]?.role).toBe('system');
    const user = msgs[1]?.content ?? '';
    expect(user).toContain('Works on GPU infra');
    expect(user).toContain('n2');
    expect(user).toContain('Nvidia unveils new chip');
    const needDue = user.split('To-dos needing a due time')[1]?.split('News (')[0] ?? '';
    expect(needDue).toContain('t1: Send Q3 churn deck to Sam by 2pm');
    expect(needDue).not.toContain('Book dentist'); // already has dueAt
    expect(user).toContain('Book dentist (due 2026-10-08T16:00:00Z)'); // still context for the briefing
    expect(user).not.toContain('Old thing'); // completed
    expect(user).toContain('2026-10-07T15:00:00Z');
    expect(user).toContain('America/Los_Angeles');
    expect(msgs[0]?.content).toMatch(/JSON/);
  });
});

describe('parseTriage', () => {
  it('parses fenced JSON, caps briefing at 3 lines of ≤60 chars, keeps only valid due times for requested ids', () => {
    const raw =
      '```json\n' +
      JSON.stringify({
        briefing: ['Call with Acme at 3pm: bring the Q3 churn numbers.', 'x'.repeat(80), 'Nvidia earnings tonight.', 'fourth'],
        newsOrder: ['n2', 'zzz', 'n1'],
        dueAt: { t1: '2026-10-07T21:00:00Z', t2: '2026-10-09T00:00:00Z', t3: 'tomorrow-ish' },
      }) +
      '\n```';
    const r = parseTriage(raw, input);
    expect(r).not.toBeNull();
    expect(r!.briefing).toHaveLength(3);
    expect(r!.briefing[1]!.length).toBe(60);
    expect(r!.newsOrder).toEqual(['n2', 'n1']);
    expect(r!.dueAt).toEqual({ t1: '2026-10-07T21:00:00Z' });
  });

  it('drops null / implausible due times', () => {
    const r = parseTriage(JSON.stringify({ briefing: ['a'], newsOrder: [], dueAt: { t1: null } }), input);
    expect(r!.dueAt).toEqual({});
    const r2 = parseTriage(JSON.stringify({ briefing: ['a'], newsOrder: [], dueAt: { t1: '1999-01-01T00:00:00Z' } }), input);
    expect(r2!.dueAt).toEqual({});
  });

  it.each(['not json', '[]', '{"briefing":"one string"}', '{"briefing":[1,2],"newsOrder":[],"dueAt":{}}'])(
    'returns null for invalid output %#',
    (raw) => {
      expect(parseTriage(raw, input)).toBeNull();
    },
  );

  it('tolerates missing newsOrder/dueAt', () => {
    expect(parseTriage('{"briefing":["hi"]}', input)).toEqual({ briefing: ['hi'], newsOrder: [], dueAt: {} });
  });
});

describe('ranking + fallback', () => {
  it('applies the LLM order, appending unranked items in original order', () => {
    expect(applyNewsOrder(news, ['n3', 'n1']).map((n) => n.id)).toEqual(['n3', 'n1', 'n2']);
  });

  it('deterministic fallback briefing counts due-today to-dos and leads with the top headline', () => {
    const b = fallbackBriefing(
      [
        { ...todos[0]!, dueAt: '2026-10-07T21:00:00Z' },
        todos[1]!,
        todos[2]!,
      ],
      news,
      NOW,
      'America/Los_Angeles',
    );
    expect(b).toEqual(['1 to-do due today, 2 open.', 'Fed holds rates steady']);
    expect(fallbackBriefing([], [], NOW, 'UTC')).toEqual([]);
  });
});
