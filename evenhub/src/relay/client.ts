// helix-relay client (conversate-core/CONTRACT-0.3.md §7). Browser fetch with
// the user's relay bearer key; /ask streams SSE through response.body.

export type FetchFn = (url: string, init?: RequestInit) => Promise<Response>;

/** Every relay request (Ask: until its first byte) gives up after this (§8). */
export const RELAY_TIMEOUT_MILLIS = 15_000;

export interface RelayConfig {
  url: string;
  key: string;
}

export interface RelayItem {
  id: string;
  title: string;
  detail: string;
}

export interface RelayTodo extends RelayItem {
  completed: boolean;
  dueAt?: string | null;
}

export interface Dashboard {
  generatedAt: string;
  briefing: string[];
  news: RelayItem[];
  x: RelayItem[];
  todos: RelayTodo[];
  omi: RelayItem[];
}

export interface Reminder {
  id: string;
  kind: string;
  text: string;
  dueAt: string | null;
}

export interface AskOptions {
  context?: string;
  deep?: boolean;
  signal?: AbortSignal;
  onDelta?: (delta: string) => void;
}

export class RelayError extends Error {
  constructor(message: string, readonly status?: number) {
    super(message);
    this.name = 'RelayError';
  }
}

/** `https://host/` -> `https://host`; bare host gets https; anything else null. */
const LOOPBACK_HOSTS = new Set(['localhost', '127.0.0.1', '[::1]', '::1']);

export function normalizeRelayUrl(raw: string): string | null {
  let u = raw.trim();
  if (u === '') return null;
  if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(u)) u = `https://${u}`;
  try {
    const parsed = new URL(u);
    if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') return null;
    // Security: the bearer key never travels in cleartext, except to this
    // device's own loopback (local development).
    if (parsed.protocol === 'http:' && !LOOPBACK_HOSTS.has(parsed.hostname)) return null;
    return `${parsed.origin}${parsed.pathname.replace(/\/+$/, '')}`;
  } catch {
    return null;
  }
}

const str = (v: unknown) => (typeof v === 'string' ? v : '');
const items = (v: unknown): RelayItem[] =>
  Array.isArray(v) ? v.filter((i) => i && typeof i.id === 'string').map((i) => ({ id: i.id, title: str(i.title), detail: str(i.detail) })) : [];

export function parseDashboard(json: unknown): Dashboard {
  const d = (json ?? {}) as Record<string, unknown>;
  const todos = Array.isArray(d.todos) ? d.todos.filter((t) => t && typeof t.id === 'string') : [];
  return {
    generatedAt: str(d.generatedAt),
    briefing: Array.isArray(d.briefing) ? d.briefing.filter((b): b is string => typeof b === 'string') : [],
    news: items(d.news),
    x: items(d.x),
    omi: items(d.omi),
    todos: todos.map((t) => ({ id: t.id, title: str(t.title), detail: str(t.detail), completed: t.completed === true, dueAt: t.dueAt ?? null })),
  };
}

export class RelayClient {
  readonly base: string;

  constructor(private readonly config: RelayConfig, private readonly fetchFn: FetchFn = (u, i) => fetch(u, i)) {
    const base = normalizeRelayUrl(config.url);
    if (!base) throw new RelayError('Relay URL is not valid');
    this.base = base;
  }

  async health(): Promise<{ ok: boolean; version: string }> {
    const json = (await this.json('/health', { method: 'GET' }, false)) as { ok?: unknown; version?: unknown };
    return { ok: json.ok === true, version: str(json.version) };
  }

  async getDashboard(): Promise<Dashboard> {
    return parseDashboard(await this.json('/dashboard', { method: 'GET' }));
  }

