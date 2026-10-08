// Relay-backed DashboardSource (plan D2): one /dashboard fetch cached for
// 60 s feeds the four panels and the idle home. The last good dashboard is
// kept when the relay becomes unreachable.
import type { PanelKind, PanelRow } from '../core/screen';
import { type Dashboard, type RelayClient, RelayError } from './client';

export const DASHBOARD_TTL_MILLIS = 60_000;
/** Panel row titles: room for `> [ ] ` in a 54-char lens line. */
export const PANEL_TITLE_CHARS = 48;

const cut = (t: string, n: number) => (t.length <= n ? t : t.slice(0, n - 1).trimEnd() + '~');

export function dashboardRows(d: Dashboard | null, kind: PanelKind): PanelRow[] {
  if (!d) return [];
  if (kind === 'todos') return d.todos.map((t) => ({ id: t.id, title: cut(t.title, PANEL_TITLE_CHARS), detail: t.detail, done: t.completed }));
  return d[kind].map((i) => ({ id: i.id, title: cut(i.title, PANEL_TITLE_CHARS), detail: i.detail }));
}

export class DashboardSource {
  private cached: Dashboard | null = null;
  private fetchedAt = Number.NEGATIVE_INFINITY;
  private inflight: Promise<Dashboard | null> | null = null;
  lastError: string | null = null;

  constructor(
    private readonly client: () => RelayClient | null,
    private readonly clock: () => number,
    private readonly ttlMillis = DASHBOARD_TTL_MILLIS,
  ) {}

  get current(): Dashboard | null {
    return this.cached;
  }

  /** Cached dashboard (≤ ttl old) or a fresh fetch; null when not configured or never reached. */
  dashboard(force = false): Promise<Dashboard | null> {
    const client = this.client();
    if (!client) {
      this.cached = null;
      this.lastError = null;
      return Promise.resolve(null);
    }
    if (!force && this.cached && this.clock() - this.fetchedAt < this.ttlMillis) return Promise.resolve(this.cached);
    if (this.inflight) return this.inflight;
    this.inflight = client
      .getDashboard()
      .then((d) => {
        this.cached = d;
        this.fetchedAt = this.clock();
        this.lastError = null;
        return d;
      })
      .catch((e: unknown) => {
        this.lastError = e instanceof RelayError || e instanceof Error ? e.message : String(e);
        return this.cached;
      })
      .finally(() => {
        this.inflight = null;
      });
    return this.inflight;
  }

  rows(kind: PanelKind): PanelRow[] {
    return dashboardRows(this.cached, kind);
  }

  /** PATCH /todos/:id; the cached row follows the wearer's toggle. Throws on relay failure. */
  async toggleTodo(id: string, done: boolean): Promise<void> {
    const client = this.client();
    if (!client) throw new RelayError('Relay not configured');
    this.setDone(id, done);
    await client.patchTodo(id, done);
  }

  setDone(id: string, done: boolean): void {
    if (!this.cached) return;
    this.cached = { ...this.cached, todos: this.cached.todos.map((t) => (t.id === id ? { ...t, completed: done } : t)) };
  }

  reset(): void {
    this.cached = null;
    this.fetchedAt = Number.NEGATIVE_INFINITY;
    this.lastError = null;
  }
}
