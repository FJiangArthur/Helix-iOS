import { clockLabel, startOfLocalDay } from './time.js';
import { detail } from './text.js';
import type { Dashboard, Reminder } from './types.js';

/** Look-ahead: a to-do becomes a reminder this long before it is due. */
export const LEAD_MS = 10 * 60_000;

/**
 * CONTRACT-0.3 §7 /reminders:
 * - open to-dos with `since < dueAt <= now + 10 min` (due soon or overdue since the last poll), oldest first;
 * - the briefing's headline once per local day: included when the client's last poll (`since`) was before
 *   today's local midnight in `timeZone`.
 */
export function buildReminders(d: Dashboard, since: number, now: number, timeZone: string): Reminder[] {
  const horizon = now + LEAD_MS;
  const todos = d.todos
    .filter((t) => !t.completed && t.dueAt)
    .map((t) => ({ t, due: Date.parse(t.dueAt!) }))
    .filter(({ due }) => !Number.isNaN(due) && due > since && due <= horizon)
    .sort((a, b) => a.due - b.due)
    .map<Reminder>(({ t, due }) => ({
      id: `r-${t.id}`,
      kind: 'todo',
      text: detail(`Due ${clockLabel(due, timeZone)}: ${t.title}`),
      dueAt: t.dueAt,
    }));
  const out = [...todos];
  const headline = d.briefing[0];
  if (headline && since < startOfLocalDay(now, timeZone)) {
    out.push({ id: 'r-brief', kind: 'briefing', text: headline, dueAt: null });
  }
  return out;
}