  async patchTodo(id: string, completed: boolean): Promise<RelayTodo | null> {
    const json = (await this.json(`/todos/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ completed }),
    })) as { todo?: Record<string, unknown> };
    const t = json.todo;
    if (!t || typeof t.id !== 'string') return null;
    return { id: t.id, title: str(t.title), detail: str(t.detail), completed: t.completed === true, dueAt: (t.dueAt as string) ?? null };
  }

  async getReminders(since: number): Promise<Reminder[]> {
    const json = (await this.json(`/reminders?since=${Math.max(0, Math.floor(since))}`, { method: 'GET' })) as { reminders?: unknown };
    const list = Array.isArray(json.reminders) ? json.reminders : [];
    return list
      .filter((r) => r && typeof r.id === 'string' && typeof r.text === 'string')
      .map((r) => ({ id: r.id, kind: str(r.kind), text: r.text, dueAt: r.dueAt ?? null }));
  }

  /** POST /ask; deltas stream to onDelta; resolves with the whole answer. */
  async ask(question: string, opts: AskOptions = {}): Promise<string> {
    const body: Record<string, unknown> = { question };
    if (opts.context) body.context = opts.context;
    if (opts.deep) body.deep = true;
    // 15 s to the first byte (pings count), then no limit (§8).
    const deadline = new Deadline(RELAY_TIMEOUT_MILLIS, opts.signal);
    let res: Response;
    try {
      res = await this.request('/ask', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'text/event-stream' },
        body: JSON.stringify(body),
      }, true, deadline);
    } catch (e) {
      deadline.clear();
      throw e;
    }
    let answer = '';
    let done = false;
    const onEvent = (data: string) => {
      let ev: { delta?: unknown; done?: unknown; error?: unknown };
      try {
        ev = JSON.parse(data);
      } catch {
        return;
      }
      if (typeof ev.error === 'string') throw new RelayError(`Relay: ${ev.error}`);
      if (typeof ev.delta === 'string' && ev.delta !== '') {
        answer += ev.delta;
        opts.onDelta?.(ev.delta);
      }
      if (ev.done === true) done = true;
    };
    const parser = new SseParser(onEvent);
    if (res.body && typeof res.body.getReader === 'function') {
      const reader = res.body.getReader();
      const dec = new TextDecoder();
      try {
        while (!done) {
          deadline.check();
          const { value, done: end } = await deadline.race(reader.read());
          deadline.clear(); // first byte (or end) arrived: no limit from here
          if (end) break;
          parser.push(dec.decode(value, { stream: true }));
          deadline.check();
        }
        parser.push(dec.decode());
        parser.end();
      } finally {
        deadline.clear();
        void reader.cancel().catch(() => { /* already closed */ });
      }
    } else {
      try {
        parser.push(await deadline.race(res.text()));
      } finally {
        deadline.clear();
      }
      parser.end();
    }
    return answer;
  }

  private async json(path: string, init: RequestInit, auth = true): Promise<unknown> {
    const deadline = new Deadline(RELAY_TIMEOUT_MILLIS, init.signal ?? undefined);
    try {
      const res = await this.request(path, init, auth, deadline);
      try {
        return await deadline.race(res.json());
      } catch (e) {
        if (isAbort(e) || e instanceof RelayError) throw e;
        throw new RelayError('Relay sent an invalid response');
      }
    } finally {
      deadline.clear();
    }
  }

  /** fetch bounded by [deadline]; the caller clears it. */
  private async request(path: string, init: RequestInit, auth: boolean, deadline: Deadline): Promise<Response> {
    const headers = new Headers(init.headers);
    if (auth) headers.set('Authorization', `Bearer ${this.config.key}`);
    let res: Response;
    try {
      res = await deadline.race(this.fetchFn(this.base + path, { ...init, headers, signal: deadline.signal }));
    } catch (e) {
      if (isAbort(e) || e instanceof RelayError) throw e;
      throw new RelayError(`Relay unreachable: ${e instanceof Error ? e.message : String(e)}`);
    }
    if (!res.ok) {
      let reason = '';
      try {
        reason = str(((await deadline.race(res.json())) as { error?: unknown }).error);
      } catch (e) {
        if (isAbort(e) || e instanceof RelayError) throw e;
      }
      throw new RelayError(`Relay HTTP ${res.status}${reason ? `: ${reason}` : ''}`, res.status);
    }
    return res;
  }
}

const isAbort = (e: unknown) => (e as { name?: string })?.name === 'AbortError';

/**
 * Caller signal + timeout, combined like AbortSignal.any([signal,
 * AbortSignal.timeout(ms)]). The timer is a plain setTimeout so it can be
 * cleared once the response starts (Ask) and driven by fake timers in tests.
 * A timeout surfaces as RelayError("Relay timed out"); a caller abort stays an
 * AbortError.
 */
class Deadline {
  readonly signal: AbortSignal;
  private readonly timeout = new AbortController();
  private timer: ReturnType<typeof setTimeout> | null;

  constructor(ms: number, private readonly caller?: AbortSignal) {
    this.timer = setTimeout(() => {
      this.timer = null;
      this.timeout.abort(new RelayError('Relay timed out'));
    }, ms);
    this.signal = caller ? anySignal([caller, this.timeout.signal]) : this.timeout.signal;
  }

  clear(): void {
    if (this.timer !== null) clearTimeout(this.timer);
    this.timer = null;
  }

  /** Throws the reason if the caller aborted or the deadline passed. */
  check(): void {
    if (this.caller?.aborted) throw abortError();
    if (this.timeout.signal.aborted) throw new RelayError('Relay timed out');
  }

  /** [p], or the abort/timeout error as soon as either fires (even if [p] ignores the signal). */
  race<T>(p: Promise<T>): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const onAbort = () => {
        try {
          this.check();
        } catch (e) {
          reject(e);
        }
      };
      if (this.signal.aborted) return onAbort();
      this.signal.addEventListener('abort', onAbort, { once: true });
      p.then(
        (v) => { this.signal.removeEventListener('abort', onAbort); resolve(v); },
        (e) => {
          this.signal.removeEventListener('abort', onAbort);
          if (this.signal.aborted) onAbort();
          else reject(e);
        },
      );
    });
  }
}

function anySignal(signals: AbortSignal[]): AbortSignal {
  const any = (AbortSignal as unknown as { any?: (s: AbortSignal[]) => AbortSignal }).any;
  if (typeof any === 'function') return any.call(AbortSignal, signals);
  const ac = new AbortController();
  for (const s of signals) {
    if (s.aborted) { ac.abort(s.reason); break; }
    s.addEventListener('abort', () => ac.abort(s.reason), { once: true });
  }
  return ac.signal;
}

function abortError(): Error {
  const e = new Error('aborted');
  e.name = 'AbortError';
  return e;
}

/** Minimal text/event-stream parser: `data:` lines, events separated by a blank line. */
export class SseParser {
  private buffer = '';
  private data: string[] = [];

  constructor(private readonly onEvent: (data: string) => void) {}

  push(text: string): void {
    this.buffer += text;
    let nl: number;
    while ((nl = this.buffer.search(/\r?\n/)) >= 0) {
      const line = this.buffer.slice(0, nl);
      this.buffer = this.buffer.slice(this.buffer[nl] === '\r' ? nl + 2 : nl + 1);
      this.line(line);
    }
  }

  end(): void {
    if (this.buffer !== '') this.line(this.buffer);
    this.buffer = '';
    this.dispatch();
  }

  private line(line: string): void {
    if (line === '') return this.dispatch();
    if (line.startsWith(':')) return;
    if (line.startsWith('data:')) this.data.push(line.slice(5).replace(/^ /, ''));
  }

  private dispatch(): void {
    if (this.data.length === 0) return;
    const data = this.data.join('\n');
    this.data = [];
    this.onEvent(data);
  }
}
